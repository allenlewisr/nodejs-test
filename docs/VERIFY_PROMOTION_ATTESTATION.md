# How to Verify Promotion Attestations

## What You Have Now

The file `sha256:6acb2e3ac756c5aeb3504aff8ef3ada13033165a6d3003713084ad3e41874132.jsonl` contains **build attestations** (not promotion attestations):

1. **Actor Attestation** - Who triggered the build
2. **Provenance Attestation** - How the artifact was built

### Inspecting Your Current Bundle

```bash
# See what's in the bundle (line 1 = actor attestation)
cat sha256:6acb2e3ac756c5aeb3504aff8ef3ada13033165a6d3003713084ad3e41874132.jsonl | \
  head -1 | jq -r '.dsseEnvelope.payload' | base64 -d | jq .

# Extract the actor information
cat sha256:6acb2e3ac756c5aeb3504aff8ef3ada13033165a6d3003713084ad3e41874132.jsonl | \
  head -1 | jq -r '.dsseEnvelope.payload' | base64 -d | jq '.predicate'
```

**Result shows:**
- Actor: `allenlewis32`
- Triggered by: `push`
- Workflow: `Build and Release`
- Run ID: `19861723295`
- Timestamp: `2025-12-02T19:47:01+05:30`

## How to Get Promotion Attestations

Promotion attestations are created by the **JFrog Promotion workflow**, not the build workflow.

### Method 1: View All Attestations on GitHub

Visit your repository's attestation page:
```
https://github.com/allenlewisr/nodejs-test/attestations
```

On this page, you can:
- See all attestations (build and promotion)
- Filter by predicate type
- Download individual attestation bundles

**Look for:**
- Predicate Type: `https://github.com/attestation/promotion/v1`

### Method 2: Extract from Workflow Logs

When you run a promotion workflow:

1. **Run the promotion workflow:**
   ```bash
   gh workflow run jfrog-promotion.yml \
     -f target_env=QA \
     -f release_bundle_version=1.0.1+build.1
   ```

2. **Find the workflow run:**
   ```bash
   gh run list --workflow=jfrog-promotion.yml --limit 5
   ```

3. **View the logs:**
   ```bash
   gh run view <run-id> --log
   ```

4. **Look for this line in the logs:**
   ```
   Attestation bundle: /path/to/sha256:<digest>.jsonl
   ```

5. **The bundle file is automatically created in your workflow runner**, but you need to either:
   - Upload it as an artifact (see workflow modification below)
   - Access it from GitHub's attestation API

### Method 3: Download from GitHub Attestations API

```bash
# List all attestations for a subject
gh api repos/allenlewisr/nodejs-test/attestations \
  --jq '.attestations[] | select(.predicate_type == "https://github.com/attestation/promotion/v1")'

# This will show promotion attestations with their bundle URLs
```

## Modifying Your Workflow to Upload Bundles

To make promotion attestation bundles easier to access, modify `.github/workflows/jfrog-promotion.yml`:

Add this step after the attestation creation:

```yaml
- name: Upload promotion attestation bundle
  uses: actions/upload-artifact@v4
  if: always()
  with:
    name: promotion-attestation-${{ inputs.target_env }}-${{ inputs.release_bundle_version }}
    path: ${{ steps.attest-promotion.outputs.bundle-path }}
    retention-days: 90
```

Then download it:
```bash
# Get the run ID
gh run list --workflow=jfrog-promotion.yml --limit 1

# Download the artifact
gh run download <run-id> --name promotion-attestation-QA-1.0.1+build.1
```

## Verifying Attestation Bundles

### For Build Attestations (what you have now)

```bash
# Download the actual artifact from JFrog
jf rt download "nodejs-test-npm-local-dev/nodejs-template/-/nodejs-template-1.0.1.tgz" --flat

# Verify using the bundle
gh attestation verify nodejs-template-1.0.1.tgz \
  --bundle sha256:6acb2e3ac756c5aeb3504aff8ef3ada13033165a6d3003713084ad3e41874132.jsonl \
  --repo allenlewisr/nodejs-test
```

