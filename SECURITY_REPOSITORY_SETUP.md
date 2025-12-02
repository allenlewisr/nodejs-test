# Security Repository Setup Guide

## Overview

This guide explains how to create a dedicated JFrog Artifactory repository for security artifacts (SARIF files, scan results, etc.) separate from your npm package repository.

## Why Separate Repositories?

### Benefits:

- **Proper Artifact Typing**: npm repos are optimized for npm packages; generic repos for security artifacts
- **Access Control**: Different teams can have different permissions
- **Retention Policies**: Security artifacts may need different retention requirements
- **Clean Organization**: Keeps npm repository focused on packages only
- **Scalability**: Easy to add more security tools without polluting npm repo

## Repository Architecture

```
Before (Mixed):
├── nodejs-test-npm-local-dev/
    ├── @your-org/
    │   └── your-package-1.0.0-abc12345.tgz
    └── security-reports/          ❌ Mixed artifact types
        └── nodejs-test-codeql-123-abc12345.sarif

After (Separated):
├── nodejs-test-npm-local-dev/     ✅ npm packages only
│   └── @your-org/
│       └── your-package-1.0.0-abc12345.tgz
│
└── nodejs-test-security-local/     ✅ security artifacts only
    ├── nodejs-test-codeql-123-abc12345.sarif
    ├── nodejs-test-dependency-scan-124.json
    └── ... (future security artifacts)
```

## Creating the Security Repository in JFrog

### Option 1: Using JFrog UI

1. **Login to JFrog Artifactory**
   - Navigate to your JFrog instance

2. **Create New Repository**
   - Go to: Administration → Repositories → Local
   - Click: "+ Add Repositories" → "Local Repository"

3. **Configure Repository**
   - **Package Type**: `Generic` (not npm)
   - **Repository Key**: `<repo-name>-security-local` (e.g., `nodejs-test-security-local`)
   - **Description**: "Security artifacts (SARIF, scan results, attestations)"
   - **Repository Layout**: `simple-default`

4. **Optional Settings**
   - **Enable Checksum Policy**: `Client Generated`
   - **Enable Snapshot/Release**: Based on your needs
   - **Retention Policy**: Configure based on compliance requirements

5. **Set Permissions**
   - Go to: Administration → Security → Permissions
   - Create or update permission target
   - Grant appropriate access to security team

### Option 2: Using JFrog CLI

```bash
# Create repository configuration file
cat > security-repo-config.json << 'EOF'
{
  "key": "nodejs-test-security-local",
  "rclass": "local",
  "packageType": "generic",
  "description": "Security artifacts (SARIF, scan results, attestations)",
  "repoLayoutRef": "simple-default",
  "checksumPolicyType": "client-generated",
  "handleReleases": true,
  "handleSnapshots": true
}
EOF

# Create the repository
jf rt repo-create security-repo-config.json
```

### Option 3: Using REST API

```bash
curl -X PUT "https://your-instance.jfrog.io/artifactory/api/repositories/nodejs-test-security-local" \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "key": "nodejs-test-security-local",
    "rclass": "local",
    "packageType": "generic",
    "description": "Security artifacts (SARIF, scan results, attestations)",
    "repoLayoutRef": "simple-default",
    "checksumPolicyType": "client-generated"
  }'
```

## Verification

After creating the repository, verify it exists:

```bash
jf rt curl -XGET "/api/repositories/nodejs-test-security-local"
```

Expected output should show repository details with `"type": "LOCAL"` and `"packageType": "Generic"`.

## Workflow Integration

The workflows are already configured to use the security repository via the `JFROG_SECURITY_REPO_NAME` environment variable:

```yaml
env:
  JFROG_SECURITY_REPO_NAME: '' # Default: <repo-name>-security-local
```

### Custom Repository Name (Optional)

If you want to use a different repository name, update the workflows:

```yaml
env:
  JFROG_SECURITY_REPO_NAME: 'my-custom-security-repo'
```

## Artifact Linking

Security artifacts are **bidirectionally linked** to their related packages via JFrog properties:

### Package Metadata (in npm repo):

```
attestation.github.url=https://github.com/org/repo/attestations
attestation.actor=github-user
attestation.commit=abc123...
security.repo=nodejs-test-security-local
security.sarif.file=nodejs-test-codeql-123-abc12345.sarif
security.sarif.path=nodejs-test-security-local/nodejs-test-codeql-123-abc12345.sarif
security.scan.type=codeql
security.scan.language=javascript
security.scan.attestation=path/to/bundle
```

### SARIF Metadata (in security repo):

```
scan.type=codeql
scan.language=javascript
attestation.codeql.bundle=path/to/bundle
related.artifact=package-1.0.0-abc12345.tgz
related.package.repo=nodejs-test-npm-local-dev
```

This **bidirectional linking** allows you to:

- **From Package → SARIF**: Query which security scans were performed on a package
- **From SARIF → Package**: Query which package a security scan belongs to

### Linking Diagram:

