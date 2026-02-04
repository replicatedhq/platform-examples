#!/bin/bash
set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=================================================${NC}"
echo -e "${BLUE}  Replicated Development License Setup${NC}"
echo -e "${BLUE}=================================================${NC}"
echo ""

# Check prerequisites
echo -e "${YELLOW}[1/4] Checking prerequisites...${NC}"
command -v replicated >/dev/null 2>&1 || {
    echo -e "${RED}✗ Replicated CLI is required${NC}"
    echo ""
    echo "Install it with:"
    echo "  brew install replicatedhq/replicated/cli"
    echo "  # or"
    echo "  curl -s https://api.github.com/repos/replicatedhq/replicated/releases/latest | grep \"browser_download_url.*$(uname -s)_$(uname -m)\" | cut -d '\"' -f 4 | xargs curl -L -o replicated && chmod +x replicated && sudo mv replicated /usr/local/bin/"
    exit 1
}
echo -e "${GREEN}✓ Replicated CLI installed${NC}"
echo ""

# Check API token
echo -e "${YELLOW}[2/4] Checking Replicated API token...${NC}"
if [ -z "$REPLICATED_API_TOKEN" ]; then
    echo -e "${YELLOW}⚠ REPLICATED_API_TOKEN not set${NC}"
    echo ""
    echo "To obtain an API token:"
    echo "  1. Log in to vendor.replicated.com"
    echo "  2. Go to Settings > Service Accounts"
    echo "  3. Create a new token"
    echo "  4. Export it: export REPLICATED_API_TOKEN=your-token"
    echo ""
    read -p "Enter your Replicated API token: " api_token
    export REPLICATED_API_TOKEN="$api_token"
fi
echo -e "${GREEN}✓ API token configured${NC}"
echo ""

# Set up application
APP_SLUG="${REPLICATED_APP_SLUG:-flipt}"
CUSTOMER_NAME="${CUSTOMER_NAME:-dev-$(whoami)-$(date +%s)}"
CHANNEL="${CHANNEL:-Unstable}"

echo -e "${YELLOW}[3/4] Creating development customer...${NC}"
echo "  App: $APP_SLUG"
echo "  Customer: $CUSTOMER_NAME"
echo "  Channel: $CHANNEL"
echo ""

# Create customer with dev license
replicated customer create \
    --app "$APP_SLUG" \
    --name "$CUSTOMER_NAME" \
    --channel "$CHANNEL" \
    --license-type dev \
    --output json > /tmp/customer.json 2>&1 || {
    echo -e "${RED}✗ Failed to create customer${NC}"
    cat /tmp/customer.json
    exit 1
}

LICENSE_ID=$(jq -r '.id' /tmp/customer.json)
echo -e "${GREEN}✓ Customer created${NC}"
echo ""

# Save license ID
echo -e "${YELLOW}[4/4] Saving license configuration...${NC}"
mkdir -p .replicated
echo "REPLICATED_LICENSE_ID=$LICENSE_ID" > .replicated/license.env
echo "REPLICATED_APP_SLUG=$APP_SLUG" >> .replicated/license.env
echo "CUSTOMER_NAME=$CUSTOMER_NAME" >> .replicated/license.env
echo "CHANNEL=$CHANNEL" >> .replicated/license.env

cat > .replicated/README.md <<EOF
# Development License

This directory contains your Replicated development license configuration.

**License ID:** \`$LICENSE_ID\`
**Customer:** \`$CUSTOMER_NAME\`
**Channel:** \`$CHANNEL\`

## Usage

Source the license environment before installing:

\`\`\`bash
source .replicated/license.env
./scripts/install.sh
\`\`\`

Or use the Makefile:

\`\`\`bash
make install-with-license
\`\`\`

## Cleanup

To remove this development license:

\`\`\`bash
replicated customer rm --customer "$CUSTOMER_NAME"
rm -rf .replicated/
\`\`\`

## License Expiry

Development licenses typically expire after a certain period.
Recreate as needed with:

\`\`\`bash
./scripts/setup-dev-license.sh
\`\`\`
EOF

echo -e "${GREEN}✓ License configuration saved to .replicated/license.env${NC}"
echo ""

echo -e "${GREEN}=================================================${NC}"
echo -e "${GREEN}  Setup Complete!${NC}"
echo -e "${GREEN}=================================================${NC}"
echo ""
echo -e "${BLUE}License ID:${NC} $LICENSE_ID"
echo -e "${BLUE}Customer Name:${NC} $CUSTOMER_NAME"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo ""
echo "  1. Load the license:"
echo -e "     ${YELLOW}source .replicated/license.env${NC}"
echo ""
echo "  2. Install Flipt:"
echo -e "     ${YELLOW}./scripts/install.sh${NC}"
echo ""
echo "  3. Access Flipt:"
echo -e "     ${YELLOW}kubectl port-forward -n flipt svc/flipt-flipt 8080:8080${NC}"
echo ""
