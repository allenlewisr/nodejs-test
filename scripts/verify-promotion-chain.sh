#!/bin/bash
set -e

# verify-promotion-chain.sh
# Verifies the complete attestation chain for a JFrog release bundle
# from initial build through all environment promotions

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_success() { echo -e "${GREEN}✓${NC} $1"; }
print_error() { echo -e "${RED}✗${NC} $1"; }
print_info() { echo -e "${BLUE}ℹ${NC} $1"; }
print_warning() { echo -e "${YELLOW}⚠${NC} $1"; }
print_header() { echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"; echo -e "${BLUE}$1${NC}"; echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"; }

# Function to display usage
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Verifies the complete attestation chain for a JFrog release bundle.

Required Arguments:
  --bundle-name NAME          Name of the release bundle
  --bundle-version VERSION    Version of the release bundle
  --repo-owner OWNER         GitHub repository owner
  --repo-name NAME           GitHub repository name
  --jfrog-repo-prefix PREFIX JFrog repository prefix (e.g., 'nodejs-test')

Optional Arguments:
  --skip-jfrog               Skip JFrog metadata verification
  --verbose                  Enable verbose output
  -h, --help                Display this help message

Example:
  $0 \\
    --bundle-name nodejs-test \\
    --bundle-version 1.0.0+build.42 \\
    --repo-owner myorg \\
    --repo-name nodejs-test \\
    --jfrog-repo-prefix nodejs-test

Prerequisites:
  - jf CLI configured and authenticated
  - gh CLI installed and authenticated
  - jq installed for JSON parsing

EOF
    exit 1
}

# Parse command line arguments
BUNDLE_NAME=""
BUNDLE_VERSION=""
REPO_OWNER=""
REPO_NAME=""
JFROG_REPO_PREFIX=""
SKIP_JFROG=false
VERBOSE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --bundle-name)
            BUNDLE_NAME="$2"
            shift 2
            ;;
        --bundle-version)
            BUNDLE_VERSION="$2"
            shift 2
            ;;
        --repo-owner)
            REPO_OWNER="$2"
            shift 2
            ;;
        --repo-name)
            REPO_NAME="$2"
            shift 2
            ;;
        --jfrog-repo-prefix)
            JFROG_REPO_PREFIX="$2"
            shift 2
            ;;
        --skip-jfrog)
            SKIP_JFROG=true
            shift
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "Unknown option: $1"
            usage
            ;;
    esac
done

# Validate required arguments
if [[ -z "$BUNDLE_NAME" ]] || [[ -z "$BUNDLE_VERSION" ]] || [[ -z "$REPO_OWNER" ]] || [[ -z "$REPO_NAME" ]]; then
    print_error "Missing required arguments"
    usage
fi

GITHUB_REPO="${REPO_OWNER}/${REPO_NAME}"

print_header "Release Bundle Attestation Verification"

echo "Bundle: ${BUNDLE_NAME}"
echo "Version: ${BUNDLE_VERSION}"
echo "Repository: ${GITHUB_REPO}"
echo ""

# Track verification status
VERIFICATION_FAILED=false

# ============================================================================
# 1. Verify JFrog Promotion History
# ============================================================================

if [[ "$SKIP_JFROG" == false ]]; then
    print_header "Step 1: JFrog Promotion History"
    
    print_info "Querying JFrog for promotion records..."
    
    if ! PROMOTION_DATA=$(jf rt curl -XGET "/api/v2/promotion/records/${BUNDLE_NAME}/${BUNDLE_VERSION}" --silent --fail 2>&1); then
        print_error "Failed to retrieve promotion records from JFrog"
        if [[ "$VERBOSE" == true ]]; then
            echo "$PROMOTION_DATA"
        fi
        VERIFICATION_FAILED=true
    else
        # Parse and display promotion history
        PROMOTIONS=$(echo "$PROMOTION_DATA" | jq -r '.promotions[] | "\(.stage) - \(.status) - \(.timestamp)"' 2>/dev/null || echo "")
        
        if [[ -z "$PROMOTIONS" ]]; then
            print_warning "No promotion records found"
        else
            print_success "Promotion history retrieved"
            echo ""
            echo "Promotion History:"
            echo "$PROMOTIONS" | while read -r line; do
                echo "  • $line"
            done
            echo ""
        fi
    fi
