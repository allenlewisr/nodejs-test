#!/bin/bash

# Script to verify artifact attestation and display actor information
# Usage: ./verify-artifact-attestation.sh <artifact_path> <jfrog_repo_name>
# Example: ./verify-artifact-attestation.sh "nodejs-template/-/nodejs-template-1.0.1.tgz" "nodejs-test-npm-local-dev"

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# GitHub owner for attestation verification
GITHUB_OWNER="allenlewisr"

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
check_command gh
check_command jq
check_command base64
success "All required tools are available"

# Validate parameters
if [ $# -lt 2 ]; then
    echo "Usage: $0 <artifact_path> <jfrog_repo_name>"
    echo ""
    echo "Parameters:"
    echo "  artifact_path     - Full artifact path (e.g., nodejs-template/-/nodejs-template-1.0.1.tgz)"
    echo "  jfrog_repo_name   - JFrog repository name (e.g., nodejs-test-npm-local-dev)"
    echo ""
    echo "Example:"
    echo "  $0 'nodejs-template/-/nodejs-template-1.0.1.tgz' 'nodejs-test-npm-local-dev'"
    exit 1
fi

ARTIFACT_PATH="$1"
JFROG_REPO_NAME="$2"
FULL_PATH="${JFROG_REPO_NAME}/${ARTIFACT_PATH}"

# Extract artifact filename
ARTIFACT_FILE=$(basename "$ARTIFACT_PATH")

echo ""
echo "==================================================================="
echo "       Artifact Attestation Verification and Actor Extraction"
echo "==================================================================="
echo ""
info "Artifact Path: ${ARTIFACT_PATH}"
info "JFrog Repo: ${JFROG_REPO_NAME}"
info "Full Path: ${FULL_PATH}"
echo ""

# Setup cleanup trap to remove artifact on exit (success or failure)
cleanup() {
    if [ -f "$ARTIFACT_FILE" ]; then
        rm -f "$ARTIFACT_FILE"
    fi
}
trap cleanup EXIT

# Clean up previous downloads
if [ -f "$ARTIFACT_FILE" ]; then
    info "Removing existing artifact file..."
    rm -f "$ARTIFACT_FILE"
fi

# Step 1: Download artifact from JFrog
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 1: Downloading artifact from JFrog"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

info "Downloading: ${FULL_PATH}"
if jf rt download "${FULL_PATH}" --flat > /dev/null 2>&1; then
    success "Artifact downloaded successfully"
else
    error "Failed to download artifact from JFrog. Check the path and repository name."
fi

# Verify file exists
if [ ! -f "$ARTIFACT_FILE" ]; then
    error "Downloaded file not found: ${ARTIFACT_FILE}"
fi

# Display file info
FILE_SIZE=$(ls -lh "$ARTIFACT_FILE" | awk '{print $5}')
FILE_SHA256=$(shasum -a 256 "$ARTIFACT_FILE" | awk '{print $1}')
info "File: ${ARTIFACT_FILE} (${FILE_SIZE})"
info "SHA256: ${FILE_SHA256}"
echo ""

# Step 2: Verify attestation
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 2: Verifying attestation"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

info "Verifying with GitHub owner: ${GITHUB_OWNER}"
if gh attestation verify "$ARTIFACT_FILE" --owner "$GITHUB_OWNER" > /dev/null 2>&1; then
    success "Attestation verification succeeded!"
else
    error "Attestation verification failed. The artifact may not have a valid attestation."
fi
echo ""

# Step 3: Get attestation bundle information
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 3: Extracting actor information from attestation"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Verify attestation and get JSON output
info "Retrieving attestation details..."
ATTESTATION_JSON=$(gh attestation verify "$ARTIFACT_FILE" --owner "$GITHUB_OWNER" --format json 2>/dev/null || echo "")

if [ -z "$ATTESTATION_JSON" ]; then
    error "Failed to retrieve attestation JSON"
fi

# The attestation JSON contains the verification results
# We need to look for the actor attestation in the verifications array
ACTOR_PREDICATE=$(echo "$ATTESTATION_JSON" | jq -r '
    .verifications[]? 
    | select(.predicateType? // .statement?.predicateType? | contains("actor"))
    | .statement?.predicate? // .predicate?
    | select(. != null)
' | head -n 1)

# If not found in verifications, try the bundle directly
if [ -z "$ACTOR_PREDICATE" ] || [ "$ACTOR_PREDICATE" = "null" ]; then
    info "Extracting from attestation bundle..."
    
    # Get the bundle path from the verification
    BUNDLE_PATH=$(echo "$ATTESTATION_JSON" | jq -r '.verifications[0]?.signature? // empty' | grep -o 'sha256:[a-f0-9]*\.jsonl' || echo "")
    
    if [ -n "$BUNDLE_PATH" ]; then
        # Try to read the bundle if it exists locally or download it
        if [ -f "$BUNDLE_PATH" ]; then
            ACTOR_PREDICATE=$(cat "$BUNDLE_PATH" | jq -r '
                select(.dsseEnvelope.payload != null)
                | .dsseEnvelope.payload
            ' | base64 -d 2>/dev/null | jq -r '
                select(.predicateType | contains("actor"))
                | .predicate
            ' | head -n 1)
        fi
    fi
fi

# Alternative: Parse from the raw attestation output
if [ -z "$ACTOR_PREDICATE" ] || [ "$ACTOR_PREDICATE" = "null" ]; then
    # Try to extract from statement directly
    ACTOR_PREDICATE=$(echo "$ATTESTATION_JSON" | jq -r '
        .verifications[]?.statement?
        | select(.predicateType | contains("actor"))
        | .predicate
    ' | head -n 1)
fi

if [ -z "$ACTOR_PREDICATE" ] || [ "$ACTOR_PREDICATE" = "null" ] || [ "$ACTOR_PREDICATE" = "" ]; then
    echo -e "${YELLOW}⚠️  Warning: Could not extract actor predicate from attestation${NC}"
    echo ""
    info "Displaying all available attestation information:"
    echo "$ATTESTATION_JSON" | jq -r '.verifications[]? | {predicateType: (.predicateType? // .statement?.predicateType?), predicate: (.predicate? // .statement?.predicate?)}' | head -20
    echo ""
    info "Note: The attestation exists and is valid, but actor information may not be available."
    exit 0
fi

# Step 4: Display actor information
echo ""
echo "==================================================================="
echo "                   Actor Attestation Information"
echo "==================================================================="
echo ""

# Parse and display actor information
ACTOR=$(echo "$ACTOR_PREDICATE" | jq -r '.actor // "N/A"')
ACTOR_ID=$(echo "$ACTOR_PREDICATE" | jq -r '.actorId // "N/A"')
TRIGGERED_BY=$(echo "$ACTOR_PREDICATE" | jq -r '.triggeredBy // "N/A"')
REPOSITORY=$(echo "$ACTOR_PREDICATE" | jq -r '.repository // "N/A"')
COMMIT=$(echo "$ACTOR_PREDICATE" | jq -r '.commit // "N/A"')
WORKFLOW=$(echo "$ACTOR_PREDICATE" | jq -r '.workflow // "N/A"')
RUN_ID=$(echo "$ACTOR_PREDICATE" | jq -r '.runId // "N/A"')
RUN_NUMBER=$(echo "$ACTOR_PREDICATE" | jq -r '.runNumber // "N/A"')
TIMESTAMP=$(echo "$ACTOR_PREDICATE" | jq -r '.timestamp // "N/A"')

printf "%-20s %s\n" "Actor:" "$ACTOR"
printf "%-20s %s\n" "Actor ID:" "$ACTOR_ID"
printf "%-20s %s\n" "Triggered By:" "$TRIGGERED_BY"
printf "%-20s %s\n" "Repository:" "$REPOSITORY"
printf "%-20s %s\n" "Commit:" "$COMMIT"
printf "%-20s %s\n" "Workflow:" "$WORKFLOW"
printf "%-20s %s\n" "Run ID:" "$RUN_ID"
printf "%-20s %s\n" "Run Number:" "$RUN_NUMBER"
printf "%-20s %s\n" "Timestamp:" "$TIMESTAMP"

echo ""
echo "==================================================================="
success "Attestation verification and extraction complete!"
echo "==================================================================="
echo ""

# Note: Cleanup happens automatically via trap on EXIT
success "Done!"

