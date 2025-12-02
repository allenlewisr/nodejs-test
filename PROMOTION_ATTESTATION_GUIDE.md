# Promotion Attestation Guide

This guide explains how promotion attestations work, what information they capture, and how to use them effectively for compliance and security auditing.

## Overview

Promotion attestations provide cryptographically signed proof of who promoted artifacts through environments and who approved each promotion. They solve a critical gap in GitHub Actions OIDC authentication where only the service identity (not individual users) is visible in JFrog.

## The Problem: OIDC Identity Limitation

### Traditional Authentication Flow

When GitHub Actions authenticates to JFrog using OIDC:

```
GitHub Actions → OIDC Token → JFrog Artifactory
                    ↓
            Service Identity
         (not human actors)
```

**What JFrog sees:**
- Workflow name: `JFrog Promotion`
- Repository: `org/repo`
- GitHub Actions service identity

**What JFrog does NOT see:**
- Who triggered the promotion
- Who approved the promotion
- Individual human actor identities

### The Solution: Promotion Attestations

Promotion attestations capture human actor information and cryptographically sign it:

```
GitHub Actions → API Query → Fetch Approvers
       ↓              ↓
   Trigger User   Approver Users
       ↓              ↓
       └──────┬───────┘
              ↓
      Create Attestation
              ↓
      Sigstore Signing
              ↓
    Permanent Record
```

## How Promotion Attestations Work

### 1. Workflow Execution

When a promotion workflow runs:

1. **Environment Gate**: GitHub checks if approvers are required
2. **Approval Wait**: Workflow pauses for reviewer approval
3. **Approval Granted**: Reviewers approve the deployment
4. **Workflow Continues**: Promotion executes

### 2. Information Capture

After promotion succeeds, the workflow:

```yaml
# Step 1: Get source environment from promotion history
- Query JFrog promotion records
- Identify the previous stage (source environment)

# Step 2: Fetch approver information
- Call GitHub API: /actions/runs/{run_id}/approvals
- Extract approver usernames
- Handle case where no approvals exist

# Step 3: Calculate bundle digest
- Create stable representation of the bundle
- Calculate SHA256 digest for attestation subject

# Step 4: Create attestation
- Bundle all information into predicate
- Sign with Sigstore
- Generate attestation bundle

# Step 5: Store metadata
- Log attestation details
- Provide verification instructions
```

### 3. Attestation Creation

The attestation includes:

```json
{
  "subject": {
    "name": "nodejs-test",
    "digest": {
      "sha256": "abc123..."
    }
  },
  "predicateType": "https://github.com/attestation/promotion/v1",
  "predicate": {
    "triggeredBy": "john.doe",
    "triggeredById": "12345",
    "approvedBy": "jane.smith,ops-manager",
    "sourceEnvironment": "QA",
    "targetEnvironment": "UAT",
    "bundleName": "nodejs-test",
    "bundleVersion": "1.0.0+build.42",
    "repository": "org/nodejs-test",
    "workflowRunId": "987654321",
    "timestamp": "2025-11-28T10:30:00Z",
    "verificationUrl": "https://github.com/org/nodejs-test/actions/runs/987654321"
  }
}
```

### 4. Cryptographic Signing

The attestation is signed using Sigstore:

- **Keyless signing**: No private keys to manage
- **Transparency log**: Recorded in public Rekor log
- **Verifiable**: Anyone can verify the signature
- **Tamper-proof**: Any modification breaks the signature

## Implementation Details

### GitHub API for Approvals

The workflow uses this API endpoint:

```bash
gh api repos/{owner}/{repo}/actions/runs/{run_id}/approvals
```

**Response format:**

```json
[
  {
    "user": {
      "login": "approver-username",
      "id": 12345
    },
    "environments": [
      {
        "name": "UAT"
      }
    ],
    "state": "approved",
    "comment": "Approved for deployment",
    "created_at": "2025-11-28T10:25:00Z"
  }
]
```

### Bundle Digest Calculation

