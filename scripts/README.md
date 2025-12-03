# Attestation and Promotion Verification Scripts

This directory contains two shell scripts for verifying attestations and displaying release bundle promotion history.

## Scripts

### 1. verify-artifact-attestation.sh

Verifies artifact attestations and displays actor information.

**Usage:**

```bash
./verify-artifact-attestation.sh <artifact_path> <jfrog_repo_name>
```

**Parameters:**

- `artifact_path` - Full artifact path (e.g., `nodejs-template/-/nodejs-template-1.0.1.tgz`)
- `jfrog_repo_name` - JFrog repository name (e.g., `nodejs-test-npm-local-dev`)

**Example:**

```bash
./scripts/verify-artifact-attestation.sh \
  "nodejs-template/-/nodejs-template-1.0.1.tgz" \
  "nodejs-test-npm-local-dev"
```

**What it does:**

1. Downloads the artifact from JFrog
2. Verifies the attestation using GitHub
3. Extracts and displays actor information:
   - Actor (who triggered the build)
   - Actor ID
   - Triggered by (push, workflow_dispatch, etc.)
   - Repository
   - Commit SHA
   - Workflow name
   - Run ID
   - Timestamp

**Output Example:**

```
=== Artifact Attestation - Actor Information ===
Actor:           allenlewis32
Actor ID:        12345
Triggered By:    push
Repository:      allenlewisr/nodejs-test
Commit:          abc123...
Workflow:        Build and Release
Run ID:          19861723295
Timestamp:       2025-12-02T19:47:01+05:30
```

---

### 2. show-bundle-promotions.sh

Displays release bundle promotion history with approval details.

**Usage:**

```bash
./show-bundle-promotions.sh <bundle_name> [bundle_version]
```

**Parameters:**

- `bundle_name` - Release bundle name (required)
- `bundle_version` - Bundle version (optional, defaults to latest)

**Examples:**

```bash
# Use specific version
./scripts/show-bundle-promotions.sh "nodejs-test" "1.0.1+build.1"

# Use latest version (auto-detected)
./scripts/show-bundle-promotions.sh "nodejs-test"
```

**What it does:**

1. Retrieves the bundle version (uses latest if not specified)
2. Fetches promotion records from JFrog
3. Displays promotion history in a formatted table:
   - Environment (DEV, QA, UAT, PROD)
   - Status (COMPLETED, IN_PROGRESS, etc.)
   - Created by (who triggered the promotion)
   - Timestamp
4. Shows the complete promotion path

**Output Example:**

```
=== Release Bundle Promotion History ===
Bundle: nodejs-test
Version: 1.0.1+build.1

Environment     Status          Created By           Timestamp
───────────────────────────────────────────────────────────────────────────
DEV             COMPLETED       allenlewis32         2025-12-02 14:30:00
QA              COMPLETED       allenlewis32         2025-12-02 15:45:00
UAT             COMPLETED       allenlewis32         2025-12-02 16:20:00

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Promotion Path: DEV → QA → UAT
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

## Prerequisites

Both scripts require the following tools to be installed:

- **JFrog CLI** (`jf`) - For interacting with JFrog Artifactory
- **GitHub CLI** (`gh`) - For attestation verification
- **jq** - For JSON parsing
- **base64** - For decoding attestation data

### Installation

```bash
# JFrog CLI
brew install jfrog-cli

# GitHub CLI
brew install gh

# jq
brew install jq

# base64 is typically pre-installed on macOS/Linux
```

### Authentication

Ensure you're authenticated with both JFrog and GitHub:

```bash
# Configure JFrog CLI
jf config add

# Login to GitHub CLI
gh auth login
```

---

## Notes

- **Script 1** cleans up the downloaded artifact after verification (even on error exits)
- **Script 2** automatically detects the latest bundle version if not specified
- Both scripts include colorized output for better readability
- Error messages are clearly marked and provide helpful guidance
- Both scripts use `trap` to ensure temporary resources are cleaned up on any exit (success or failure)

---

## Troubleshooting

### Attestation Verification Fails

- Ensure the artifact has been attested (check GitHub attestations page)
- Verify you're using the correct GitHub owner (`allenlewisr`)
- Check that the artifact path follows npm structure with `/-/` separator

### Bundle Not Found

- Verify the bundle name matches exactly (case-sensitive)
- Check that the bundle version exists in JFrog
- Ensure JFrog CLI is properly configured with correct permissions

### Missing Dependencies

- Run the prerequisite installation commands above
- Verify tools are in your PATH: `which jf gh jq`

---

## Related Documentation

- [START_HERE.md](../docs/START_HERE.md) - Overview of attestation system
- [QUICK_VERIFICATION_GUIDE.md](../docs/QUICK_VERIFICATION_GUIDE.md) - Quick verification steps
- [VERIFY_PROMOTION_ATTESTATION.md](../docs/VERIFY_PROMOTION_ATTESTATION.md) - Promotion attestation details
