#!/usr/bin/env bash
# Cerumbra helper to enable NVIDIA confidential computing mode on DGX Spark
#
# NOTE: As of Oct 2025, nvidia-ccadm package availability may vary by NVIDIA driver
# version and system configuration. This script attempts multiple installation methods.
# Tested repository URLs (as of Oct 2025):
#   - CUDA repos (ubuntu2204, ubuntu2404): ✓ Available
#   - Confidential computing repos: ⚠ May redirect or return 404
#
# If automatic installation fails, consult NVIDIA's official documentation:
#   https://docs.nvidia.com/confidential-computing/

set -euo pipefail

if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root (sudo)." >&2
    exit 1
fi

CUDA_KEYRING_TMP=""
NVIDIA_CCADM_DEB=""
DOCS_URL="https://docs.nvidia.com/confidential-computing/latest/deployment-guide/index.html"

cleanup_tmp_artifacts() {
    if [[ -n "${CUDA_KEYRING_TMP}" && -f "${CUDA_KEYRING_TMP}" ]]; then
        rm -f "${CUDA_KEYRING_TMP}"
    fi
    if [[ -n "${NVIDIA_CCADM_DEB}" && -f "${NVIDIA_CCADM_DEB}" ]]; then
        rm -f "${NVIDIA_CCADM_DEB}"
    fi
}

trap cleanup_tmp_artifacts EXIT

ensure_nvidia_ccadm_available() {
    # Check if nvidia-ccadm is in PATH
    if command -v nvidia-ccadm >/dev/null 2>&1; then
        echo "[Cerumbra] ✓ nvidia-ccadm is already available in PATH"
        nvidia-ccadm --version 2>/dev/null || echo "[Cerumbra] (version info unavailable)"
        return 0
    fi
    
    # Check common installation locations
    local common_paths=(
        "/usr/bin/nvidia-ccadm"
        "/usr/local/bin/nvidia-ccadm"
        "/opt/nvidia/ccadm/nvidia-ccadm"
        "/usr/lib/nvidia-ccadm/nvidia-ccadm"
    )
    
    for path in "${common_paths[@]}"; do
        if [[ -x "${path}" ]]; then
            echo "[Cerumbra] ✓ Found nvidia-ccadm at ${path}"
            "${path}" --version 2>/dev/null || echo "[Cerumbra] (version info unavailable)"
            # Add to PATH if not already there
            export PATH="${path%/*}:${PATH}"
            return 0
        fi
    done

    echo "[Cerumbra] nvidia-ccadm not found in PATH or common locations. Attempting installation..."
    echo "[Cerumbra] Note: nvidia-ccadm is required for GPU confidential computing mode."
    echo "[Cerumbra] It may be bundled with NVIDIA drivers (550+ recommended for H100/Blackwell)"

    if ! command -v apt-get >/dev/null 2>&1; then
        echo "Error: apt-get not available. Install the NVIDIA confidential computing utilities manually (nvidia-ccadm)." >&2
        return 1
    fi

    if ! add_nvidia_cuda_repo; then
        return 1
    fi

    fix_conflicting_signed_by
    disable_duplicate_cuda_lists
    if ! verify_repo_endpoint "cuda"; then
        echo "Error: Unable to reach the NVIDIA CUDA repository endpoint." >&2
        echo "Check network connectivity and consult: ${DOCS_URL}" >&2
        return 1
    fi

    echo "[Cerumbra] Updating apt package listings..."
    # Allow update to continue even if some repos fail (we'll clean them up later)
    apt-get update 2>&1 | tee /tmp/cerumbra-initial-apt-update.log || {
        echo "Warning: apt-get update reported issues, but continuing..." >&2
    }

    if ! apt-cache show nvidia-ccadm >/dev/null 2>&1; then
        echo "[Cerumbra] nvidia-ccadm not present in current APT sources. Adding confidential-computing repository..."
        if ! add_confidential_computing_repo; then
            echo "Warning: Failed to add confidential-computing repository configuration." >&2
        else
            # Note: As of Oct 2025, confidential computing repos may not be publicly available
            # Verify and remove if it causes apt to fail
            if ! verify_repo_endpoint "confidential"; then
                echo "Warning: Unable to verify NVIDIA confidential-computing repository endpoint." >&2
                echo "This is expected if the package is distributed through other channels." >&2
                echo "Removing repository to prevent apt-get update failures..." >&2
                remove_confidential_computing_repo
            fi
        fi
        
        echo "[Cerumbra] Updating apt cache after repository changes..."
        if ! apt-get update 2>&1 | tee /tmp/cerumbra-apt-update.log; then
            echo "Warning: apt-get update still has issues after cleanup." >&2
            # If update still fails and CC repo exists, remove it
            if grep -q "confidential-computing" /tmp/cerumbra-apt-update.log 2>/dev/null; then
                echo "[Cerumbra] Confidential computing repository is causing apt failures, removing it..." >&2
                remove_confidential_computing_repo
                echo "[Cerumbra] Retrying apt-get update..." >&2
                apt-get update 2>&1 | tee /tmp/cerumbra-apt-update-retry.log || true
            fi
        fi
    fi

    echo "[Cerumbra] Installing nvidia-ccadm package..."
    if ! apt-get install -y nvidia-ccadm 2>&1 | tee /tmp/cerumbra-ccadm-install.log; then
        echo "Warning: apt-get install failed. Attempting direct package download..." >&2
        if ! download_and_install_nvidia_ccadm; then
            echo "" >&2
            echo "======================================================================" >&2
            echo "ERROR: Unable to install nvidia-ccadm automatically" >&2
            echo "======================================================================" >&2
            echo "" >&2
            echo "nvidia-ccadm is required to enable GPU confidential computing mode." >&2
            echo "" >&2
            echo "Possible reasons:" >&2
            echo "  1. Package not yet available for your Ubuntu version" >&2
            echo "  2. Requires specific NVIDIA driver version (550+ for H100/Blackwell)" >&2
            echo "  3. May be included with NVIDIA driver installation" >&2
            echo "  4. Network/repository access issues" >&2
            echo "" >&2
            echo "Manual installation options:" >&2
            echo "  1. Install/upgrade NVIDIA drivers (may include nvidia-ccadm):" >&2
            echo "     sudo apt install nvidia-driver-550-server" >&2
            echo "  2. Check if nvidia-smi shows Hopper H100 or Blackwell GPUs:" >&2
            echo "     nvidia-smi --query-gpu=name --format=csv" >&2
            echo "  3. Consult NVIDIA confidential computing documentation:" >&2
            echo "     ${DOCS_URL}" >&2
            echo "  4. Contact NVIDIA support for DGX Spark specific guidance" >&2
            echo "" >&2
            echo "Install log: /tmp/cerumbra-ccadm-install.log" >&2
            echo "======================================================================" >&2
            return 1
        fi
    fi

    if ! command -v nvidia-ccadm >/dev/null 2>&1; then
        echo "Error: nvidia-ccadm remains unavailable after installation." >&2
        echo "Check installation log: /tmp/cerumbra-ccadm-install.log" >&2
        echo "Refer to the NVIDIA documentation for troubleshooting guidance:" >&2
        echo "  ${DOCS_URL}" >&2
        return 1
    fi
    
    echo "[Cerumbra] ✓ nvidia-ccadm successfully installed"
}