Since release bundles don't have a physical file to hash, we create a stable identifier:

```bash
# Create bundle subject
bundle_subject="${BUNDLE_NAME}:${BUNDLE_VERSION}"

# Calculate SHA256
bundle_digest=$(echo -n "$bundle_subject" | sha256sum | awk '{print $1}')
```

This digest is used as the attestation subject, binding the attestation to the specific bundle version.

### Attestation Storage

Attestations are stored:

1. **GitHub**: Visible at `https://github.com/{org}/{repo}/attestations`
2. **Sigstore Rekor**: Public transparency log
3. **Local bundle**: Can be downloaded for offline verification

## Predicate Fields Explained

### Core Identity Fields

- **`triggeredBy`**: GitHub username who clicked "Run workflow"
- **`triggeredById`**: GitHub user ID (numeric)
- **`approvedBy`**: Comma-separated list of approver usernames
  - Value is "none" if environment has no required reviewers
  - Multiple approvers separated by commas

### Environment Fields

- **`sourceEnvironment`**: Where the bundle was promoted FROM (DEV, QA, UAT)
- **`targetEnvironment`**: Where the bundle was promoted TO (QA, UAT, PROD)

### Bundle Fields

- **`bundleName`**: JFrog release bundle name
- **`bundleVersion`**: Full version including build number (e.g., `1.0.0+build.42`)

### Verification Fields

- **`workflowRunId`**: GitHub Actions run ID for this promotion
- **`verificationUrl`**: Direct link to the workflow run
- **`timestamp`**: When the promotion was triggered

## Use Cases

### 1. Compliance Auditing

**Scenario**: SOX audit requires proof of who approved production deployment

**Solution**:
```bash
# View production promotion attestation
# Navigate to: https://github.com/org/repo/attestations
# Filter for predicate type: promotion/v1
# Find the promotion to PROD
# Verify approvers match authorized list
```

### 2. Incident Investigation

**Scenario**: Investigate who deployed a specific version to production

**Solution**:
```bash
# Get promotion history
jf rt curl -XGET "/api/v2/promotion/records/bundle-name/version" | \
  jq '.promotions[] | select(.stage=="PROD")'

# Find corresponding attestation on GitHub
# Check who triggered and who approved
# Follow verificationUrl to see full workflow logs
```

### 3. Change Management

**Scenario**: Document all changes for change advisory board

**Solution**:
```bash
# Run verification script
./scripts/verify-promotion-chain.sh \
  --bundle-name app \
  --bundle-version 2.0.0+build.100 \
  --repo-owner myorg \
  --repo-name myapp

# Script outputs complete audit trail:
# - Who built the artifact
# - All promotions with approvers
# - Verification status
```

### 4. Security Forensics

**Scenario**: Verify artifact hasn't been tampered with

**Solution**:
```bash
# Download artifact from JFrog
jf rt download "repo/artifact.tgz" .

# Verify build attestation
gh attestation verify artifact.tgz --repo org/repo

# Check promotion attestations
# Verify continuous chain from build to production
# Ensure all approvals were legitimate
```

## Verification Workflows

### Complete Chain Verification

To verify the entire chain from build to production:

```bash
#!/bin/bash

BUNDLE_NAME="nodejs-test"
BUNDLE_VERSION="1.0.0+build.42"
GITHUB_REPO="org/repo"

echo "=== Verifying Complete Attestation Chain ==="

# 1. Download and verify build artifact
echo "Step 1: Build Attestation"
jf rt download "repo-dev/${BUNDLE_NAME}-*.tgz" .
ARTIFACT=$(ls ${BUNDLE_NAME}-*.tgz | head -1)
gh attestation verify "$ARTIFACT" --repo "$GITHUB_REPO"

# 2. Check promotion history
echo "Step 2: Promotion History"
jf rt curl -XGET "/api/v2/promotion/records/${BUNDLE_NAME}/${BUNDLE_VERSION}" | \
  jq -r '.promotions[] | "\(.stage): \(.status) at \(.timestamp)"'

# 3. Verify each promotion attestation
echo "Step 3: Promotion Attestations"
echo "Visit: https://github.com/${GITHUB_REPO}/attestations"
echo "Look for promotion/v1 attestations"

# 4. Validate approvers
echo "Step 4: Validate Approvers"
echo "Check each attestation's 'approvedBy' field"
echo "Verify approvers are authorized for that environment"

echo "✅ Verification complete"
```

