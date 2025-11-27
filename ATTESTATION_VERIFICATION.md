# Attestation Verification Guide

This guide explains how to verify the GitHub attestations for your build artifacts and CodeQL security scan results.

## Overview

Your workflow creates three types of attestations:

1. **Build Provenance** - Verifiable proof of how the package was built
2. **Actor Information** - Who triggered the build and when
3. **CodeQL Security Scan** - Security analysis results with attestation

All attestations are signed using Sigstore and can be independently verified.

## Prerequisites

Install the GitHub CLI with attestation support:

```bash
# Install GitHub CLI (if not already installed)
brew install gh  # macOS
# or
sudo apt install gh  # Linux

# Authenticate with GitHub
gh auth login

# Install attestation extension
gh extension install github/gh-attestation
```

## Verification Methods

### Method 1: Verify Package from JFrog

After downloading the package from JFrog:

```bash
# Download the package from JFrog
jf rt download "<JFROG_REPO_NAME>/<package-name>-<version>.tgz" .

# Verify the build provenance attestation
gh attestation verify <package-name>-<version>.tgz \
  --owner <your-github-org>

# Verify with specific repository
gh attestation verify <package-name>-<version>.tgz \
  --repo <your-github-org>/<repo-name>
```

### Method 2: Verify CodeQL SARIF Results from JFrog

```bash
# Download the SARIF file from JFrog
jf rt download "<JFROG_REPO_NAME>/security-reports/<build-name>-codeql-<run-number>.sarif" .

# Verify the CodeQL attestation
gh attestation verify <build-name>-codeql-<run-number>.sarif \
  --owner <your-github-org>
```

### Method 3: Verify Using GitHub Web UI

1. Navigate to your repository on GitHub
2. Go to: `https://github.com/<org>/<repo>/attestations`
3. You'll see a list of all attestations created for your artifacts
4. Click on any attestation to view:
   - The attested artifact's SHA256 digest
   - The predicate (metadata about the build/scan)
   - The signature and verification status
   - The Sigstore transparency log entry

### Method 4: Verify Using Bundle Path

Each attestation generates a bundle file. You can find the bundle path in the workflow logs or JFrog properties:

```bash
# View artifact properties in JFrog (including attestation bundle paths)
jf rt curl -XGET "/api/storage/<JFROG_REPO_NAME>/<artifact-path>"

# Example output shows properties like:
# - attestation.provenance.bundle
# - attestation.actor.bundle
# - attestation.codeql.bundle
```

## Detailed Verification Examples

### Example 1: Full Package Verification

```bash
# Set variables
PACKAGE_FILE="nodejs-template-1.0.0.tgz"
GITHUB_ORG="your-org"
GITHUB_REPO="your-repo"

# Verify the package
gh attestation verify "$PACKAGE_FILE" \
  --repo "$GITHUB_ORG/$GITHUB_REPO"

# Expected output:
# ✓ Verification succeeded!
#
# attestation verified for nodejs-template-1.0.0.tgz
# Repository: your-org/your-repo
# Workflow: Build
# Predicate type: https://slsa.dev/provenance/v1
```

### Example 2: Verify CodeQL Results

```bash
# Set variables
SARIF_FILE="nodejs-template-codeql-123.sarif"
GITHUB_ORG="your-org"

# Verify the SARIF file
gh attestation verify "$SARIF_FILE" \
  --owner "$GITHUB_ORG"

# Expected output:
# ✓ Verification succeeded!
#
# attestation verified for nodejs-template-codeql-123.sarif
# Predicate type: https://github.com/attestation/codeql/v1
```

### Example 3: Inspect Attestation Details

```bash
# Get detailed information about an attestation
gh attestation verify "$PACKAGE_FILE" \
  --repo "$GITHUB_ORG/$GITHUB_REPO" \
  --format json | jq .

# This shows:
# - Subject (the artifact)
# - Predicate (build metadata)
# - Signature verification status
# - Sigstore bundle information
```

## Verifying JFrog Metadata

You can also verify that the attestation metadata is correctly attached to artifacts in JFrog:

