# Quick Start: Verifying Attestations

## TL;DR - What You Can Do Right Now

### 1. Inspect Your Current Build Attestations

```bash
./scripts/inspect-attestation.sh sha256:6acb2e3ac756c5aeb3504aff8ef3ada13033165a6d3003713084ad3e41874132.jsonl
```

### 2. View All Attestations Online

```bash
open https://github.com/allenlewisr/nodejs-test/attestations
```

### 3. Create a Promotion Attestation

```bash
# This will create a promotion attestation when you run it
gh workflow run jfrog-promotion.yml \
  -f target_env=QA \
  -f release_bundle_version=1.0.1+build.1
```

## What's in Your Current Bundle?

Your file `sha256:6acb2e3ac756c5aeb3504aff8ef3ada13033165a6d3003713084ad3e41874132.jsonl` contains:

✅ **Actor Attestation** - Proves `allenlewis32` built this at 2025-12-02T19:47:01  
✅ **Provenance Attestation** - Proves it was built by `unified-build.yml` workflow

Both are cryptographically signed and recorded in Sigstore's transparency log.

## The Difference

| Build Attestations             | Promotion Attestations           |
| ------------------------------ | -------------------------------- |
| You have these now ✅          | Created during promotion ⏳      |
| Prove who built it             | Prove who promoted and approved  |
| For artifact files             | For release bundles              |
| Created by `unified-build.yml` | Created by `jfrog-promotion.yml` |

## Tools You Have

1. **`./scripts/inspect-attestation.sh`** - Inspect any attestation bundle
2. **`./scripts/verify-promotion-chain.sh`** - Verify complete promotion chain
3. **`./scripts/verify-attestation.sh`** - Verify build attestations

## Next Steps

### To See a Promotion Attestation:

1. **Run a promotion:**

   ```bash
   gh workflow run jfrog-promotion.yml -f target_env=QA -f release_bundle_version=1.0.1+build.1
   ```

2. **Wait for it to complete**

3. **View the attestation:**

   ```bash
   open https://github.com/allenlewisr/nodejs-test/attestations
   ```

   Look for predicate type: `https://github.com/attestation/promotion/v1`

### To Download a Promotion Attestation Bundle:

After a promotion runs, check the workflow logs:

```bash
gh run list --workflow=jfrog-promotion.yml --limit 1
gh run view <run-id> --log | grep "Attestation bundle:"
```

The bundle path will be printed in the logs. You can then inspect it:

```bash
./scripts/inspect-attestation.sh <promotion-bundle-path>.jsonl
```

## Quick Commands Reference

```bash
# Inspect any bundle
./scripts/inspect-attestation.sh <file>.jsonl

# Verify promotion chain
./scripts/verify-promotion-chain.sh \
  --bundle-name nodejs-test \
  --bundle-version 1.0.1+build.1 \
  --repo-owner allenlewisr \
  --repo-name nodejs-test

# View attestations online
open https://github.com/allenlewisr/nodejs-test/attestations

# List recent promotions
gh run list --workflow=jfrog-promotion.yml --limit 5

# View specific run logs
gh run view <run-id> --log
```

## Documentation

- **`ATTESTATION_SUMMARY.md`** - Complete summary of what you have
- **`VERIFY_PROMOTION_ATTESTATION.md`** - Detailed verification guide
- **`PROMOTION_ATTESTATION_GUIDE.md`** - Full promotion attestation docs

## Example Output

When you inspect your current bundle:

```
╔══════════════════════════════════════════════════════════════╗
║          Attestation Bundle Inspector                       ║
╚══════════════════════════════════════════════════════════════╝

Total attestations in bundle: 2

Attestation #1
═══════════════════════════════════════════════════════════════
Subject: nodejs-template-1.0.1.tgz
Predicate Type: https://github.com/attestation/actor/v1

Predicate Content:
{
  "actor": "allenlewis32",
  "actorId": "40535590",
  "triggeredBy": "push",
  "workflow": "Build and Release",
  "runId": "19861723295",
  "timestamp": "2025-12-02T19:47:01+05:30"
}
```

---

**Ready to start?** Run the inspection script on your existing bundle:

```bash
./scripts/inspect-attestation.sh sha256:6acb2e3ac756c5aeb3504aff8ef3ada13033165a6d3003713084ad3e41874132.jsonl
```