### Automated CI/CD Verification

Add this to your deployment pipeline:

```yaml
- name: Verify promotion attestation exists
  run: |
    # Query for promotion attestation
    # This is conceptual - actual implementation depends on your setup
    
    BUNDLE="${{ inputs.bundle-name }}:${{ inputs.bundle-version }}"
    
    echo "Verifying promotion attestation for: $BUNDLE"
    echo "Check: https://github.com/${{ github.repository }}/attestations"
    
    # In practice, you'd query the GitHub API or Sigstore to verify
    # the attestation exists and contains expected approvers
```

## Security Considerations

### Trust Model

Promotion attestations rely on:

1. **GitHub's OIDC identity**: Trusted issuer
2. **Sigstore infrastructure**: Public key infrastructure
3. **GitHub API authenticity**: Source of approval data
4. **Rekor transparency log**: Immutable audit trail

### What Attestations Guarantee

✅ **Do guarantee:**
- Who triggered the workflow (from GitHub identity)
- Who approved in GitHub (from GitHub API)
- What was promoted (bundle name/version)
- When it happened (timestamp)
- Attestation hasn't been tampered with (signature)

❌ **Do NOT guarantee:**
- Approvers used MFA (depends on GitHub settings)
- Approvers are still employed (point-in-time record)
- Approval was well-informed (policy enforcement separate)
- No other path to promotion exists (depends on branch protection)

### Best Practices

1. **Verify attestations regularly**: Don't just create, also check them
2. **Combine with other controls**: Attestations + branch protection + environment secrets
3. **Audit approver lists**: Regularly review who can approve each environment
4. **Archive attestation bundles**: Keep offline copies for long-term compliance
5. **Monitor Sigstore logs**: Check for unexpected attestations
6. **Test verification process**: Ensure your team can verify attestations
7. **Document approval criteria**: What should approvers check before approving?

## Troubleshooting

### No Approvers Found

**Symptom**: `approvedBy: "none"` in attestation

**Causes:**
- Environment doesn't have required reviewers configured
- Workflow ran before approval feature was implemented
- API query failed (non-fatal)

**Solution:**
- Configure required reviewers in GitHub Environment settings
- Check workflow logs for API errors

### Attestation Not Found

**Symptom**: Cannot find attestation on GitHub

**Causes:**
- Workflow didn't complete successfully
- Permissions missing (`attestations: write`)
- Attestation creation step failed

**Solution:**
- Check workflow logs for errors
- Verify permissions in workflow file
- Ensure `actions/attest@v2` action ran successfully

### Verification URL 404

**Symptom**: `verificationUrl` returns 404

**Causes:**
- Workflow run was deleted
- Repository was renamed/moved
- Insufficient permissions to view run

**Solution:**
- Check repository settings for workflow retention
- Update URL if repository moved
- Ensure you have read access to Actions

### Bundle Digest Mismatch

**Symptom**: Digest doesn't match expected value

**Causes:**
- Bundle name or version changed
- Different digest calculation method
- Attestation is for different bundle

**Solution:**
- Verify bundle name and version are exact matches
- Check that digest calculation uses same method
- Ensure you're looking at the correct attestation

## Integration Examples

### With JIRA

```bash
# Add attestation URL to JIRA ticket
ATTESTATION_URL="https://github.com/org/repo/attestations"
BUNDLE_VERSION="1.0.0+build.42"

jira comment add PROJ-123 \
  "Promoted to PROD with attestation: ${ATTESTATION_URL}
   Bundle: ${BUNDLE_VERSION}
   Verify with: gh attestation verify --bundle <bundle-path>"
```

