#!/bin/bash
set -e

# Set essential environment variables
export SHELL=/bin/bash
export HOME=${HOME:-/home/devuser}
export USER=${USER:-devuser}

# Trap to ensure clean exit
trap 'exit 0' EXIT

# Basic initialization
echo "Initializing development environment..."

# Check for kube config and warn if none found
if [ ! -f ~/.kube/config ]; then
  echo "Warning: No Kubernetes config file found."
  echo "Ensure ~/.kube/config is mounted from host."
else
  echo "Found Kubernetes config. Using existing configuration."
fi

# Check for Helm config and warn if not found
if [ ! -d ~/.config/helm ]; then
  echo "Warning: No Helm configuration found. If you need Helm repos, please ensure ~/.config/helm is mounted."
fi

# Network mode information
NETWORK_MODE="Container network"
if [ "${HOST_NETWORK:-false}" = "true" ]; then
  NETWORK_MODE="Host network (ports opened in container are accessible on host)"
fi

# Print welcome message
cat << EOF
======================================================
MLflow Development Environment
------------------------------------------------------
- All required tools are pre-installed:
  * task, helm, kubectl, yq, jq, etc.
- Use 'task --list' to see available tasks
- Directories from host are mounted in /workspace

Kubernetes Setup:
- Using host's Kubernetes config

Networking:
- ${NETWORK_MODE}
======================================================
EOF

# Print environment debug information
echo "Environment:"
echo "- SHELL: $SHELL"
echo "- HOME: $HOME" 
echo "- USER: $USER"
echo "- PATH: $PATH"
echo ""

# Run the command
exec "$@" 