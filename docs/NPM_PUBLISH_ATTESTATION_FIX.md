# NPM Publish Attestation Fix

## Problem Summary

Attestation verification was failing with 404 errors when using `jf npm publish` instead of `jf rt upload`.

## Root Cause

The issue was caused by **incorrect artifact path resolution** in npm repositories:

### Different Path Structures

**When using `jf rt upload`:**

```
repo-name/package-name-1.0.0.tgz
```

**When using `jf npm publish`:**

```
repo-name/package-name/-/package-name-1.0.0.tgz
```

### What Was Happening

1. ✅ Package published successfully to JFrog with `jf npm publish`
2. ✅ Attestations created successfully in GitHub
3. ❌ Workflow tried to set properties on wrong path: `nodejs-test-npm-local-dev/nodejs-template-1.0.1.tgz`
4. ❌ Actual artifact location: `nodejs-test-npm-local-dev/nodejs-template/-/nodejs-template-1.0.1.tgz`
5. ❌ Properties never set → metadata not linked
6. ❌ Verification failed with 404 (attestation exists but can't be matched to artifact)

## The Fix

### 1. Workflow Changes

Updated `.github/workflows/unified-build.yml` to calculate and use the correct npm artifact path:

```yaml
- name: Generate package tarball path
  run: |
    PACKAGE_NAME=$(node -p "require('./package.json').name")
    PACKAGE_VERSION=$(node -p "require('./package.json').version")
    SHORT_SHA="${GITHUB_SHA:0:8}"
    TARBALL_NAME="${PACKAGE_NAME}-${PACKAGE_VERSION}.tgz"
    # npm publish creates path: repo-name/package-name/-/tarball.tgz
    NPM_ARTIFACT_PATH="${PACKAGE_NAME}/-/${TARBALL_NAME}"
    echo "PACKAGE_NAME=${PACKAGE_NAME}" >> $GITHUB_ENV
    echo "TARBALL_PATH=${TARBALL_NAME}" >> $GITHUB_ENV
    echo "NPM_ARTIFACT_PATH=${NPM_ARTIFACT_PATH}" >> $GITHUB_ENV
    echo "SHORT_SHA=${SHORT_SHA}" >> $GITHUB_ENV
```

### 2. Property Setting Updates

Changed all property-setting steps to use `NPM_ARTIFACT_PATH`:

**Before:**

```yaml
ARTIFACT_PATH="${{ env.JFROG_REPO_NAME }}/${{ env.TARBALL_PATH }}"
```

**After:**

```yaml
ARTIFACT_PATH="${{ env.JFROG_REPO_NAME }}/${{ env.NPM_ARTIFACT_PATH }}"
```

This affects:

- Main attestation metadata (line ~203)
- SARIF security artifact linking (line ~278)
- SBOM security artifact linking (line ~346)

### 3. Verification Script Updates

Updated `scripts/verify-attestation.sh` to:

- Extract package name from tarball filename
- Construct correct npm artifact path
- Download from correct location
- Query properties from correct path

### 4. Documentation Updates

Updated all documentation to reflect npm path structure:

- `docs/ATTESTATION_VERIFICATION_TROUBLESHOOTING.md`
- Download examples
- Property query examples

## Verification Steps

After the workflow runs with these fixes:

### 1. Check Properties Were Set

```bash
jf rt curl -XGET "/api/storage/nodejs-test-npm-local-dev/nodejs-template/-/nodejs-template-1.0.1.tgz?properties"
```

Should show properties like:

- `git.commit.sha`
- `attestation.provenance.bundle`
- `attestation.actor.bundle`
- `security.sarif.file`
- `security.sbom.file`

### 2. Download and Verify

```bash
# Download from correct npm path
jf rt download "nodejs-test-npm-local-dev/nodejs-template/-/nodejs-template-1.0.1.tgz" --flat

# Verify attestation
gh attestation verify nodejs-template-1.0.1.tgz --owner allenlewisr
```

### 3. Use Verification Script

```bash
./scripts/verify-attestation.sh nodejs-template-1.0.1.tgz nodejs-test-npm-local-dev allenlewisr
```

## Why This Matters

### NPM Repository Structure

NPM repositories in JFrog follow the npm registry specification:

```
repository/
  └── package-name/
      ├── -/
      │   ├── package-name-1.0.0.tgz
      │   ├── package-name-1.0.1.tgz
      │   └── package-name-2.0.0.tgz
      └── package.json (metadata)
```

The `/-/` directory contains all tarball versions.

### Why `jf rt upload` Worked Before

`jf rt upload` is a generic file upload that:

- Places files exactly where you specify
- Doesn't follow npm conventions
- Simple flat structure

`jf npm publish` is npm-aware and:

- Follows npm registry structure
- Creates proper package metadata
- Supports npm-specific operations (unpublish, deprecate, etc.)
- **Recommended for npm packages**

## Benefits of Using `jf npm publish`

1. **Proper npm registry structure** - compatible with npm clients
2. **Package metadata management** - maintains package.json in repo
3. **Version management** - easier to list/manage versions
4. **npm-specific features** - deprecation, tags, etc.
5. **Better integration** - works with JFrog npm APIs

## Summary of Changes

| File                                               | Change                                |
| -------------------------------------------------- | ------------------------------------- |
| `.github/workflows/unified-build.yml`              | Added `NPM_ARTIFACT_PATH` calculation |
| `.github/workflows/unified-build.yml`              | Updated 3 property-setting steps      |
| `scripts/verify-attestation.sh`                    | Added npm path resolution             |
| `docs/ATTESTATION_VERIFICATION_TROUBLESHOOTING.md` | Updated all examples                  |
| `docs/NPM_PUBLISH_ATTESTATION_FIX.md`              | Created (this document)               |

## Testing Checklist

After running the workflow:

- [ ] Build completes successfully
- [ ] Package published to correct npm path
- [ ] Attestations created in GitHub
- [ ] Properties set on artifact in JFrog
- [ ] SARIF linked to package
- [ ] SBOM linked to package
- [ ] Can download package from JFrog
- [ ] Attestation verification passes
- [ ] Metadata visible in JFrog properties

## Related Documentation

- `docs/ATTESTATION_VERIFICATION_TROUBLESHOOTING.md` - Troubleshooting guide
- `docs/ATTESTATION_WITH_NPM.md` - Publishing to public npm
- `ATTESTATION_VERIFICATION.md` - Complete verification guide
- `scripts/verify-attestation.sh` - Automated verification script
