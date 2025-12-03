# Attesting the Published Package

## The Better Approach

Instead of attesting a locally created package and then publishing it, we now:

1. **Create** the package tarball with `npm pack`
2. **Publish** to JFrog Artifactory
3. **Download** the published package from JFrog
4. **Attest** the downloaded package

## Why This Works Better

### Problem with Previous Approach

**Old Flow:**
```
npm pack → attest local file → publish to JFrog
```

**Issues:**
- Local tarball might have different hash than published one
- Attestation created before package is in repository
- Hash mismatch causes verification failures
- Attestation tied to local file, not repository file

### Solution: Attest Published Package

**New Flow:**
```
npm pack → publish to JFrog → download from JFrog → attest downloaded file
```

**Benefits:**
- ✅ Attests the **exact file** stored in JFrog
- ✅ Hash guaranteed to match
- ✅ Attestation created after successful publish
- ✅ Verification always works (same source of truth)
- ✅ No local backup/restore needed

## Implementation

### In the Workflow

```yaml
- name: Publish to JFrog Artifactory
  run: |
    jf npm publish --build-name=${{ env.BUILD_NAME }} --build-number=${{ github.run_number }}

- name: Download published package for attestation
  run: |
    # Download the actual published package from JFrog
    JFROG_ARTIFACT_PATH="${{ env.JFROG_REPO_NAME }}/${{ env.NPM_ARTIFACT_PATH }}"
    echo "Downloading published package from: ${JFROG_ARTIFACT_PATH}"
    
    jf rt download "${JFROG_ARTIFACT_PATH}" --flat
    
    if [ ! -f "${{ env.TARBALL_PATH }}" ]; then
      echo "❌ Failed to download published package"
      exit 1
    fi
    
    echo "✓ Published package downloaded for attestation"
    
    # Display digest for verification
    DIGEST=$(sha256sum ${{ env.TARBALL_PATH }} | awk '{print $1}')
    echo "Package SHA256: ${DIGEST}"

- name: Attest package with GitHub
  id: attest
  uses: actions/attest-build-provenance@v3
  with:
    subject-path: '${{ env.TARBALL_PATH }}'
```

### Key Points

1. **npm publish removes local file** - This is normal npm behavior
2. **Download from JFrog** - Gets the exact published bytes
3. **Attest downloaded file** - Guarantees hash match
4. **Properties set correctly** - Uses npm path structure

## Verification Flow

When users verify:

```bash
# User downloads from JFrog
jf rt download "repo/package/-/package-1.0.0.tgz" --flat

# User verifies
gh attestation verify package-1.0.0.tgz --owner org
```

**What happens:**
1. `gh` calculates SHA256 of downloaded file
2. Looks up attestation by that digest
3. ✅ **Finds attestation** (same digest as attested file)
4. Verifies signature with Sigstore
5. ✅ **Success!**

## Why Previous Approaches Failed

### Approach 1: Attest Before Publishing
```yaml
npm pack → attest → publish
```
❌ Local file hash ≠ Published file hash (sometimes)

### Approach 2: Backup and Restore
```yaml
npm pack → backup → publish → restore → attest
```
❌ Still attesting local copy, not published file

### Approach 3: Attest Published Package ✅
```yaml
npm pack → publish → download → attest
```
✅ Attesting the exact published file

## Additional Benefits

### 1. Verifiable Supply Chain

The attestation now proves:
- Package was built in GitHub Actions
- Exact file in JFrog was attested
- No post-publish tampering

### 2. Simpler Workflow

No need for:
- Backup copies
- Restore steps
- Local file management

### 3. Future-Proof

Works with:
- Any repository type (npm, generic, etc.)
- Any package manager
- Any verification tool

## Complete Example

```yaml
# Create package
- name: Create package tarball
  run: |
    jf npm pack
    ls -lh ${{ env.TARBALL_PATH }}

# Publish to JFrog
- name: Publish to JFrog Artifactory
  run: |
    jf npm publish --build-name=$BUILD_NAME --build-number=$BUILD_NUMBER

# Download published package
- name: Download published package for attestation
  run: |
    ARTIFACT_PATH="${REPO}/${PACKAGE}/-/${TARBALL}"
    jf rt download "${ARTIFACT_PATH}" --flat
    sha256sum $TARBALL

# Attest the published package
- name: Attest package
  uses: actions/attest-build-provenance@v3
  with:
    subject-path: '${{ env.TARBALL_PATH }}'

# Set properties linking attestation
- name: Link attestation in JFrog
  run: |
    ARTIFACT_PATH="${REPO}/${NPM_ARTIFACT_PATH}"
    jf rt set-props "${ARTIFACT_PATH}" \
      "attestation.bundle=${{ steps.attest.outputs.bundle-path }}"
```

## Verification Command

```bash
# Download from JFrog
jf rt download "nodejs-test-npm-local-dev/nodejs-template/-/nodejs-template-1.0.1.tgz" --flat

# Verify attestation
gh attestation verify nodejs-template-1.0.1.tgz --owner allenlewisr

# Expected output:
# Loaded digest sha256:abc123... for file://nodejs-template-1.0.1.tgz
# ✓ Verification succeeded!
```

## Summary

**This approach ensures that:**
1. Attestation is for the exact file in JFrog
2. Hash always matches between JFrog and attestation
3. Verification succeeds reliably
4. Supply chain is verifiable end-to-end

The key insight: **Attest what users will actually download and use!**

