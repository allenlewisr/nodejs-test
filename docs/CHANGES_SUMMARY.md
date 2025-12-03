# Summary of Changes - NPM Publish Attestation Fix

## Problem Identified

Attestation verification was failing with **404 errors** because:

1. Attesting **local file** instead of **published file** from JFrog
2. Hash mismatch between local tarball and published tarball
3. `jf npm publish` stores packages at: `repo/package-name/-/tarball.tgz`
4. Workflow was setting properties at wrong path: `repo/tarball.tgz`
5. Properties never applied → attestation couldn't be linked to artifact
6. Verification failed: attestation digest doesn't match published file

## Root Cause

**NPM repositories use a different path structure** than generic repositories:

| Method           | Path Structure                     |
| ---------------- | ---------------------------------- |
| `jf rt upload`   | `repo/package-1.0.0.tgz`           |
| `jf npm publish` | `repo/package/-/package-1.0.0.tgz` |

The `/-/` directory is part of the npm registry specification.

## Files Modified

### 1. `.github/workflows/unified-build.yml`

**Lines 125-138:** Added npm artifact path calculation

```yaml
NPM_ARTIFACT_PATH="${PACKAGE_NAME}/-/${TARBALL_NAME}"
```

**Lines 158-180:** **KEY FIX** - Download and attest the published package

```yaml
# Old approach: backup → publish → restore → attest local file
# New approach: publish → download from JFrog → attest published file

- name: Publish to JFrog Artifactory
  run: jf npm publish

- name: Download published package for attestation
  run: |
    jf rt download "${JFROG_REPO_NAME}/${NPM_ARTIFACT_PATH}" --flat
    sha256sum ${{ env.TARBALL_PATH }}

- name: Attest package with GitHub
  uses: actions/attest-build-provenance@v3
  with:
    subject-path: '${{ env.TARBALL_PATH }}'
```

**Line ~203:** Updated main attestation metadata path

```yaml
ARTIFACT_PATH="${{ env.JFROG_REPO_NAME }}/${{ env.NPM_ARTIFACT_PATH }}"
```

**Line ~278:** Updated SARIF linking path

```yaml
ARTIFACT_PATH="${{ env.JFROG_REPO_NAME }}/${{ env.NPM_ARTIFACT_PATH }}"
```

**Line ~346:** Updated SBOM linking path

```yaml
ARTIFACT_PATH="${{ env.JFROG_REPO_NAME }}/${{ env.NPM_ARTIFACT_PATH }}"
```

### 2. `scripts/verify-attestation.sh`

- Added npm path calculation from tarball filename
- Updated download path to use npm structure
- Updated property query path

### 3. Documentation Created/Updated

- ✅ `docs/ATTEST_PUBLISHED_PACKAGE.md` - **NEW** - Why we attest the published package
- ✅ `docs/NPM_PUBLISH_ATTESTATION_FIX.md` - Complete technical explanation
- ✅ `docs/ATTESTATION_VERIFICATION_TROUBLESHOOTING.md` - Updated all examples
- ✅ `QUICK_VERIFICATION_GUIDE.md` - Quick reference for verification
- ✅ `CHANGES_SUMMARY.md` - This file

## How to Test

### 1. Run the Workflow

Trigger the workflow on your `release/1.0.0` branch:

```bash
git push origin release/1.0.0
```

### 2. After Workflow Completes

Check that properties were set:

```bash
jf rt curl -XGET "/api/storage/nodejs-test-npm-local-dev/nodejs-template/-/nodejs-template-1.0.1.tgz?properties"
```

### 3. Download and Verify

```bash
# Download from JFrog (note the /-/ in path!)
jf rt download "nodejs-test-npm-local-dev/nodejs-template/-/nodejs-template-1.0.1.tgz" --flat

# Verify attestation
gh attestation verify nodejs-template-1.0.1.tgz --owner allenlewisr
```

### 4. Or Use the Script

```bash
./scripts/verify-attestation.sh nodejs-template-1.0.1.tgz nodejs-test-npm-local-dev allenlewisr
```

## Expected Outcome

✅ **Before:** 404 error - no attestations found  
✅ **After:** Attestation verified successfully

```
Loaded digest sha256:... for file://nodejs-template-1.0.1.tgz
✓ Verification succeeded!

Attestation verified for: nodejs-template-1.0.1.tgz
  Repository: allenlewisr/nodejs-test
  Workflow: Build and Release
  Run ID: ...
```

## Key Takeaways

1. **Use `jf npm publish` for npm packages** - it's the recommended approach
2. **NPM path structure includes `/-/`** - this is standard npm registry format
3. **Properties must be set on correct path** - or they won't be found
4. **Attestations work correctly** - once properties are on the right path
5. **Verification requires local file** - when package is in private JFrog

## Additional Benefits

Using `jf npm publish` provides:

- ✅ Proper npm registry structure
- ✅ Package metadata management
- ✅ Version management
- ✅ NPM-specific features (deprecate, tags, etc.)
- ✅ Better npm client compatibility

## Next Steps

1. **Commit and push changes** to trigger workflow
2. **Verify the fix** using steps above
3. **Update version** when ready for next release
4. **Check documentation** if issues arise

## Need Help?

- **Quick Start:** `QUICK_VERIFICATION_GUIDE.md`
- **Why Attest Published Package:** `docs/ATTEST_PUBLISHED_PACKAGE.md` ⭐
- **Technical Details:** `docs/NPM_PUBLISH_ATTESTATION_FIX.md`
- **Troubleshooting:** `docs/ATTESTATION_VERIFICATION_TROUBLESHOOTING.md`
- **Public NPM:** `docs/ATTESTATION_WITH_NPM.md`

## The Solution: Attest the Published Package

### Why This Works

**Problem:** Attesting a local file before/after publishing can cause hash mismatches.

**Solution:** Attest the exact file downloaded from JFrog after publishing.

```
Old: npm pack → attest local → publish (hash might differ)
New: npm pack → publish → download → attest (hash guaranteed to match)
```

### Benefits

1. ✅ **Guaranteed hash match** - Attesting the exact bytes in JFrog
2. ✅ **No backup/restore** - Simpler workflow
3. ✅ **Verifiable** - Users download same file we attested
4. ✅ **Supply chain proof** - Proves exact file in repo was built by us

## Workflow Actions

The workflow now:

1. ✅ Creates tarball with `npm pack`
2. ✅ Publishes to JFrog with `jf npm publish`
3. ✅ **Downloads published package from JFrog** ← KEY FIX #1
4. ✅ **Attests the downloaded package** ← KEY FIX #2
5. ✅ **Sets properties at correct npm path** ← KEY FIX #3
6. ✅ Links SARIF and SBOM bidirectionally
7. ✅ Publishes build info

All attestations are now for the exact file in JFrog with matching hashes!
