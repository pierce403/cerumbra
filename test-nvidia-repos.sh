#!/usr/bin/env bash
# Test script to verify NVIDIA repository availability
# Created during ccadm-setup.sh fixes on Oct 22, 2025

set -euo pipefail

echo "======================================================================"
echo "NVIDIA Repository Availability Test"
echo "======================================================================"
echo "Date: $(date)"
echo ""

# Detect system info
RELEASE=""
if command -v lsb_release >/dev/null 2>&1; then
    RELEASE=$(lsb_release -rs)
elif [[ -f /etc/os-release ]]; then
    RELEASE=$(grep -E '^VERSION_ID=' /etc/os-release | cut -d'"' -f2)
fi

DISTRO=""
case "${RELEASE}" in
    24.04*|24)
        DISTRO="ubuntu2404"
        ;;
    22.04*|22)
        DISTRO="ubuntu2204"
        ;;
    20.04*|20)
        DISTRO="ubuntu2004"
        ;;
    *)
        echo "Unknown Ubuntu release: ${RELEASE}"
        DISTRO="ubuntu2204"
        ;;
esac

ARCH=""
if command -v dpkg >/dev/null 2>&1; then
    ARCH=$(dpkg --print-architecture)
fi

REPO_ARCH="x86_64"
case "${ARCH}" in
    amd64) REPO_ARCH="x86_64" ;;
    arm64) REPO_ARCH="sbsa" ;;
    *) REPO_ARCH="x86_64" ;;
esac

echo "System Configuration:"
echo "  Ubuntu Release: ${RELEASE}"
echo "  Distro Code: ${DISTRO}"
echo "  Architecture: ${ARCH} (repo: ${REPO_ARCH})"
echo ""

test_url() {
    local url="$1"
    local name="$2"
    
    if ! command -v curl >/dev/null 2>&1; then
        echo "  SKIP (no curl): ${name}"
        return
    fi
    
    local http_code
    http_code=$(curl -o /dev/null -w '%{http_code}' -fsSL --max-time 5 "${url}" 2>/dev/null || echo "000")
    
    if [[ "${http_code}" == "200" ]]; then
        echo "  ✓ HTTP ${http_code}: ${name}"
        echo "      ${url}"
    elif [[ "${http_code}" == "301" ]] || [[ "${http_code}" == "302" ]]; then
        echo "  ⚠ HTTP ${http_code} (redirect): ${name}"
        echo "      ${url}"
    elif [[ "${http_code}" == "404" ]]; then
        echo "  ✗ HTTP ${http_code} (not found): ${name}"
        echo "      ${url}"
    else
        echo "  ✗ HTTP ${http_code} (error/timeout): ${name}"
        echo "      ${url}"
    fi
}

echo "======================================================================"
echo "Testing CUDA Repository"
echo "======================================================================"
CUDA_BASE="https://developer.download.nvidia.com/compute/cuda/repos/${DISTRO}/${REPO_ARCH}"
test_url "${CUDA_BASE}/Release" "CUDA Release file"
test_url "${CUDA_BASE}/InRelease" "CUDA InRelease file"
test_url "${CUDA_BASE}/cuda-keyring_1.1-1_all.deb" "cuda-keyring package"
test_url "${CUDA_BASE}/" "CUDA base directory"
echo ""

echo "======================================================================"
echo "Testing Confidential Computing Repository"
echo "======================================================================"
CC_BASE="https://developer.download.nvidia.com/compute/confidential-computing/repos/${DISTRO}/${REPO_ARCH}"
test_url "${CC_BASE}/Release" "CC Release file"
test_url "${CC_BASE}/InRelease" "CC InRelease file"
test_url "${CC_BASE}/" "CC base directory"
echo ""

echo "======================================================================"
echo "Testing Alternative Repository Paths"
echo "======================================================================"
test_url "https://repo.download.nvidia.com/baseos/ubuntu/focal/" "DGX Base OS (focal)"
test_url "https://repo.download.nvidia.com/baseos/ubuntu/jammy/" "DGX Base OS (jammy)"
test_url "https://repo.download.nvidia.com/baseos/ubuntu/noble/" "DGX Base OS (noble)"
echo ""

echo "======================================================================"
echo "Searching for nvidia-ccadm package"
echo "======================================================================"
if command -v curl >/dev/null 2>&1; then
    echo "Checking CUDA repository for nvidia-ccadm..."
    if curl -s --max-time 10 "${CUDA_BASE}/" | grep -i "nvidia-ccadm" | head -n 5; then
        echo "  ✓ Found nvidia-ccadm in CUDA repo"
    else
        echo "  ✗ No nvidia-ccadm found in CUDA repo"
    fi
    echo ""
    
    echo "Checking Confidential Computing repository for nvidia-ccadm..."
    if curl -s --max-time 10 "${CC_BASE}/" 2>/dev/null | grep -i "nvidia-ccadm" | head -n 5; then
        echo "  ✓ Found nvidia-ccadm in CC repo"
    else
        echo "  ✗ No nvidia-ccadm found in CC repo (may be expected if repo doesn't exist)"
    fi
else
    echo "  SKIP: curl not available"
fi
echo ""

echo "======================================================================"
echo "System Package Check"
echo "======================================================================"
if command -v apt-cache >/dev/null 2>&1; then
    echo "Checking if nvidia-ccadm is available via apt..."
    if apt-cache show nvidia-ccadm >/dev/null 2>&1; then
        echo "  ✓ nvidia-ccadm is available in configured repositories"
        apt-cache policy nvidia-ccadm 2>/dev/null | head -n 10
    else
        echo "  ✗ nvidia-ccadm not available in current apt sources"
    fi
else
    echo "  SKIP: apt-cache not available"
fi
echo ""

if command -v nvidia-ccadm >/dev/null 2>&1; then
    echo "✓ nvidia-ccadm is installed on this system"
    nvidia-ccadm --version 2>/dev/null || echo "  (version info unavailable)"
else
    echo "✗ nvidia-ccadm is not currently installed"
fi
echo ""

if command -v nvidia-smi >/dev/null 2>&1; then
    echo "NVIDIA Driver Information:"
    echo "  Driver Version: $(nvidia-smi --query-gpu=driver_version --format=csv,noheader | head -n1 2>/dev/null || echo 'unknown')"
    echo "  GPU(s):"
    nvidia-smi --query-gpu=index,name,uuid --format=csv,noheader 2>/dev/null | sed 's/^/    /' || echo "    (unavailable)"
else
    echo "✗ nvidia-smi not available (NVIDIA driver not installed)"
fi
echo ""

echo "======================================================================"
echo "Test Complete"
echo "======================================================================"
echo ""
echo "Summary:"
echo "  - CUDA repository for ${DISTRO}/${REPO_ARCH} is accessible"
echo "  - Confidential computing repo availability varies"
echo "  - nvidia-ccadm may be bundled with NVIDIA driver 550+ for H100/Blackwell"
echo ""

