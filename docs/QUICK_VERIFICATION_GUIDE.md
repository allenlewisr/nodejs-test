# Quick Verification Guide

## After Workflow Runs Successfully

### Step 1: Check the Artifact Path in JFrog

Your package will be at:
```
nodejs-test-npm-local-dev/nodejs-template/-/nodejs-template-1.0.1.tgz
```

**NOT at:** `nodejs-test-npm-local-dev/nodejs-template-1.0.1.tgz` ⚠️

### Step 2: Verify Properties Were Set

```bash
jf rt curl -XGET "/api/storage/nodejs-test-npm-local-dev/nodejs-template/-/nodejs-template-1.0.1.tgz?properties" | jq .
```

You should see properties like:
- `git.commit.sha`
- `attestation.provenance.bundle`
- `attestation.actor.bundle`
- `attestation.actor`
- `security.sarif.file`
- `security.sbom.file`

### Step 3: Download and Verify

```bash
# Download (note the /-/ in the path!)
jf rt download "nodejs-test-npm-local-dev/nodejs-template/-/nodejs-template-1.0.1.tgz" --flat

# Verify
gh attestation verify nodejs-template-1.0.1.tgz --owner allenlewisr
```

### Step 4: Or Use the Script

```bash
./scripts/verify-attestation.sh nodejs-template-1.0.1.tgz nodejs-test-npm-local-dev allenlewisr
```

## What Changed?

### The Key Fix: Attest the Published Package

Instead of attesting a local file before publishing, we now:

1. **Publish** to JFrog first
2. **Download** the published package from JFrog
3. **Attest** the downloaded package

This ensures the attestation is for the **exact file** stored in JFrog!

```yaml
# New flow
jf npm publish → download from JFrog → attest downloaded file
```

### Path Fix

The workflow also correctly calculates the npm artifact path:

```yaml
NPM_ARTIFACT_PATH="${PACKAGE_NAME}/-/${TARBALL_NAME}"
# Result: nodejs-template/-/nodejs-template-1.0.1.tgz
```

### Key Points

1. **`jf npm publish`** uses npm registry path structure with `/-/` separator
2. **`jf rt upload`** uses flat structure (no `/-/`)
3. The workflow now handles npm structure correctly
4. Properties are now set on the correct path
5. Attestations can be verified successfully

## Expected Results

✅ Package published to correct npm path  
✅ Attestations created in GitHub  
✅ Properties set on artifact in JFrog  
✅ SARIF and SBOM linked bidirectionally  
✅ Verification succeeds  

## Troubleshooting

If verification still fails:

1. **Check the workflow logs** - ensure no errors in property-setting steps
2. **Verify the path** - run the property query command above
3. **Check attestations exist** - visit https://github.com/allenlewisr/nodejs-test/attestations
4. **Re-download** - ensure you have the exact file from JFrog
5. **Use correct owner** - `allenlewisr` (user) not `allenlewisr/nodejs-test` (repo)

## More Information

- Full documentation: `docs/NPM_PUBLISH_ATTESTATION_FIX.md`
- Troubleshooting: `docs/ATTESTATION_VERIFICATION_TROUBLESHOOTING.md`
- Public npm: `docs/ATTESTATION_WITH_NPM.md`

