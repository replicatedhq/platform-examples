#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

NAMESPACE="${NAMESPACE:-flipt}"
RELEASE_NAME="${RELEASE_NAME:-flipt}"

# Check for Replicated license
if [ -f ".replicated/license.env" ]; then
    echo -e "${BLUE}Loading Replicated license from .replicated/license.env${NC}"
    source .replicated/license.env
fi

if [ -z "$REPLICATED_LICENSE_ID" ]; then
    echo -e "${RED}=================================================${NC}"
    echo -e "${RED}  Replicated License Required${NC}"
    echo -e "${RED}=================================================${NC}"
    echo ""
    echo -e "${YELLOW}This application requires a Replicated development license.${NC}"
    echo ""
    echo "To set up a development license:"
    echo ""
    echo "  1. Run the license setup script:"
    echo -e "     ${YELLOW}./scripts/setup-dev-license.sh${NC}"
    echo ""
    echo "  2. Load the license:"
    echo -e "     ${YELLOW}source .replicated/license.env${NC}"
    echo ""
    echo "  3. Re-run this installation:"
    echo -e "     ${YELLOW}./scripts/install.sh${NC}"
    echo ""
    echo "Or set it manually:"
    echo -e "  ${YELLOW}export REPLICATED_LICENSE_ID=your-license-id${NC}"
    echo ""
    exit 1
fi

echo -e "${GREEN}✓ Replicated license configured: $REPLICATED_LICENSE_ID${NC}"
echo ""

echo -e "${BLUE}=================================================${NC}"
echo -e "${BLUE}     Flipt Feature Flags Installation${NC}"
echo -e "${BLUE}=================================================${NC}"
echo ""

# Step 1: Check prerequisites
echo -e "${YELLOW}[1/7] Checking prerequisites...${NC}"
command -v kubectl >/dev/null 2>&1 || { echo -e "${RED}✗ kubectl is required but not installed${NC}"; exit 1; }
command -v helm >/dev/null 2>&1 || { echo -e "${RED}✗ helm is required but not installed${NC}"; exit 1; }
echo -e "${GREEN}✓ Prerequisites satisfied${NC}"
echo ""

# Step 2: Check if operator is installed
echo -e "${YELLOW}[2/7] Checking CloudNativePG operator...${NC}"
if kubectl get deployment cnpg-cloudnative-pg -n cnpg-system >/dev/null 2>&1; then
    echo -e "${GREEN}✓ CloudNativePG operator already installed${NC}"
else
    echo -e "${YELLOW}⚠ CloudNativePG operator not found. Installing...${NC}"

    # Add CNPG repo
    helm repo add cnpg https://cloudnative-pg.github.io/charts >/dev/null 2>&1 || true
    helm repo update >/dev/null 2>&1

    # Install operator
    helm upgrade --install cnpg \
        --namespace cnpg-system \
        --create-namespace \
        cnpg/cloudnative-pg

    # Wait for operator to be ready
    echo -e "${YELLOW}  Waiting for operator to be ready...${NC}"
    kubectl wait --for=condition=available --timeout=300s \
        deployment/cnpg-cloudnative-pg \
        -n cnpg-system 2>/dev/null || true

    echo -e "${GREEN}✓ Operator installed successfully${NC}"
fi
echo ""

# Step 3: Add Helm repositories
echo -e "${YELLOW}[3/7] Adding Helm repositories...${NC}"
helm repo add flipt https://helm.flipt.io >/dev/null 2>&1 || true
helm repo add bitnami https://charts.bitnami.com/bitnami >/dev/null 2>&1 || true
helm repo add replicated https://charts.replicated.com >/dev/null 2>&1 || true
helm repo update >/dev/null 2>&1
echo -e "${GREEN}✓ Repositories added${NC}"
echo ""

# Step 4: Clean and update dependencies
echo -e "${YELLOW}[4/7] Updating chart dependencies...${NC}"
cd chart

# Remove any cached cloudnative-pg dependency
rm -f charts/cloudnative-pg-*.tgz 2>/dev/null || true
rm -f Chart.lock 2>/dev/null || true

# Update dependencies
helm dependency update
cd ..
echo -e "${GREEN}✓ Dependencies updated${NC}"
echo ""

# Step 5: Configure Replicated SDK
echo -e "${YELLOW}[5/7] Configuring Replicated SDK...${NC}"
kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -
kubectl create secret generic replicated-license \
    --from-literal=license="$REPLICATED_LICENSE_ID" \
    --namespace "${NAMESPACE}" \
    --dry-run=client -o yaml | kubectl apply -f -
echo -e "${GREEN}✓ Replicated SDK configured${NC}"
echo ""

# Step 6: Install Flipt
echo -e "${YELLOW}[6/7] Installing Flipt...${NC}"
helm upgrade --install "${RELEASE_NAME}" ./chart \
    --namespace "${NAMESPACE}" \
    --create-namespace \
    --wait \
    --timeout 10m \
    "$@"

echo -e "${GREEN}✓ Flipt installed successfully${NC}"
echo ""

# Step 7: Show status
echo -e "${YELLOW}[7/7] Checking deployment status...${NC}"
kubectl get pods -n "${NAMESPACE}"
echo ""

# Show next steps
echo -e "${GREEN}=================================================${NC}"
echo -e "${GREEN}     Installation Complete!${NC}"
echo -e "${GREEN}=================================================${NC}"
echo ""
echo -e "${BLUE}Access Flipt:${NC}"
echo ""
echo -e "  1. Port-forward to the service:"
echo -e "     ${YELLOW}kubectl port-forward -n ${NAMESPACE} svc/${RELEASE_NAME}-flipt 8080:8080${NC}"
echo ""
echo -e "  2. Open your browser:"
echo -e "     ${YELLOW}http://localhost:8080${NC}"
echo ""
echo -e "${BLUE}Useful commands:${NC}"
echo ""
echo -e "  View pods:     ${YELLOW}kubectl get pods -n ${NAMESPACE}${NC}"
echo -e "  View logs:     ${YELLOW}kubectl logs -l app.kubernetes.io/name=flipt -n ${NAMESPACE} -f${NC}"
echo -e "  View database: ${YELLOW}kubectl get cluster -n ${NAMESPACE}${NC}"
echo -e "  Uninstall:     ${YELLOW}helm uninstall ${RELEASE_NAME} -n ${NAMESPACE}${NC}"
echo ""
