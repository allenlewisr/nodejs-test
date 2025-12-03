# Attestation Verification Troubleshooting

## Common Issues and Solutions

### ❌ Error: 404 "Could not find package"

**Why this happens:**

- `gh attestation verify` expects packages to be in public npm registry
- Your package is in JFrog Artifactory (private)
- GitHub cannot fetch the package to compare with the attestation

**Solutions:**

#### Option 1: Verify Local File (Recommended for JFrog)

```bash
# 1. Download from JFrog (note the npm path structure: package-name/-/tarball.tgz)
jf rt download "nodejs-test-npm-local-dev/nodejs-template/-/nodejs-template-1.0.1.tgz" --flat

# 2. Verify the downloaded file
gh attestation verify nodejs-template-1.0.1.tgz --owner <your-github-org>
```

#### Option 2: Use the Verification Script

```bash
./scripts/verify-attestation.sh nodejs-template-1.0.1.tgz
```

#### Option 3: View Attestations on GitHub

Visit: `https://github.com/<your-org>/nodejs-test/attestations`

---

### ❌ Error: "No attestations found"

**Possible causes:**

1. Workflow hasn't run yet after the fix
2. Attestation step failed (check workflow logs)
3. Wrong owner/org specified

**Check:**

```bash
# List all attestations for the repo
gh api repos/<owner>/nodejs-test/attestations

# Check specific workflow run
gh run view <run-id>
```

---

### ❌ Error: "Subject digest does not match"

**Why this happens:**

- Local file has been modified
- Different version of the package

**Solution:**

```bash
# Delete and re-download from JFrog
rm nodejs-template-1.0.1.tgz
jf rt download "nodejs-test-npm-local-dev/nodejs-template/-/nodejs-template-1.0.1.tgz" --flat
gh attestation verify nodejs-template-1.0.1.tgz --owner <your-org>
```

---

### ❌ Error: "Could not find subject at path" (During Workflow)

**Why this happens:**

- The tarball was deleted before attestation step
- This is fixed in the current workflow

**The Fix (already implemented):**
The workflow now saves a backup copy of the tarball before publishing:

1. Creates tarball
2. **Saves backup** ← prevents this error
3. Publishes to JFrog (removes original)
4. **Restores from backup** ← tarball available for attestation
5. Creates attestations

---

### ⚠️ Important: NPM Repository Path Structure

When using `jf npm publish` (vs `jf rt upload`), packages are stored in npm-style paths:

**npm publish path:**

```
repo-name/package-name/-/package-name-1.0.0.tgz
```

**Direct upload path:**

```
repo-name/package-name-1.0.0.tgz
```

**Example:**

- Package: `nodejs-template@1.0.1`
- Repo: `nodejs-test-npm-local-dev`
- Path: `nodejs-test-npm-local-dev/nodejs-template/-/nodejs-template-1.0.1.tgz`

The workflow automatically handles this path structure when setting properties and creating attestations.

---

## Verification Best Practices

### For JFrog-hosted Packages (npm publish)

Always download first, then verify. Note the npm path structure:

```bash
# Complete verification flow (npm path structure: package-name/-/tarball.tgz)
jf rt download "repo-name/package-name/-/package-1.0.0.tgz" --flat
gh attestation verify package-1.0.0.tgz --owner <org>

# Example:
jf rt download "nodejs-test-npm-local-dev/nodejs-template/-/nodejs-template-1.0.1.tgz" --flat
gh attestation verify nodejs-template-1.0.1.tgz --owner allenlewisr
```

### For npm-hosted Packages

Can verify directly (no download needed):

```bash
gh attestation verify package-name@version --owner <org>
```

### Automated Verification in CI/CD

```yaml
- name: Verify package attestation
  run: |
    # Download from JFrog
    jf rt download "$REPO/$TARBALL" --flat

    # Verify
    gh attestation verify "$TARBALL" --owner "${{ github.repository_owner }}"
```

---

## Useful Commands

```bash
# List all attestations for a repository
gh api repos/<owner>/<repo>/attestations

# Verify with detailed output
gh attestation verify file.tgz --owner <org> --format json | jq

# Check attestation metadata in JFrog (npm path structure)
jf rt curl -XGET "/api/storage/repo-name/package-name/-/package.tgz?properties"

# Download specific version from JFrog (npm path structure)
jf rt download "repo-name/package-name/-/package-1.0.1.tgz" --flat

# Example:
jf rt curl -XGET "/api/storage/nodejs-test-npm-local-dev/nodejs-template/-/nodejs-template-1.0.1.tgz?properties"

# View workflow run that created attestation
gh run view --repo <owner>/<repo> <run-id>
```

---

## Understanding the Workflow

The attestation workflow creates **3 types of attestations**:

1. **Build Provenance** (`actions/attest-build-provenance@v3`)
   - Proves the package was built in GitHub Actions
   - Links to specific commit, workflow, and runner

2. **Actor Information** (`actions/attest@v2`)
   - Records who triggered the build
   - Includes approver information

3. **Security Artifacts** (SARIF, SBOM)
   - CodeQL scan results attestation
   - Software Bill of Materials attestation

All attestations are:

- ✅ Signed with Sigstore
- ✅ Stored in GitHub
- ✅ Linked to the package in JFrog (via properties)
- ✅ Immutable and tamper-proof

---

## Additional Resources

- [GitHub Attestations Documentation](https://docs.github.com/en/actions/security-guides/using-artifact-attestations)
- [Sigstore Documentation](https://docs.sigstore.dev/)
- See `docs/ATTESTATION_WITH_NPM.md` for publishing to public npm
- Use `scripts/verify-attestation.sh` for automated verification
