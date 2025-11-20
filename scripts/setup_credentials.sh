#!/bin/bash
#
# Credential Setup Helper for Notarization
# This script helps you securely store your Apple ID and app-specific password
#

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  Notarization Credentials Setup${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Get Apple ID
echo -e "${YELLOW}Step 1: Apple ID${NC}"
echo "Enter your Apple Developer account email:"
read -r APPLE_ID
echo ""

# Get app-specific password
echo -e "${YELLOW}Step 2: App-Specific Password${NC}"
echo "Enter your app-specific password (format: xxxx-xxxx-xxxx-xxxx):"
read -r APP_SPECIFIC_PASSWORD
echo ""

# Store in keychain (more secure than environment variables)
echo -e "${YELLOW}Storing credentials in macOS Keychain...${NC}"

# Store Apple ID in keychain
security add-generic-password \
    -a "$APPLE_ID" \
    -s "VideoCullingApp_Notarization_AppleID" \
    -w "$APPLE_ID" \
    -U 2>/dev/null || \
security delete-generic-password \
    -s "VideoCullingApp_Notarization_AppleID" 2>/dev/null && \
security add-generic-password \
    -a "$APPLE_ID" \
    -s "VideoCullingApp_Notarization_AppleID" \
    -w "$APPLE_ID" \
    -U

# Store app-specific password in keychain
security add-generic-password \
    -a "$APPLE_ID" \
    -s "VideoCullingApp_Notarization_Password" \
    -w "$APP_SPECIFIC_PASSWORD" \
    -U 2>/dev/null || \
security delete-generic-password \
    -s "VideoCullingApp_Notarization_Password" 2>/dev/null && \
security add-generic-password \
    -a "$APPLE_ID" \
    -s "VideoCullingApp_Notarization_Password" \
    -w "$APP_SPECIFIC_PASSWORD" \
    -U

echo -e "${GREEN}✓${NC} Credentials stored securely in macOS Keychain"
echo ""

# Create a helper file to export these as environment variables
CREDENTIAL_FILE="$(dirname "$0")/.notarization_env"
cat > "$CREDENTIAL_FILE" << EOF
#!/bin/bash
# Source this file to set notarization credentials
# Usage: source scripts/.notarization_env

export APPLE_ID="$APPLE_ID"
export APP_SPECIFIC_PASSWORD="\$(security find-generic-password -s 'VideoCullingApp_Notarization_Password' -w 2>/dev/null)"

if [ -z "\$APP_SPECIFIC_PASSWORD" ]; then
    echo "⚠️  Could not retrieve password from keychain"
    echo "Run: ./scripts/setup_credentials.sh"
    exit 1
fi
EOF

chmod +x "$CREDENTIAL_FILE"

echo -e "${GREEN}✓${NC} Created credential helper: scripts/.notarization_env"
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅ Setup Complete!${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "To notarize your app, run:"
echo -e "${YELLOW}  source scripts/.notarization_env${NC}"
echo -e "${YELLOW}  ./scripts/notarize_and_package.sh${NC}"
echo ""
