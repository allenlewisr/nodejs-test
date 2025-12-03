# Artifact Naming and Resolution Guide

## Overview

This project uses **standard npm package naming** for artifacts uploaded to JFrog Artifactory. Git commit information and build metadata are stored as **artifact properties** rather than in filenames, ensuring packages can be resolved normally through npm while maintaining full traceability.

## Naming Convention

### Package Artifacts

- **Format**: `{package-name}-{version}.tgz`
- **Example**: `nodejs-template-1.0.1.tgz`
- ✅ Standard npm naming - works with `npm install`
- ✅ Git SHA stored in properties for traceability

### Security Artifacts

- **SARIF**: `{build-name}-codeql-{build-number}.sarif`
  - Example: `nodejs-test-codeql-123.sarif`
- **SBOM**: `{build-name}-sbom-{build-number}.json`
  - Example: `nodejs-test-sbom-123.json`

## Artifact Properties

Each artifact is tagged with the following properties for traceability:

### Package Properties

```properties
# Git Information
git.commit.sha=4c44b85f5cf080f95b708ac37ae2d9f268432dca
git.commit.short=4c44b85f
git.branch=release/1.0.0

# Build Information
build.name=nodejs-test
build.number=123

# Attestation Information
attestation.github.url=https://github.com/org/repo/attestations
attestation.actor=username
attestation.trigger=push
attestation.commit=4c44b85f5cf080f95b708ac37ae2d9f268432dca
attestation.provenance.bundle=/attestations/...
attestation.sigstore.enabled=true

# Security Links
security.repo=nodejs-test-security-local
security.sarif.file=nodejs-test-codeql-123.sarif
security.sbom.file=nodejs-test-sbom-123.json
```

### Security Artifact Properties (SARIF/SBOM)

```properties
# Git Information
git.commit.sha=4c44b85f5cf080f95b708ac37ae2d9f268432dca
git.commit.short=4c44b85f
git.branch=release/1.0.0

# Build Information
build.name=nodejs-test
build.number=123

# Related Artifacts
related.artifact=nodejs-template-1.0.1.tgz
related.package.repo=nodejs-test-npm-local-dev
```

## Package Resolution Methods

### 1. Normal npm Install (Recommended)

After configuring JFrog as your npm registry:

```bash
# Configure npm to use JFrog
jf npm-config --repo-resolve=npm-remote --repo-deploy=nodejs-test-npm-local-dev

# Install by version (standard npm)
npm install nodejs-template@1.0.1

# Or add to package.json
{
  "dependencies": {
    "nodejs-template": "1.0.1"
  }
}
npm install
```

### 2. Direct Download from JFrog

```bash
# Download by exact path
jf rt download "nodejs-test-npm-local-dev/nodejs-template-1.0.1.tgz" .

# Install the downloaded tarball
npm install ./nodejs-template-1.0.1.tgz
```

### 3. Search by Build Information

Find artifacts by build number or name:

```bash
# Search by build number
jf rt search "nodejs-test-npm-local-dev/*.tgz" \
  --props="build.name=nodejs-test;build.number=123"

# Search by git commit SHA
jf rt search "nodejs-test-npm-local-dev/*.tgz" \
  --props="git.commit.sha=4c44b85f5cf080f95b708ac37ae2d9f268432dca"

# Search by short SHA
jf rt search "nodejs-test-npm-local-dev/*.tgz" \
  --props="git.commit.short=4c44b85f"

# Search by branch
jf rt search "nodejs-test-npm-local-dev/*.tgz" \
  --props="git.branch=release/1.0.0"
```

### 4. Query Using Build Info API

```bash
# Get build information
jf rt curl "/api/build/nodejs-test/123" | jq .

# Extract artifact details
jf rt curl "/api/build/nodejs-test/123" | \
  jq -r '.buildInfo.modules[].artifacts[] | "\(.name) - \(.sha256)"'
```

### 5. Get Artifact Properties

```bash
# View all properties for an artifact
jf rt curl "/api/storage/nodejs-test-npm-local-dev/nodejs-template-1.0.1.tgz" | \
  jq .properties
```

## Finding Related Security Artifacts

### From Package to SARIF/SBOM

```bash
# 1. Get package properties
PROPS=$(jf rt curl "/api/storage/nodejs-test-npm-local-dev/nodejs-template-1.0.1.tgz")

# 2. Extract security artifact paths
SARIF_PATH=$(echo "$PROPS" | jq -r '.properties["security.sarif.path"][0]')
SBOM_PATH=$(echo "$PROPS" | jq -r '.properties["security.sbom.path"][0]')

# 3. Download security artifacts
jf rt download "$SARIF_PATH" .
jf rt download "$SBOM_PATH" .
```

### From SARIF/SBOM to Package

```bash
# Find package related to a security artifact
jf rt curl "/api/storage/nodejs-test-security-local/nodejs-test-codeql-123.sarif" | \
  jq -r '.properties["related.artifact"][0]'
```

## Verification and Attestation

### Verify Package Attestation

```bash
# Download package
jf rt download "nodejs-test-npm-local-dev/nodejs-template-1.0.1.tgz" .

# Verify attestation with GitHub CLI
gh attestation verify nodejs-template-1.0.1.tgz \
  --repo your-org/nodejs-test
```