```
┌─────────────────────────────────────────────────────────────────┐
│  npm Repository: nodejs-test-npm-local-dev                      │
│                                                                  │
│  📦 your-package-1.0.0-abc12345.tgz                             │
│     Properties:                                                  │
│     • attestation.github.url=...                                │
│     • attestation.commit=abc123...                              │
│     • security.repo=nodejs-test-security-local         ─────┐   │
│     • security.sarif.file=...codeql-123-abc12345.sarif ─────┤   │
│     • security.sarif.path=nodejs-test-security-local/... ───┤   │
│     • security.scan.type=codeql                              │   │
└─────────────────────────────────────────────────────────────│───┘
                                                               │
                              Bidirectional Linking            │
                                                               │
┌─────────────────────────────────────────────────────────────│───┐
│  Security Repository: nodejs-test-security-local            │   │
│                                                              │   │
│  🔒 nodejs-test-codeql-123-abc12345.sarif                   │   │
│     Properties:                                              │   │
│     • scan.type=codeql                                       │   │
│     • scan.language=javascript                               │   │
│     • attestation.commit=abc123...                           │   │
│     • related.artifact=your-package-1.0.0-abc12345.tgz  ◄───┘   │
│     • related.package.repo=nodejs-test-npm-local-dev  ◄─────────┤
└─────────────────────────────────────────────────────────────────┘
```

## Querying Security Artifacts

### Find SARIF file for a specific package (Package → SARIF):

```bash
# Query package to get its SARIF location
jf rt curl -XPOST "/api/search/aql" -d 'items.find({
  "repo": "nodejs-test-npm-local-dev",
  "name": "your-package-1.0.0-abc12345.tgz"
}).include("name", "repo", "path", "property.*")'

# Or get SARIF path directly from properties
jf rt curl -XGET "/api/storage/nodejs-test-npm-local-dev/your-package-1.0.0-abc12345.tgz?properties=security.sarif.path"
```

### Find package for a specific SARIF file (SARIF → Package):

```bash
# Query SARIF to get its related package
jf rt curl -XPOST "/api/search/aql" -d 'items.find({
  "repo": "nodejs-test-security-local",
  "name": "nodejs-test-codeql-123-abc12345.sarif"
}).include("name", "repo", "path", "property.*")'

# Or query by related artifact property
jf rt curl -XPOST "/api/search/aql" -d 'items.find({
  "repo": "nodejs-test-security-local",
  "type": "file",
  "@related.artifact": "your-package-1.0.0-abc12345.tgz"
})'
```

### Find all packages scanned with CodeQL:

```bash
jf rt curl -XPOST "/api/search/aql" -d 'items.find({
  "repo": "nodejs-test-npm-local-dev",
  "@security.scan.type": "codeql"
})'
```

### Find all CodeQL SARIF files:

```bash
jf rt curl -XPOST "/api/search/aql" -d 'items.find({
  "repo": "nodejs-test-security-local",
  "@scan.type": "codeql"
})'
```

### Find all security artifacts for a commit:

```bash
jf rt curl -XPOST "/api/search/aql" -d 'items.find({
  "repo": "nodejs-test-security-local",
  "@attestation.commit": "abc123..."
})'
```

## Best Practices

1. **Regular Cleanup**: Set retention policies to avoid accumulating old scan results
2. **Access Control**: Limit write access to CI/CD systems only
3. **Audit Logging**: Enable audit logs for security artifacts
4. **Backup**: Include security repo in backup policies
5. **Naming Convention**: Use consistent naming: `<build-name>-<scan-type>-<run-number>-<short-sha>.sarif`

## Troubleshooting

### Repository Not Found Error

If workflows fail with "repository does not exist":

1. Verify repository exists: `jf rt curl -XGET "/api/repositories/your-security-repo"`
2. Check repository name matches `JFROG_SECURITY_REPO_NAME`
3. Verify access token has permissions to the repository

### Upload Fails

If SARIF upload fails:

1. Verify repository type is "Generic" (not npm)
2. Check network connectivity to JFrog
3. Verify access token has deploy permissions
4. Check artifact size limits

## Migration from Old Structure

If you have existing SARIF files in your npm repository:

```bash
# List existing SARIF files
jf rt search "nodejs-test-npm-local-dev/security-reports/*.sarif"

# Copy to new security repository (optional)
jf rt copy "nodejs-test-npm-local-dev/security-reports/*" "nodejs-test-security-local/"

# Clean up old location (after verification)
jf rt delete "nodejs-test-npm-local-dev/security-reports/"
```

## Next Steps

1. ✅ Create the security repository in JFrog
2. ✅ Update workflows (already done)
3. ✅ Run a test build to verify
4. ✅ (Optional) Migrate existing SARIF files
5. ✅ Configure retention policies
6. ✅ Set up appropriate permissions

## Additional Resources

- [JFrog Repository Management](https://jfrog.com/help/r/jfrog-artifactory-documentation/repository-management)
- [JFrog REST API](https://jfrog.com/help/r/jfrog-rest-apis/artifactory-rest-api)
- [Artifactory Query Language (AQL)](https://jfrog.com/help/r/jfrog-artifactory-documentation/artifactory-query-language)