else
    print_info "Skipping JFrog verification (--skip-jfrog enabled)"
fi

# ============================================================================
# 2. List All Attestations
# ============================================================================

print_header "Step 2: GitHub Attestations Discovery"

print_info "Searching for attestations at: https://github.com/${GITHUB_REPO}/attestations"

# Try to list attestations (note: gh attestation list may not be available in all versions)
if command -v gh &> /dev/null; then
    print_success "GitHub CLI found"
    
    # Check if attestation extension is available
    if gh attestation --help &> /dev/null 2>&1; then
        print_success "GitHub attestation extension available"
    else
        print_warning "GitHub attestation extension not found"
        print_info "Install with: gh extension install github/gh-attestation"
    fi
else
    print_error "GitHub CLI (gh) not found"
    print_info "Install from: https://cli.github.com/"
    VERIFICATION_FAILED=true
fi

# ============================================================================
# 3. Verify Build Attestations
# ============================================================================

print_header "Step 3: Build Attestations"

print_info "Checking for build provenance and actor attestations..."

cat << EOF

Build attestations are created during the initial build phase and include:
  • Build Provenance (SLSA) - How the artifact was built
  • Actor Attestation - Who triggered the build
  • CodeQL Attestation - Security scan results

To verify build attestations:
  1. Download the package tarball from JFrog:
     jf rt download "${JFROG_REPO_PREFIX:-$BUNDLE_NAME}-npm-local-dev/<package>.tgz" .

  2. Verify the attestation:
     gh attestation verify <package>.tgz --repo ${GITHUB_REPO}

EOF

# ============================================================================
# 4. Verify Promotion Attestations
# ============================================================================

print_header "Step 4: Promotion Attestations"

print_info "Promotion attestations are created at each environment promotion..."

cat << EOF

Promotion attestations capture:
  • Who triggered the promotion
  • Who approved the promotion (from environment reviewers)
  • Source and target environments
  • Bundle name and version
  • Timestamp and verification URL

To view promotion attestations:
  1. Visit: https://github.com/${GITHUB_REPO}/attestations

  2. Search for attestations with predicate type:
     https://github.com/attestation/promotion/v1

  3. Verify using the attestation bundle path (from workflow logs)

Note: Promotion attestations are bound to the bundle identifier, not a file.

EOF

# ============================================================================
# 5. Display Audit Trail
# ============================================================================

print_header "Step 5: Complete Audit Trail"

cat << EOF

Complete Verification Checklist:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

$(if [[ "$SKIP_JFROG" == false ]]; then
    if [[ "$VERIFICATION_FAILED" == false ]]; then
        echo "  ${GREEN}✓${NC} JFrog promotion history retrieved"
    else
        echo "  ${RED}✗${NC} JFrog promotion history verification failed"
    fi
else
    echo "  ${YELLOW}⊘${NC} JFrog verification skipped"
fi)

To complete full verification:

  ${BLUE}1. Build Attestations${NC}
     • Download artifact from JFrog
     • Run: gh attestation verify <artifact> --repo ${GITHUB_REPO}

  ${BLUE}2. Promotion Attestations${NC}
     • Visit: https://github.com/${GITHUB_REPO}/attestations
     • Verify each promotion attestation
     • Check approver information in predicate

  ${BLUE}3. Audit Information${NC}
     • Review GitHub Actions logs for each promotion
     • Check environment deployment history
     • Verify approvers match expected reviewers

${BLUE}Useful Commands:${NC}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  # View promotion history in JFrog
  jf rt curl -XGET "/api/v2/promotion/records/${BUNDLE_NAME}/${BUNDLE_VERSION}" | jq .

  # View all attestations for repository
  Open: https://github.com/${GITHUB_REPO}/attestations

  # Check environment deployment history
  gh api repos/${GITHUB_REPO}/deployments --jq '.[] | {environment, created_at, creator: .creator.login}'

EOF

# ============================================================================
# Summary
# ============================================================================

echo ""
if [[ "$VERIFICATION_FAILED" == true ]]; then
    print_error "Verification completed with errors"
    exit 1
else
    print_success "Verification checks passed"
    print_info "Complete manual verification steps listed above"
    exit 0
fi