### View Attestations

Visit: `https://github.com/your-org/nodejs-test/attestations`

## Querying Across Environments

### Find Latest Package in Each Environment

```bash
# DEV
jf rt search "nodejs-test-npm-local-dev/nodejs-template-*.tgz" \
  --sort-by=created --sort-order=desc --limit=1

# QA
jf rt search "nodejs-test-npm-local-qa/nodejs-template-*.tgz" \
  --sort-by=created --sort-order=desc --limit=1

# UAT
jf rt search "nodejs-test-npm-local-uat/nodejs-template-*.tgz" \
  --sort-by=created --sort-order=desc --limit=1

# PROD
jf rt search "nodejs-test-npm-local-prod/nodejs-template-*.tgz" \
  --sort-by=created --sort-order=desc --limit=1
```

### Trace Promotion Path

```bash
# Find which environments have a specific version
for env in dev qa uat prod; do
  echo "=== $env ==="
  jf rt search "nodejs-test-npm-local-$env/nodejs-template-1.0.1.tgz" \
    --props="git.commit.short=4c44b85f" 2>/dev/null || echo "Not found"
done
```

## Advanced Queries

### Find All Artifacts from a Specific Commit

```bash
# Find all artifacts (package, SARIF, SBOM) from a commit
git_sha="4c44b85f5cf080f95b708ac37ae2d9f268432dca"

echo "Package artifacts:"
jf rt search "nodejs-test-npm-local-*/*.tgz" \
  --props="git.commit.sha=${git_sha}"

echo -e "\nSecurity artifacts:"
jf rt search "nodejs-test-security-local/*" \
  --props="git.commit.sha=${git_sha}"
```

### Find All Artifacts from a Build

```bash
build_number="123"

# Using build info (most reliable)
jf rt curl "/api/build/nodejs-test/${build_number}" | \
  jq -r '.buildInfo.modules[].artifacts[].name'

# Or using properties search
jf rt search "*/*" --props="build.number=${build_number}"
```

### Find Packages Missing Security Artifacts

```bash
# Find packages without SARIF
jf rt search "nodejs-test-npm-local-dev/*.tgz" | \
  jq -r '.[] | select(.props["security.sarif.file"] == null) | .path'
```

## Best Practices

### For Developers

1. **Install packages normally** using npm with JFrog configured
2. **Use version numbers** from `package.json`, not SHAs
3. **Check attestations** before using packages in production

### For DevOps/Security

1. **Search by properties** to find artifacts by commit or build
2. **Always verify attestations** in promotion workflows
3. **Use build info API** for reliable artifact queries
4. **Check security artifacts** (SARIF/SBOM) are linked

### For Auditors

1. **Use git SHA** to find all artifacts from a specific commit
2. **Verify promotion chain** using attestations
3. **Check properties** for complete traceability
4. **Download security artifacts** for compliance reviews

## Migrating from SHA-Named Artifacts

If you have existing artifacts with SHA names (e.g., `package-1.0.0-abc123.tgz`):

### Option 1: Manual Installation

```bash
jf rt download "repo/package-1.0.0-abc123.tgz" .
npm install ./package-1.0.0-abc123.tgz
```

### Option 2: Copy During Promotion

Add to promotion workflow:

```bash
# Copy with standard name in new environment
jf rt copy \
  "nodejs-test-npm-local-dev/package-1.0.0-abc123.tgz" \
  "nodejs-test-npm-local-qa/package-1.0.0.tgz" \
  --props="copied.from.sha.version=true"
```

### Option 3: Re-release

- Increment version (1.0.0 → 1.0.1)
- Re-publish with standard naming
- Mark old version as deprecated

## Troubleshooting

### Package Not Found by npm

```bash
# Check repository configuration
jf npm-config --repo-resolve=npm-remote

# Search for the package manually
jf rt search "nodejs-test-npm-local-*/nodejs-template-*.tgz"

# Verify package exists with correct name
jf rt curl "/api/storage/nodejs-test-npm-local-dev/nodejs-template-1.0.1.tgz"
```

### Cannot Find Package by SHA

```bash
# Search by short SHA (more lenient)
jf rt search "*/*.tgz" --props="git.commit.short=4c44b85f"

# Or full SHA
jf rt search "*/*.tgz" --props="git.commit.sha=4c44b85f5cf080f95b708ac37ae2d9f268432dca"
```

### Missing Security Artifacts

```bash
# Check if security repo exists
jf rt curl "/api/repositories/nodejs-test-security-local"

# Check package properties for links
jf rt curl "/api/storage/nodejs-test-npm-local-dev/nodejs-template-1.0.1.tgz" | \
  jq '.properties | with_entries(select(.key | startswith("security")))'
```

## Related Documentation

- [Attestation Verification Guide](ATTESTATION_VERIFICATION.md)
- [Promotion Guide](PROMOTION_ATTESTATION_GUIDE.md)
- [Environment Setup](ENVIRONMENT_SETUP_INSTRUCTIONS.md)
- [Bidirectional Artifact Linking](BIDIRECTIONAL_ARTIFACT_LINKING.md)