add_nvidia_cuda_repo() {
    if dpkg -s cuda-keyring >/dev/null 2>&1; then
        return 0
    fi

    echo "[Cerumbra] NVIDIA CUDA repository not detected. Installing cuda-keyring..."

    if ! command -v dpkg >/dev/null 2>&1; then
        echo "Error: dpkg not available. Unable to install cuda-keyring automatically." >&2
        return 1
    fi

    local release=""
    if command -v lsb_release >/dev/null 2>&1; then
        release=$(lsb_release -rs)
    elif [[ -f /etc/os-release ]]; then
        release=$(grep -E '^VERSION_ID=' /etc/os-release | cut -d'"' -f2)
    fi

    local distro=""
    case "${release}" in
        24.04*|24)
            distro="ubuntu2404"
            ;;
        22.04*|22)
            distro="ubuntu2204"
            ;;
        20.04*|20)
            distro="ubuntu2004"
            ;;
        *)
            echo "Error: Unsupported or undetected Ubuntu release (${release:-unknown}). Install cuda-keyring manually." >&2
            return 1
            ;;
    esac

    local arch=""
    if command -v dpkg >/dev/null 2>&1; then
        arch=$(dpkg --print-architecture)
    fi

    local repo_arch="x86_64"
    case "${arch}" in
        amd64) repo_arch="x86_64" ;;
        arm64) repo_arch="sbsa" ;;
        *) repo_arch="x86_64" ;;
    esac

    local keyring_pkg="cuda-keyring_1.1-1_all.deb"
    local base_url="https://developer.download.nvidia.com/compute/cuda/repos/${distro}/${repo_arch}"
    local url="${base_url}/${keyring_pkg}"

    if ! command -v curl >/dev/null 2>&1 && ! command -v wget >/dev/null 2>&1; then
        echo "Error: Neither curl nor wget is available to download cuda-keyring. Install one of them and rerun." >&2
        return 1
    fi

    CUDA_KEYRING_TMP="$(mktemp)"
    echo "[Cerumbra] Downloading cuda-keyring from ${url}..."
    if command -v curl >/dev/null 2>&1; then
        if ! curl -fsSL -o "${CUDA_KEYRING_TMP}" "${url}"; then
            echo "Error: Failed to download cuda-keyring from ${url}" >&2
            return 1
        fi
    else
        if ! wget -q -O "${CUDA_KEYRING_TMP}" "${url}"; then
            echo "Error: Failed to download cuda-keyring from ${url}" >&2
            return 1
        fi
    fi

    echo "[Cerumbra] Installing cuda-keyring..."
    if ! dpkg -i "${CUDA_KEYRING_TMP}"; then
        echo "Error: Failed to install cuda-keyring package. Please install the NVIDIA CUDA repository manually." >&2
        return 1
    fi

    echo "[Cerumbra] NVIDIA CUDA repository added."
    return 0
}

