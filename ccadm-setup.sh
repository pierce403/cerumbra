#!/usr/bin/env bash
# Cerumbra helper to enable NVIDIA confidential computing mode on DGX Spark

set -euo pipefail

if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root (sudo)." >&2
    exit 1
fi

CUDA_KEYRING_TMP=""

cleanup_tmp_artifacts() {
    if [[ -n "${CUDA_KEYRING_TMP}" && -f "${CUDA_KEYRING_TMP}" ]]; then
        rm -f "${CUDA_KEYRING_TMP}"
    fi
}

trap cleanup_tmp_artifacts EXIT

ensure_nvidia_ccadm_available() {
    if command -v nvidia-ccadm >/dev/null 2>&1; then
        return 0
    fi

    echo "[Cerumbra] nvidia-ccadm not found. Attempting installation..."

    if ! command -v apt-get >/dev/null 2>&1; then
        echo "Error: apt-get not available. Install the NVIDIA confidential computing utilities manually (nvidia-ccadm)." >&2
        return 1
    fi

    if ! add_nvidia_cuda_repo; then
        return 1
    fi

    fix_conflicting_signed_by

    echo "[Cerumbra] Updating apt package listings..."
    if ! apt-get update; then
        echo "Error: apt-get update failed even after repository fixes. Resolve APT issues and retry." >&2
        return 1
    fi

    echo "[Cerumbra] Installing nvidia-ccadm package..."
    if ! apt-get install -y nvidia-ccadm; then
        echo "Error: Failed to install nvidia-ccadm via apt-get. Install the NVIDIA confidential computing utilities manually." >&2
        return 1
    fi

    if ! command -v nvidia-ccadm >/dev/null 2>&1; then
        echo "Error: nvidia-ccadm remains unavailable after installation. Check the system package repositories." >&2
        return 1
    fi
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

echo "[Cerumbra] Checking confidential compute status..."
if ! ensure_nvidia_ccadm_available; then
    exit 1
fi

nvidia-ccadm --status || true

echo "[Cerumbra] Enabling SECURE mode via nvidia-ccadm..."
nvidia-ccadm --mode SECURE

echo "[Cerumbra] Confidential compute requested. Please reboot the system to finalize."
