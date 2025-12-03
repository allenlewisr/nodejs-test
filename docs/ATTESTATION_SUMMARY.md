# Attestation Verification Summary

## What You Have Now ✅

### Current Bundle File
`sha256:6acb2e3ac756c5aeb3504aff8ef3ada13033165a6d3003713084ad3e41874132.jsonl`

This bundle contains **2 build attestations** from your recent build (Run #19861723295):

#### 1. Actor Attestation
- **Type:** `https://github.com/attestation/actor/v1`
- **Subject:** `nodejs-template-1.0.1.tgz`
- **Actor:** `allenlewis32` (ID: 40535590)
- **Triggered by:** `push`
- **Workflow:** Build and Release
- **Timestamp:** 2025-12-02T19:47:01+05:30
- **Rekor Log Index:** 736740379

#### 2. Provenance Attestation (SLSA)
- **Type:** `https://slsa.dev/provenance/v1`
- **Subject:** `nodejs-template-1.0.1.tgz`
- **Builder:** `unified-build.yml@release/1.0.0`
- **Build Type:** GitHub Actions Workflow
- **Rekor Log Index:** 736740352

Both attestations are:
- ✅ Signed with Sigstore (keyless signing)
- ✅ Recorded in Rekor transparency log
- ✅ Valid certificates (10-minute expiry - standard for keyless)
- ✅ Verifiable cryptographically

## What You Need for Promotion Attestations 📋

### Promotion Attestations vs Build Attestations

| Aspect | Build Attestations | Promotion Attestations |
|--------|-------------------|----------------------|
| **Created by** | `unified-build.yml` workflow | `jfrog-promotion.yml` workflow |
| **When** | During build/publish | During environment promotion |
| **Subject** | Artifact file (.tgz) | Release bundle identifier |
| **Predicate Type** | `actor/v1`, `provenance/v1` | `promotion/v1` |
| **Contains** | Who built, how built | Who promoted, who approved |
| **Purpose** | Prove artifact provenance | Prove promotion authorization |

### How to Get Promotion Attestations

Promotion attestations are created when you run the **JFrog Promotion workflow**:

```bash
# Trigger a promotion
gh workflow run jfrog-promotion.yml \
  -f target_env=QA \
  -f release_bundle_version=1.0.1+build.1
```

The workflow will:
1. ✅ Get approvers from GitHub environment
2. ✅ Calculate bundle digest
3. ✅ Create promotion attestation
4. ✅ Sign with Sigstore
5. ✅ Upload to GitHub

## How to View All Attestations 🔍

### Web Interface (Easiest)
Visit: **https://github.com/allenlewisr/nodejs-test/attestations**

You'll see:
- All attestations for your repository
- Filter by predicate type
- Download individual bundles
- View attestation details

### Command Line
```bash
# Using the inspection script (included)
./scripts/inspect-attestation.sh <bundle-file>.jsonl

# Using jq directly
cat <bundle-file>.jsonl | head -1 | jq -r '.dsseEnvelope.payload' | base64 -d | jq .

# Using GitHub API
gh api repos/allenlewisr/nodejs-test/attestations
```

## Verification Tools 🛠️

### 1. Inspect Attestation Bundle
```bash
./scripts/inspect-attestation.sh sha256:6acb2e3ac756c5aeb3504aff8ef3ada13033165a6d3003713084ad3e41874132.jsonl
```

Shows:
- All attestations in the bundle
- Subject and digest
- Predicate type and content
- Certificate information
- Rekor log details

### 2. Verify Promotion Chain
```bash
./scripts/verify-promotion-chain.sh \
  --bundle-name nodejs-test \
  --bundle-version 1.0.1+build.1 \
  --repo-owner allenlewisr \
  --repo-name nodejs-test \
  --jfrog-repo-prefix nodejs-test
```

Checks:
- JFrog promotion history
- GitHub attestations
- Complete audit trail

### 3. Verify Specific Attestation
```bash
# For build attestations (with artifact file)
gh attestation verify nodejs-template-1.0.1.tgz \
  --repo allenlewisr/nodejs-test

# For promotion attestations (with bundle)
gh attestation verify \
  --bundle <promotion-bundle>.jsonl \
  --repo allenlewisr/nodejs-test
```

## Quick Reference 📚

### Files You Have
- ✅ `sha256:6acb2e3ac756c5aeb3504aff8ef3ada13033165a6d3003713084ad3e41874132.jsonl` - Build attestations
- ✅ `scripts/inspect-attestation.sh` - Inspection tool
- ✅ `scripts/verify-promotion-chain.sh` - Chain verification tool
- ✅ `VERIFY_PROMOTION_ATTESTATION.md` - Detailed guide
- ✅ `PROMOTION_ATTESTATION_GUIDE.md` - Complete documentation

### What Each Attestation Proves

**Build Attestations (What You Have):**
```
✓ Who triggered the build: allenlewis32
✓ What triggered it: push to release/1.0.0
✓ Which workflow: unified-build.yml
✓ When: 2025-12-02T19:47:01+05:30
✓ How it was built: GitHub Actions workflow
✓ Where: github-hosted runner
```

**Promotion Attestations (Created During Promotion):**
```
✓ Who triggered promotion: [username]
✓ Who approved promotion: [comma-separated approvers]
✓ From environment: DEV/QA/UAT
✓ To environment: QA/UAT/PROD
✓ What was promoted: Bundle name + version
✓ When: [timestamp]
✓ Verification link: GitHub Actions run URL
```

## Next Steps 🚀

### 1. View Your Current Attestations
```bash
# Open in browser
open https://github.com/allenlewisr/nodejs-test/attestations

# Or inspect locally
./scripts/inspect-attestation.sh sha256:6acb2e3ac756c5aeb3504aff8ef3ada13033165a6d3003713084ad3e41874132.jsonl
```

### 2. Run a Promotion (to create promotion attestations)
```bash
# Promote to QA
gh workflow run jfrog-promotion.yml \
  -f target_env=QA \
  -f release_bundle_version=1.0.1+build.1

# Wait for approval (if required)
# Then check for the new attestation
```

### 3. Verify the Complete Chain
```bash
# After promotion runs
./scripts/verify-promotion-chain.sh \
  --bundle-name nodejs-test \
  --bundle-version 1.0.1+build.1 \
  --repo-owner allenlewisr \
  --repo-name nodejs-test
```

## Example: Complete Verification Workflow

```bash
# Step 1: Download artifact from JFrog
jf rt download "nodejs-test-npm-local-dev/nodejs-template/-/nodejs-template-1.0.1.tgz" --flat

# Step 2: Verify build attestations
gh attestation verify nodejs-template-1.0.1.tgz --repo allenlewisr/nodejs-test

# Step 3: Run promotion (creates promotion attestation)
gh workflow run jfrog-promotion.yml -f target_env=QA -f release_bundle_version=1.0.1+build.1

# Step 4: View promotion attestation
open https://github.com/allenlewisr/nodejs-test/attestations

# Step 5: Verify complete chain
./scripts/verify-promotion-chain.sh \
  --bundle-name nodejs-test \
  --bundle-version 1.0.1+build.1 \
  --repo-owner allenlewisr \
  --repo-name nodejs-test
```

## Troubleshooting 🔧

### Can't Verify with gh CLI
If you see certificate or verification errors:
- Use the inspection script instead: `./scripts/inspect-attestation.sh`
- View on GitHub web interface (most reliable)
- Manually inspect with jq

### No Promotion Attestations
If you don't see promotion attestations:
- They're only created when you run `jfrog-promotion.yml`
- Check workflow logs for errors
- Ensure workflow has `attestations: write` permission
- Verify the attestation step completed successfully

### Bundle File Location
After promotion workflow runs, find bundle path in logs:
```bash
gh run view <run-id> --log | grep "Attestation bundle:"
```

## Understanding the Signature

Each attestation in your bundle has:

1. **DSSE Envelope** - Signature wrapper
2. **Payload** - Base64-encoded attestation (subject + predicate)
3. **Certificate** - X.509 cert from Sigstore (10-min validity)
4. **Rekor Entry** - Transparency log proof
5. **Checkpoint** - Signed tree head from Rekor

This creates a cryptographically verifiable chain proving:
- The attestation came from your GitHub Actions
- It was created at a specific time
- It hasn't been tampered with
- It's recorded in a public transparency log

## Key Insights 💡

1. **Build attestations exist** - Your build is already creating and signing attestations
2. **Promotion attestations are separate** - They're created by the promotion workflow
3. **Both are important** - Together they provide complete provenance
4. **Everything is verifiable** - All attestations are signed and logged
5. **Web interface is easiest** - GitHub's attestation page shows everything

## Resources

- [VERIFY_PROMOTION_ATTESTATION.md](VERIFY_PROMOTION_ATTESTATION.md) - Step-by-step verification guide
- [PROMOTION_ATTESTATION_GUIDE.md](PROMOTION_ATTESTATION_GUIDE.md) - Complete promotion attestation documentation
- [GitHub Attestations](https://github.com/allenlewisr/nodejs-test/attestations) - Your repository's attestations
- [Sigstore Documentation](https://docs.sigstore.dev/) - Understanding the signing infrastructure
- [SLSA Framework](https://slsa.dev/) - Supply chain security levels

---

**Status:** ✅ Build attestations verified and documented  
**Next:** Run a promotion workflow to create promotion attestations  
**Tools:** Inspection and verification scripts ready to use