fix_conflicting_signed_by() {
    local legacy="/usr/share/keyrings/cuda_debian_prod.gpg"
    local replacement="/usr/share/keyrings/cuda-archive-keyring.gpg"

    # Rewrite any legacy Signed-By/signed-by references across APT configs
    if grep -Rql "${legacy}" /etc/apt 2>/dev/null; then
        while IFS= read -r -d '' file; do
            echo "[Cerumbra] Normalizing Signed-By in ${file}"
            # Handle both '=' and ':' separators, case-insensitive
            sed -i -E "s#([Ss]igned-[Bb]y[:=])\\s*${legacy}#\\1 ${replacement}#g" "${file}"
        done < <(grep -RZl "${legacy}" /etc/apt 2>/dev/null)
    fi

    # Deduplicate repeated signed-by tokens that may have accumulated
    while IFS= read -r -d '' file; do
        sed -i -E "s#(signed-by=${replacement})([[:space:]]+signed-by=${replacement})+#\\1#gI" "${file}"
        sed -i -E "s#(Signed-By=${replacement})([[:space:]]+Signed-By=${replacement})+#\\1#g" "${file}"
    done < <(find /etc/apt -type f -name "*.list" -print0 2>/dev/null)

    while IFS= read -r -d '' file; do
        sed -i -E "s#(Signed-By:\\s*)${replacement}(\\s+Signed-By:\\s*${replacement})+#\\1${replacement}#g" "${file}"
    done < <(find /etc/apt -type f -name "*.sources" -print0 2>/dev/null)
}

disable_duplicate_cuda_lists() {
    local duplicates=(/etc/apt/sources.list.d/cuda-ubuntu*.list)
    for file in "${duplicates[@]}"; do
        if [[ -f "${file}" ]]; then
            echo "[Cerumbra] Disabling duplicate legacy CUDA source ${file}"
            mv "${file}" "${file}.disabled"
        fi
    done
}

add_confidential_computing_repo() {
    local release=""
    if command -v lsb_release >/dev/null 2>&1; then
        release=$(lsb_release -rs)
    elif [[ -f /etc/os-release ]]; then
        release=$(grep -E '^VERSION_ID=' /etc/os-release | cut -d'"' -f2)
    fi

    local distro=""
    case "${release}" in
        24.04*|24)
            distro="ubuntu2404"
            ;;
        22.04*|22)
            distro="ubuntu2204"
            ;;
        20.04*|20)
            distro="ubuntu2004"
            ;;
        *)
            echo "Error: Unsupported or undetected Ubuntu release (${release:-unknown}). Install the confidential computing repository manually." >&2
            return 1
            ;;
    esac

    local arch=""
    if command -v dpkg >/dev/null 2>&1; then
        arch=$(dpkg --print-architecture)
    fi

    local repo_arch="x86_64"
    case "${arch}" in
        amd64) repo_arch="x86_64" ;;
        arm64) repo_arch="sbsa" ;;
        *) repo_arch="x86_64" ;;
    esac

    local target="/etc/apt/sources.list.d/nvidia-confidential-compute.sources"
    if [[ -f "${target}" ]]; then
        return 0
    fi

    echo "[Cerumbra] Creating confidential-computing APT source at ${target}"
    cat > "${target}" <<EOF