### With Slack

```yaml
- name: Notify Slack with attestation
  run: |
    curl -X POST ${{ secrets.SLACK_WEBHOOK }} \
      -H 'Content-Type: application/json' \
      -d '{
        "text": "✅ Promoted to PROD",
        "blocks": [{
          "type": "section",
          "text": {
            "type": "mrkdwn",
            "text": "*Promoted*: '"${{ env.BUNDLE_NAME }}"' v'"${{ inputs.bundle_version }}"'\n*Triggered by*: '"${{ github.actor }}"'\n*Approved by*: '"${{ steps.get-approvers.outputs.approvers }}"'\n*Attestation*: <https://github.com/${{ github.repository }}/attestations|View>"
          }
        }]
      }'
```

### With ServiceNow

```python
import requests

# Create change record with attestation
change_data = {
    "short_description": f"Promotion to PROD: {bundle_name} {bundle_version}",
    "description": f"Triggered by: {triggered_by}\nApproved by: {approved_by}",
    "attestation_url": f"https://github.com/{repo}/attestations",
    "verification_url": verification_url
}

response = requests.post(
    f"{servicenow_url}/api/now/table/change_request",
    auth=(username, password),
    json=change_data
)
```

## Compliance Mapping

### SOX (Sarbanes-Oxley)

**Requirement**: Separation of duties in change management

**How attestations help**:
- `triggeredBy` ≠ `approvedBy` (different people)
- Environment reviewers configured separately
- Immutable audit trail in Sigstore

### PCI-DSS

**Requirement**: Track and monitor all access to cardholder data environment

**How attestations help**:
- Every promotion to production is recorded
- Approvers are documented
- Timestamps provide chronological record

### SOC 2

**Requirement**: Control activities for system operations

**How attestations help**:
- Automated controls (environment gates)
- Detective controls (attestation verification)
- Audit trail for assessors

### ISO 27001

**Requirement**: Change management procedures

**How attestations help**:
- Documented approval process
- Verifiable records
- Independent audit capability

## Future Enhancements

### Potential Improvements

1. **Automated Verification**: Add verification step before allowing further promotions
2. **Policy Enforcement**: Reject promotions if attestation invalid
3. **Enhanced Metadata**: Include additional context (ticket numbers, test results)
4. **Multi-org Support**: Cross-organization attestation verification
5. **Archive Integration**: Automatic long-term storage for compliance
6. **Dashboard**: Visual representation of promotion chains
7. **Alerting**: Notify on missing or invalid attestations

### Contributing

To enhance the promotion attestation system:

1. Review current implementation in `.github/workflows/jfrog-promotion.yml`
2. Test changes thoroughly in non-production environments
3. Update documentation to reflect changes
4. Add verification tests for new fields or functionality

## Additional Resources

- [GitHub Attestations Documentation](https://docs.github.com/en/actions/security-guides/using-artifact-attestations)
- [Sigstore Documentation](https://docs.sigstore.dev/)
- [SLSA Framework](https://slsa.dev/)
- [In-toto Attestation Specification](https://github.com/in-toto/attestation)
- [Attestation Verification Guide](ATTESTATION_VERIFICATION.md)
- [Environment Approval Implementation](ENVIRONMENT_APPROVAL_IMPLEMENTATION.md)

## Summary

Promotion attestations provide a cryptographically verifiable audit trail that bridges the gap between GitHub Actions OIDC authentication (service identity) and the need for human actor attribution. By capturing and signing who triggered and approved each promotion, they enable:

- **Compliance**: Meet audit requirements with tamper-proof records
- **Security**: Verify artifact journey from build to production
- **Accountability**: Clear attribution of all changes
- **Transparency**: Anyone can verify the attestations

The system is production-ready, requires minimal maintenance, and integrates seamlessly with existing GitHub Actions and JFrog workflows.

