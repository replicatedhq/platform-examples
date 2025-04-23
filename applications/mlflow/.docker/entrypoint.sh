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

# Function to create a Kind cluster if needed
setup_kind_cluster() {
  echo "Setting up Kind Kubernetes cluster..."
  # Check if kind is installed
  if ! command -v kind &> /dev/null; then
    echo "Error: kind not found. Cannot create cluster."
    return 1
  fi

  # Create a basic kind config
  cat > /tmp/kind-config.yaml << EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  extraPortMappings:
  - containerPort: 30080
    hostPort: 30080
EOF

  # Create the cluster
  echo "Creating kind cluster 'mlflow-dev'..."
  kind create cluster --name mlflow-dev --config /tmp/kind-config.yaml --wait 2m

  # Update kubeconfig
  mkdir -p ~/.kube
  kind get kubeconfig --name mlflow-dev > ~/.kube/config
  chmod 600 ~/.kube/config
  
  echo "✅ Kind cluster 'mlflow-dev' created and configured."
  echo "Kubernetes context set to kind-mlflow-dev"
}

# Check for kube config and offer to create kind cluster if none found
if [ ! -f ~/.kube/config ]; then
  echo "Warning: No Kubernetes config file found."
  
  # Check if USE_KIND is set to true
  if [ "${USE_KIND:-}" = "true" ]; then
    echo "USE_KIND is set, creating local Kind cluster..."
    setup_kind_cluster
  else
    echo "To use a local Kind cluster, restart with:"
    echo "USE_KIND=true task dev:shell"
    echo ""
    echo "Alternatively, ensure ~/.kube/config is mounted from host."
  fi
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
- Directories from host are mounted in /app

Kubernetes Setup:
$(if [ "${USE_KIND:-}" = "true" ]; then echo "- Using local Kind cluster 'mlflow-dev'"; else echo "- Using host's Kubernetes config"; fi)

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