Types: deb
URIs: https://developer.download.nvidia.com/compute/confidential-computing/repos/${distro}/${repo_arch}/
Suites: /
Components:
Signed-By: /usr/share/keyrings/cuda-archive-keyring.gpg
EOF
}

remove_confidential_computing_repo() {
    local target="/etc/apt/sources.list.d/nvidia-confidential-compute.sources"
    if [[ -f "${target}" ]]; then
        echo "[Cerumbra] Removing problematic confidential-computing repository..." >&2
        rm -f "${target}"
        return 0
    fi
    return 1
}

download_and_install_nvidia_ccadm() {
    local release=""
    if command -v lsb_release >/dev/null 2>&1; then
        release=$(lsb_release -rs)
    elif [[ -f /etc/os-release ]]; then
        release=$(grep -E '^VERSION_ID=' /etc/os-release | cut -d'"' -f2)
    fi

    local distro=""
    case "${release}" in
        24.04*|24)
            distro="ubuntu2404"
            ;;
        22.04*|22)
            distro="ubuntu2204"
            ;;
        20.04*|20)
            distro="ubuntu2004"
            ;;
        *)
            return 1
            ;;
    esac

    local arch=""
    if command -v dpkg >/dev/null 2>&1; then
        arch=$(dpkg --print-architecture)
    fi

    local repo_arch="x86_64"
    case "${arch}" in
        amd64) repo_arch="x86_64" ;;
        arm64) repo_arch="sbsa" ;;
        *) repo_arch="x86_64" ;;
    esac

    if command -v apt-get >/dev/null 2>&1; then
        if apt-get download nvidia-ccadm >/dev/null 2>&1; then
            NVIDIA_CCADM_DEB="$(ls -t nvidia-ccadm_*.deb 2>/dev/null | head -n1 || true)"
            if [[ -n "${NVIDIA_CCADM_DEB}" && -f "${NVIDIA_CCADM_DEB}" ]]; then
                if dpkg -i "${NVIDIA_CCADM_DEB}"; then
                    return 0
                fi
            fi
        fi
    fi

    local pkg_url="https://developer.download.nvidia.com/compute/confidential-computing/repos/${distro}/${repo_arch}/"
    local index_tmp
    index_tmp="$(mktemp)"

    if command -v curl >/dev/null 2>&1; then
        if ! curl -fsSL "${pkg_url}" -o "${index_tmp}"; then
            rm -f "${index_tmp}"
            return 1
        fi
    elif command -v wget >/dev/null 2>&1; then
        if ! wget -q "${pkg_url}" -O "${index_tmp}"; then
            rm -f "${index_tmp}"
            return 1
        fi
    else
        rm -f "${index_tmp}"
        return 1
    fi

    local deb_name
    deb_name="$(grep -Eo 'nvidia-ccadm_[^"]+\.deb' "${index_tmp}" | head -n1 || true)"
    rm -f "${index_tmp}"

    if [[ -z "${deb_name}" ]]; then
        return 1
    fi

    NVIDIA_CCADM_DEB="$(mktemp)"
    local full_url="${pkg_url}${deb_name}"
    echo "[Cerumbra] Downloading ${deb_name} from ${full_url}"
    if command -v curl >/dev/null 2>&1; then
        if ! curl -fsSL "${full_url}" -o "${NVIDIA_CCADM_DEB}"; then
            return 1
        fi
    else
        if ! wget -q "${full_url}" -O "${NVIDIA_CCADM_DEB}"; then
            return 1
        fi
    fi

    if ! dpkg -i "${NVIDIA_CCADM_DEB}"; then
        return 1
    fi

    return 0
}