```bash
# View package metadata
jf rt curl -XGET "/api/storage/<JFROG_REPO_NAME>/<package-name>-<version>.tgz" | jq .

# Look for these properties:
# - attestation.github.url
# - attestation.actor
# - attestation.commit
# - attestation.provenance.bundle
# - attestation.actor.bundle
# - attestation.sigstore.enabled

# View SARIF metadata
jf rt curl -XGET "/api/storage/<JFROG_REPO_NAME>/security-reports/<sarif-name>" | jq .

# Look for these properties:
# - scan.type=codeql
# - scan.language=javascript
# - attestation.codeql.bundle
# - related.artifact
```

## Understanding the Attestations

### 1. Build Provenance Attestation

- **Standard**: SLSA Provenance v1.0
- **Purpose**: Proves the package was built in your GitHub Actions workflow
- **Contains**: Builder identity, build parameters, materials (source code)
- **Signature**: Signed with GitHub's Sigstore keyless signing

### 2. Actor Attestation

- **Custom Predicate**: `https://github.com/attestation/actor/v1`
- **Purpose**: Records who triggered the build
- **Contains**: Actor name, actor ID, trigger event, repository info, commit SHA

### 3. CodeQL Attestation

- **Custom Predicate**: `https://github.com/attestation/codeql/v1`
- **Purpose**: Proves security scan was performed
- **Contains**: Scan type, language, queries used, commit SHA, results file reference

## Security Best Practices

1. **Always verify attestations** before using artifacts from JFrog
2. **Check the actor** to ensure builds were triggered by authorized users
3. **Review CodeQL results** before deploying
4. **Store verification logs** for compliance purposes
5. **Automate verification** in your deployment pipelines

## Automated Verification in CI/CD

Add verification to your deployment pipeline:

```yaml
- name: Download and verify artifact from JFrog
  run: |
    # Download from JFrog
    jf rt download "$JFROG_REPO_NAME/$ARTIFACT_PATH" .

    # Verify attestation
    gh attestation verify "$ARTIFACT_FILE" \
      --repo ${{ github.repository }} || exit 1

    # Only deploy if verification succeeds
    echo "✓ Attestation verified - proceeding with deployment"
```

## Troubleshooting

### "No attestations found"

- Ensure the workflow has run successfully
- Check that `permissions.attestations: write` is set
- Verify you're using the correct repository/owner

### "Verification failed"

- The artifact may have been tampered with
- The artifact might not have an attestation
- You may be using the wrong repository

### "Bundle not found"

- Wait a few minutes after the workflow completes
- Check GitHub's transparency log for the attestation

## Additional Resources

- [GitHub Attestations Documentation](https://docs.github.com/en/actions/security-guides/using-artifact-attestations)
- [SLSA Provenance Specification](https://slsa.dev/provenance/)
- [Sigstore Documentation](https://docs.sigstore.dev/)
- [CodeQL Documentation](https://codeql.github.com/docs/)

## Example: Complete Verification Script

```bash
#!/bin/bash
set -e

JFROG_REPO="your-repo-npm-local-dev"
PACKAGE_NAME="nodejs-template"
PACKAGE_VERSION="1.0.0"
BUILD_NUMBER="123"
GITHUB_REPO="your-org/nodejs-test"

echo "=== Downloading artifacts from JFrog ==="
jf rt download "$JFROG_REPO/$PACKAGE_NAME-$PACKAGE_VERSION.tgz" .
jf rt download "$JFROG_REPO/security-reports/$PACKAGE_NAME-codeql-$BUILD_NUMBER.sarif" .

echo "=== Verifying package attestation ==="
gh attestation verify "$PACKAGE_NAME-$PACKAGE_VERSION.tgz" \
  --repo "$GITHUB_REPO"

echo "=== Verifying CodeQL attestation ==="
gh attestation verify "$PACKAGE_NAME-codeql-$BUILD_NUMBER.sarif" \
  --repo "$GITHUB_REPO"

echo "=== Checking JFrog metadata ==="
jf rt curl -XGET "/api/storage/$JFROG_REPO/$PACKAGE_NAME-$PACKAGE_VERSION.tgz" | \
  jq -r '.properties | to_entries[] | "\(.key): \(.value[0])"'

echo ""
echo "✅ All verifications passed!"
```

Save this as `verify-attestations.sh` and run it to verify all attestations in one go.