### For Promotion Attestations (when you get one)

```bash
# Verify the promotion attestation bundle
gh attestation verify \
  --bundle <promotion-attestation>.jsonl \
  --repo allenlewisr/nodejs-test

# Or inspect manually
cat <promotion-attestation>.jsonl | jq -r '.dsseEnvelope.payload' | base64 -d | jq .
```

## Manual Inspection of Promotion Attestations

If you have a promotion attestation bundle:

```bash
# Extract the predicate (the actual attestation data)
cat promotion-bundle.jsonl | jq -r '.dsseEnvelope.payload' | base64 -d | jq '.predicate'
```

This will show you:
```json
{
  "triggeredBy": "username",
  "triggeredById": "12345",
  "approvedBy": "approver1,approver2",
  "sourceEnvironment": "DEV",
  "targetEnvironment": "QA",
  "bundleName": "nodejs-test",
  "bundleVersion": "1.0.1+build.1",
  "repository": "allenlewisr/nodejs-test",
  "workflowRunId": "123456789",
  "timestamp": "2025-12-02T...",
  "verificationUrl": "https://github.com/allenlewisr/nodejs-test/actions/runs/123456789"
}
```

## Verification Using the Script

Use the provided verification script:

```bash
./scripts/verify-promotion-chain.sh \
  --bundle-name nodejs-test \
  --bundle-version 1.0.1+build.1 \
  --repo-owner allenlewisr \
  --repo-name nodejs-test \
  --jfrog-repo-prefix nodejs-test
```

This will:
- ✅ Check JFrog promotion history
- ✅ Guide you to view attestations on GitHub
- ✅ Provide complete verification checklist

## Troubleshooting

### Certificate/TLS Errors

If you see TLS errors when using `gh` commands:
```bash
# Try with network permissions or outside sandbox
# Or use the web interface instead
open https://github.com/allenlewisr/nodejs-test/attestations
```

### Bundle Verification Fails

If `gh attestation verify` fails:
1. Ensure you have the latest `gh` CLI version
2. Try manual inspection with `jq` instead
3. Verify on GitHub's web interface
4. Check that the bundle file is complete (not truncated)

### No Promotion Attestations Found

If you don't see promotion attestations:
1. Make sure you've run the promotion workflow (not just the build)
2. Check that the promotion workflow completed successfully
3. Verify the attestation step didn't fail (check logs)
4. Ensure the workflow has `attestations: write` permission

## Summary

**Current Status:**
- ✅ You have build attestations (actor + provenance)
- ⏳ Promotion attestations are created when you run promotions
- 📍 View all at: https://github.com/allenlewisr/nodejs-test/attestations

**Next Steps:**
1. Visit the attestations page to see all attestations
2. Run a promotion workflow to create promotion attestations
3. Use the verification script to check the complete chain
4. Optionally: Modify workflow to upload attestation bundles as artifacts

## Quick Reference

| Attestation Type | Created By | Subject | Predicate Type |
|-----------------|------------|---------|----------------|
| **Actor** | Build workflow | Artifact file (.tgz) | `github.com/attestation/actor/v1` |
| **Provenance** | Build workflow | Artifact file (.tgz) | `slsa.dev/provenance/v1` |
| **Promotion** | Promotion workflow | Bundle identifier | `github.com/attestation/promotion/v1` |

## Additional Resources

- [PROMOTION_ATTESTATION_GUIDE.md](PROMOTION_ATTESTATION_GUIDE.md) - Complete guide on promotion attestations
- [scripts/verify-promotion-chain.sh](scripts/verify-promotion-chain.sh) - Automated verification script
- [GitHub Attestations Docs](https://docs.github.com/en/actions/security-guides/using-artifact-attestations)

