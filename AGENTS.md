# Cerumbra Agent Operating Notes

- Always commit and push every set of changes immediately after completing the requested update. Do not leave local-only work in the tree.
- When conversations become lengthy, record any notable decisions, context, or follow-up actions in this file so future agents have a quick reference.
- **Never put files in /tmp/** - Use workspace directory for all temporary/log files. /tmp/ is not appropriate for build artifacts, logs, or any project-related files.

## Recent Work

### Oct 22, 2025 - ccadm-setup.sh Fixes & DGX Spark GB10 Limitation Discovery
- **Fixed critical syntax error**: Line 375 had `}` instead of `esac` in case statement
- **Repository investigation**: Tested all NVIDIA repo URLs - CUDA repos work (HTTP 200), but confidential computing repos return 404
- **⚠️ CRITICAL FINDING**: DGX Spark with GB10 chip **DOES NOT support confidential computing** - confirmed by NVIDIA (https://forums.developer.nvidia.com/t/confidential-computing-support-for-dgx-spark-gb10/347945)
- **Hardware requirements**: Confidential computing requires H100 GPUs + compatible CPU (AMD SEV-SNP or Intel TDX)
- **Script updates**: Now detects GB10 and exits with clear warning; removes /tmp/ usage (uses .cerumbra-logs/ instead); graceful CC repo failure handling
- **Created test-nvidia-repos.sh**: Systematic verification script for repository availability
- **Documentation**: CCADM-SETUP-FIXES.md updated with GB10 limitation details
- **Impact**: Cerumbra will run in simulation mode on DGX Spark; real TEE support requires H100-based hardware
