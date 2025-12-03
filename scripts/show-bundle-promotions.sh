#!/bin/bash

# Script to display release bundle promotion history with approval details
# Usage: ./show-bundle-promotions.sh <bundle_name> [bundle_version]
# Example: ./show-bundle-promotions.sh "nodejs-test" "1.0.1+build.1"
#          ./show-bundle-promotions.sh "nodejs-test" (uses latest version)

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Function to print error messages
error() {
    echo -e "${RED}❌ ERROR: $1${NC}" >&2
    exit 1
}

# Function to print info messages
info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# Function to print success messages
success() {
    echo -e "${GREEN}✓ $1${NC}"
}

# Function to check if a command exists
check_command() {
    if ! command -v "$1" &> /dev/null; then
        error "$1 is not installed. Please install it first."
    fi
}

# Validate required tools
info "Checking required tools..."
check_command jf
check_command jq
success "All required tools are available"

# Validate parameters
if [ $# -lt 1 ]; then
    echo "Usage: $0 <bundle_name> [bundle_version]"
    echo ""
    echo "Parameters:"
    echo "  bundle_name       - Release bundle name (required)"
    echo "  bundle_version    - Bundle version (optional, defaults to latest)"
    echo ""
    echo "Examples:"
    echo "  $0 'nodejs-test' '1.0.1+build.1'"
    echo "  $0 'nodejs-test'                   # Uses latest version"
    exit 1
fi

BUNDLE_NAME="$1"
BUNDLE_VERSION="${2:-}"

echo ""
echo "==================================================================="
echo "            Release Bundle Promotion History"
echo "==================================================================="
echo ""

# If version not provided, get the latest version
if [ -z "$BUNDLE_VERSION" ]; then
    info "No version specified, retrieving latest version..."
    
    # Get all versions for this bundle
    VERSIONS_JSON=$(jf rt curl -XGET "/api/v2/release_bundle/${BUNDLE_NAME}" --silent --fail 2>&1)
    
    if [ $? -ne 0 ]; then
        error "Failed to retrieve bundle information for '${BUNDLE_NAME}'. Bundle may not exist."
    fi
    
    # Extract the latest version (first in the list)
    BUNDLE_VERSION=$(echo "$VERSIONS_JSON" | jq -r '.versions[0].version // empty' 2>/dev/null)
    
    if [ -z "$BUNDLE_VERSION" ] || [ "$BUNDLE_VERSION" = "null" ]; then
        error "No versions found for bundle '${BUNDLE_NAME}'"
    fi
    
    success "Found latest version: ${BUNDLE_VERSION}"
fi

echo ""
info "Bundle Name: ${BUNDLE_NAME}"
info "Bundle Version: ${BUNDLE_VERSION}"
echo ""

# Get promotion records
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
info "Retrieving promotion records from JFrog..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

PROMOTION_JSON=$(jf rt curl -XGET "/api/v2/promotion/records/${BUNDLE_NAME}/${BUNDLE_VERSION}" --silent --fail 2>&1)

if [ $? -ne 0 ]; then
    error "Failed to retrieve promotion records. Bundle may not exist or has no promotions."
fi

# Check if there are any promotions
PROMOTION_COUNT=$(echo "$PROMOTION_JSON" | jq '.promotions | length' 2>/dev/null || echo "0")

if [ "$PROMOTION_COUNT" = "0" ] || [ "$PROMOTION_COUNT" = "null" ]; then
    echo ""
    echo -e "${YELLOW}⚠️  No promotions found for this bundle${NC}"
    echo ""
    info "Bundle exists but has not been promoted yet."
    exit 0
fi

success "Found ${PROMOTION_COUNT} promotion(s)"
echo ""

# Parse promotion data and format as table
echo "==================================================================="
echo "                        Promotion Details"
echo "==================================================================="
echo ""

# Create temporary file for table data
TEMP_FILE=$(mktemp)

# Setup cleanup trap to remove temp file on exit (success or failure)
cleanup() {
    if [ -n "$TEMP_FILE" ] && [ -f "$TEMP_FILE" ]; then
        rm -f "$TEMP_FILE"
    fi
}
trap cleanup EXIT

# Extract promotion information and write to temp file
echo "$PROMOTION_JSON" | jq -r '
    .promotions[]
    | [
        (.environment // "N/A"),
        (.status // "N/A"),
        (.created_by // "N/A"),
        (.created // "N/A")
    ]
    | @tsv
' | while IFS=$'\t' read -r environment status created_by created; do
    # Format timestamp (remove milliseconds and T)
    formatted_time=$(echo "$created" | sed 's/T/ /' | cut -d'.' -f1)
    
    echo "$environment|$status|$created_by|$formatted_time" >> "$TEMP_FILE"
done

# Display table header
printf "${CYAN}%-15s${NC} ${CYAN}%-15s${NC} ${CYAN}%-20s${NC} ${CYAN}%-20s${NC}\n" "Environment" "Status" "Created By" "Timestamp"
echo "───────────────────────────────────────────────────────────────────────────"

# Display table rows
while IFS='|' read -r env status creator timestamp; do
    # Color code based on status
    if [ "$status" = "COMPLETED" ]; then
        STATUS_COLORED="${GREEN}${status}${NC}"
    elif [ "$status" = "IN_PROGRESS" ]; then
        STATUS_COLORED="${YELLOW}${status}${NC}"
    else
        STATUS_COLORED="${RED}${status}${NC}"
    fi
    
    printf "%-15s ${STATUS_COLORED}%-15s${NC} %-20s %-20s\n" "$env" "" "$creator" "$timestamp"
done < "$TEMP_FILE"

echo ""

# Build promotion path
PROMOTION_PATH=$(cat "$TEMP_FILE" | cut -d'|' -f1 | tr '\n' ' ' | sed 's/ / → /g' | sed 's/ → $//')

if [ -n "$PROMOTION_PATH" ]; then
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${CYAN}Promotion Path:${NC} ${PROMOTION_PATH}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
fi

# Get additional details for each promotion (including source environment)
echo ""
echo "==================================================================="
echo "                    Detailed Promotion Information"
echo "==================================================================="
echo ""

# Parse and display detailed information for each promotion
PROMOTION_INDEX=0
echo "$PROMOTION_JSON" | jq -c '.promotions[]' | while read -r promotion; do
    PROMOTION_INDEX=$((PROMOTION_INDEX + 1))
    
    TARGET_ENV=$(echo "$promotion" | jq -r '.environment // "N/A"')
    STATUS=$(echo "$promotion" | jq -r '.status // "N/A"')
    CREATED_BY=$(echo "$promotion" | jq -r '.created_by // "N/A"')
    CREATED=$(echo "$promotion" | jq -r '.created // "N/A"' | sed 's/T/ /' | cut -d'.' -f1)
    
    # Try to determine source environment (previous promotion's target or BUILD)
    if [ $PROMOTION_INDEX -eq 1 ]; then
        SOURCE_ENV="BUILD"
    else
        SOURCE_ENV=$(echo "$PROMOTION_JSON" | jq -r ".promotions[$((PROMOTION_INDEX - 2))].environment // \"UNKNOWN\"")
    fi
    
    echo -e "${CYAN}Promotion #${PROMOTION_INDEX}:${NC}"
    printf "  %-20s %s\n" "Source:" "$SOURCE_ENV"
    printf "  %-20s %s\n" "Target:" "$TARGET_ENV"
    printf "  %-20s %s\n" "Triggered By:" "$CREATED_BY"
    printf "  %-20s %s\n" "Status:" "$STATUS"
    printf "  %-20s %s\n" "Timestamp:" "$CREATED"
    
    # Note: The JFrog API doesn't directly provide "approved by" information in promotion records
    # This would typically come from GitHub Actions workflow or environment approvals
    echo -e "  ${YELLOW}Note: Approval details are tracked in GitHub Actions workflow runs${NC}"
    
    echo ""
done

echo "==================================================================="
success "Promotion history retrieval complete!"
echo "==================================================================="
echo ""

# Additional information
echo -e "${BLUE}Additional Information:${NC}"
echo "  • To verify promotion attestations, check: https://github.com/<owner>/<repo>/attestations"
echo "  • Approval details are stored in GitHub Actions environment approvals"
echo "  • For detailed approval information, check the GitHub Actions workflow runs"
echo ""