verify_repo_endpoint() {
    local kind="$1"
    local release=""
    if command -v lsb_release >/dev/null 2>&1; then
        release=$(lsb_release -rs)
    elif [[ -f /etc/os-release ]]; then
        release=$(grep -E '^VERSION_ID=' /etc/os-release | cut -d'"' -f2)
    fi

    local distro=""
    case "${release}" in
        24.04*|24)
            distro="ubuntu2404"
            ;;
        22.04*|22)
            distro="ubuntu2204"
            ;;
        20.04*|20)
            distro="ubuntu2004"
            ;;
        *)
            return 1
            ;;
    esac

    local arch=""
    if command -v dpkg >/dev/null 2>&1; then
        arch=$(dpkg --print-architecture)
    fi

    local repo_arch="x86_64"
    case "${arch}" in
        amd64) repo_arch="x86_64" ;;
        arm64) repo_arch="sbsa" ;;
        *) repo_arch="x86_64" ;;
    esac

    local base=""
    if [[ "${kind}" == "confidential" ]]; then
        base="https://developer.download.nvidia.com/compute/confidential-computing/repos/${distro}/${repo_arch}/"
    else
        base="https://developer.download.nvidia.com/compute/cuda/repos/${distro}/${repo_arch}/"
    fi

    echo "[Cerumbra] Verifying ${kind} repository: ${base}" >&2

    local candidates=("InRelease" "Release")
    local url=""
    local http_code=""
    for candidate in "${candidates[@]}"; do
        url="${base}${candidate}"
        if command -v curl >/dev/null 2>&1; then
            http_code=$(curl -o /dev/null -w '%{http_code}' -fsSL --retry 2 --connect-timeout 5 "${url}" 2>/dev/null || echo "000")
            if [[ "${http_code}" == "200" ]]; then
                echo "[Cerumbra] ✓ Repository endpoint verified (HTTP ${http_code})" >&2
                return 0
            elif [[ "${http_code}" != "000" ]]; then
                echo "[Cerumbra] ⚠ Repository returned HTTP ${http_code} for ${candidate}" >&2
            fi
        elif command -v wget >/dev/null 2>&1; then
            if wget -q --spider --tries=2 --timeout=5 "${url}" 2>/dev/null; then
                echo "[Cerumbra] ✓ Repository endpoint verified" >&2
                return 0
            fi
        fi
    done

    # Try base directory listing as fallback
    if command -v curl >/dev/null 2>&1; then
        http_code=$(curl -o /dev/null -w '%{http_code}' -fsSL --retry 2 --connect-timeout 5 "${base}" 2>/dev/null || echo "000")
        if [[ "${http_code}" == "200" ]]; then
            echo "[Cerumbra] ✓ Repository base directory accessible (HTTP ${http_code})" >&2
            return 0
        fi
        echo "[Cerumbra] ✗ Repository verification failed (HTTP ${http_code})" >&2
    elif command -v wget >/dev/null 2>&1; then
        if wget -q --spider --tries=2 --timeout=5 "${base}" 2>/dev/null; then
            echo "[Cerumbra] ✓ Repository base directory accessible" >&2
            return 0
        fi
        echo "[Cerumbra] ✗ Repository verification failed" >&2
    fi

    return 1
}

echo "======================================================================"
echo "Cerumbra DGX Spark Confidential Computing Setup"
echo "======================================================================"
echo ""
echo "[Cerumbra] System information:"
echo "  OS: $(lsb_release -ds 2>/dev/null || grep PRETTY_NAME /etc/os-release | cut -d'"' -f2)"
echo "  Kernel: $(uname -r)"
if command -v nvidia-smi >/dev/null 2>&1; then
    echo "  NVIDIA Driver: $(nvidia-smi --query-gpu=driver_version --format=csv,noheader | head -n1 2>/dev/null || echo 'unknown')"
    echo "  GPU(s): $(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | paste -sd ', ' || echo 'unknown')"
fi
echo ""

echo "[Cerumbra] Checking confidential compute status..."
if ! ensure_nvidia_ccadm_available; then
    exit 1
fi

echo ""
echo "[Cerumbra] Current GPU confidential computing status:"
nvidia-ccadm --status || true

echo ""
echo "[Cerumbra] Enabling SECURE mode via nvidia-ccadm..."
if nvidia-ccadm --mode SECURE; then
    echo "[Cerumbra] ✓ SECURE mode successfully requested"
else
    echo "[Cerumbra] ✗ Failed to set SECURE mode" >&2
    echo "This may indicate:"
    echo "  - GPU doesn't support confidential computing"
    echo "  - Driver version incompatibility"
    echo "  - System configuration issue"
    exit 1
fi

echo ""
echo "======================================================================"
echo "Setup Complete - Reboot Required"
echo "======================================================================"
echo ""
echo "Next steps:"
echo "  1. Reboot the system:"
echo "       sudo reboot"
echo ""
echo "  2. After reboot, verify confidential computing is enabled:"
echo "       nvidia-ccadm --status"
echo "       # Should show: SECURE"
echo ""
echo "  3. Check GPU confidential computing mode:"
echo "       nvidia-smi --query-gpu=conf_computing_mode --format=csv"
echo "       # Should show: Enabled"
echo ""
echo "  4. Run Cerumbra server to test:"
echo "       ./cerumbra-server.sh"
echo ""
echo "======================================================================"
