# Bidirectional Artifact Linking

## Overview

The npm packages and their security artifacts (SARIF files) are now **bidirectionally linked** through JFrog Artifactory properties, enabling easy traversal in both directions.

## Why Bidirectional Linking?

### Use Cases:

1. **From Package → Security Artifacts**
   - "Show me all security scans for this package"
   - "What vulnerabilities were found in version X?"
   - "Was this package scanned with CodeQL?"

2. **From Security Artifact → Package**
   - "Which package does this SARIF belong to?"
   - "What package was affected by this security finding?"
   - "Find packages with specific scan results"

3. **Compliance & Auditing**
   - Prove every package has been scanned
   - Track security scan history
   - Generate security reports

4. **Automation**
   - Automatically fetch scan results for a package
   - Block deployments based on scan findings
   - Generate security dashboards

## Implementation Details

### Package Properties (npm repository)

Every npm package tarball includes these security-related properties:

| Property                    | Description              | Example Value                           |
| --------------------------- | ------------------------ | --------------------------------------- |
| `security.repo`             | Security repository name | `nodejs-test-security-local`            |
| `security.sarif.file`       | SARIF filename           | `nodejs-test-codeql-123-abc12345.sarif` |
| `security.sarif.path`       | Full SARIF path          | `nodejs-test-security-local/...sarif`   |
| `security.scan.type`        | Type of security scan    | `codeql`                                |
| `security.scan.language`    | Scan language            | `javascript`                            |
| `security.scan.attestation` | Attestation bundle path  | `.../attestation-bundle.json`           |

### SARIF Properties (security repository)

Every SARIF file includes these package-related properties:

| Property                    | Description               | Example Value                     |
| --------------------------- | ------------------------- | --------------------------------- |
| `related.artifact`          | Package filename          | `your-package-1.0.0-abc12345.tgz` |
| `related.package.repo`      | Package repository        | `nodejs-test-npm-local-dev`       |
| `scan.type`                 | Type of scan              | `codeql`                          |
| `scan.language`             | Language scanned          | `javascript`                      |
| `attestation.commit`        | Git commit SHA            | `abc123...`                       |
| `attestation.codeql.bundle` | CodeQL attestation bundle | `.../bundle.json`                 |

## Query Examples

### 1. Get SARIF file for a specific package

```bash
# Method 1: Query package properties
jf rt curl -XGET "/api/storage/nodejs-test-npm-local-dev/your-package-1.0.0-abc12345.tgz?properties=security.sarif.path"

# Method 2: AQL query
jf rt curl -XPOST "/api/search/aql" -d '
items.find({
  "repo": "nodejs-test-npm-local-dev",
  "name": "your-package-1.0.0-abc12345.tgz"
}).include("property.security.sarif.path")
'
```

**Response:**

```json
{
  "properties": {
    "security.sarif.path": [
      "nodejs-test-security-local/nodejs-test-codeql-123-abc12345.sarif"
    ]
  }
}
```

### 2. Get package for a specific SARIF file

```bash
# Query SARIF properties
jf rt curl -XGET "/api/storage/nodejs-test-security-local/nodejs-test-codeql-123-abc12345.sarif?properties=related.artifact,related.package.repo"

# Or use AQL
jf rt curl -XPOST "/api/search/aql" -d '
items.find({
  "repo": "nodejs-test-security-local",
  "name": "nodejs-test-codeql-123-abc12345.sarif"
}).include("property.related.*")
'
```

**Response:**

```json
{
  "properties": {
    "related.artifact": ["your-package-1.0.0-abc12345.tgz"],
    "related.package.repo": ["nodejs-test-npm-local-dev"]
  }
}
```

### 3. Find all packages scanned with CodeQL

```bash
jf rt curl -XPOST "/api/search/aql" -d '
items.find({
  "repo": "nodejs-test-npm-local-dev",
  "@security.scan.type": "codeql"
})
'
```

### 4. Find all security scans for a specific commit

```bash
# Find packages from commit
jf rt curl -XPOST "/api/search/aql" -d '
items.find({
  "repo": "nodejs-test-npm-local-dev",
  "@attestation.commit": "abc123..."
})
'

# Find SARIF files from commit
jf rt curl -XPOST "/api/search/aql" -d '
items.find({
  "repo": "nodejs-test-security-local",
  "@attestation.commit": "abc123..."
})
'
```

### 5. Verify package has security scan

```bash
# Check if package has associated SARIF
PACKAGE="your-package-1.0.0-abc12345.tgz"

SARIF_PATH=$(jf rt curl -XGET "/api/storage/nodejs-test-npm-local-dev/${PACKAGE}" | \
  jq -r '.properties["security.sarif.path"][0]')

if [ -n "$SARIF_PATH" ]; then
  echo "✓ Package has security scan: $SARIF_PATH"
else
  echo "✗ Package missing security scan!"
  exit 1
fi
```

## Workflow Integration

### How Links Are Created

**Step 1: Package is uploaded**

```yaml
- name: Publish to JFrog Artifactory
  run: |
    jf rt upload "${{ env.TARBALL_PATH }}" "${{ env.JFROG_REPO_NAME }}/" \
      --build-name=${{ env.BUILD_NAME }} \
      --build-number=${{ github.run_number }}
```

**Step 2: Initial package metadata (without SARIF link)**

```yaml
- name: Add attestation metadata to JFrog artifact
  run: |
    jf rt set-props "${ARTIFACT_PATH}" \
      "attestation.github.url=...;security.repo=${{ env.JFROG_SECURITY_REPO_NAME }}"
```

**Step 3: SARIF is uploaded**

```yaml
- name: Upload CodeQL SARIF to JFrog
  run: |
    jf rt upload "${{ env.SARIF_JFROG_NAME }}" "${{ env.JFROG_SECURITY_REPO_NAME }}/"
```

**Step 4: SARIF → Package link**

```yaml
- name: Add CodeQL attestation metadata to SARIF in JFrog
  run: |
    jf rt set-props "${SARIF_ARTIFACT_PATH}" \
      "scan.type=codeql;related.artifact=${{ env.TARBALL_PATH }};related.package.repo=${{ env.JFROG_REPO_NAME }}"
```

**Step 5: Package → SARIF link (completing bidirectional link)**

```yaml
- name: Link package to SARIF security artifact
  run: |
    jf rt set-props "${ARTIFACT_PATH}" \
      "security.sarif.file=${{ env.SARIF_JFROG_NAME }};security.sarif.path=${{ env.JFROG_SECURITY_REPO_NAME }}/${{ env.SARIF_JFROG_NAME }}"
```

## Automation Scripts

### Script: Get SARIF for Package

```bash
#!/bin/bash
# get-package-sarif.sh

PACKAGE_NAME=$1
REPO="nodejs-test-npm-local-dev"

if [ -z "$PACKAGE_NAME" ]; then
  echo "Usage: $0 <package-name.tgz>"
  exit 1
fi

echo "Fetching SARIF for package: $PACKAGE_NAME"

# Get SARIF path from package properties
SARIF_PATH=$(jf rt curl -XGET "/api/storage/${REPO}/${PACKAGE_NAME}" | \
  jq -r '.properties["security.sarif.path"][0]')

if [ -z "$SARIF_PATH" ] || [ "$SARIF_PATH" = "null" ]; then
  echo "✗ No SARIF file found for package"
  exit 1
fi

echo "✓ SARIF location: $SARIF_PATH"

# Download SARIF
SARIF_FILE=$(basename "$SARIF_PATH")
jf rt download "$SARIF_PATH" "./$SARIF_FILE"

echo "✓ Downloaded: ./$SARIF_FILE"
```

### Script: Verify Package Has Scan

```bash
#!/bin/bash
# verify-package-scan.sh

PACKAGE_NAME=$1
REPO="nodejs-test-npm-local-dev"

if [ -z "$PACKAGE_NAME" ]; then
  echo "Usage: $0 <package-name.tgz>"
  exit 1
fi

echo "Verifying security scan for: $PACKAGE_NAME"

# Check if package exists
if ! jf rt curl -XGET "/api/storage/${REPO}/${PACKAGE_NAME}" --silent --fail > /dev/null 2>&1; then
  echo "✗ Package not found: $PACKAGE_NAME"
  exit 1
fi

# Get package properties
PROPS=$(jf rt curl -XGET "/api/storage/${REPO}/${PACKAGE_NAME}")

SCAN_TYPE=$(echo "$PROPS" | jq -r '.properties["security.scan.type"][0]')
SARIF_FILE=$(echo "$PROPS" | jq -r '.properties["security.sarif.file"][0]')
SARIF_PATH=$(echo "$PROPS" | jq -r '.properties["security.sarif.path"][0]')

# Verify properties exist
if [ -z "$SCAN_TYPE" ] || [ "$SCAN_TYPE" = "null" ]; then
  echo "✗ No security scan found for package"
  exit 1
fi

echo "✓ Security scan found"
echo "  Scan Type: $SCAN_TYPE"
echo "  SARIF File: $SARIF_FILE"
echo "  SARIF Path: $SARIF_PATH"

# Verify SARIF file exists
if jf rt curl -XGET "/api/storage/${SARIF_PATH}" --silent --fail > /dev/null 2>&1; then
  echo "✓ SARIF file verified in repository"
else
  echo "✗ SARIF file not found at: $SARIF_PATH"
  exit 1
fi

echo "✓ Package security verification complete"
```

### Script: Generate Security Report

```bash
#!/bin/bash
# security-report.sh

REPO="nodejs-test-npm-local-dev"

echo "Generating Security Report"
echo "=========================="

# Find all packages
PACKAGES=$(jf rt curl -XPOST "/api/search/aql" -d "items.find({\"repo\": \"${REPO}\", \"type\": \"file\", \"name\": {\"\$match\": \"*.tgz\"}})" | \
  jq -r '.results[].name')

TOTAL=0
SCANNED=0
NOT_SCANNED=0

for PACKAGE in $PACKAGES; do
  ((TOTAL++))

  SCAN_TYPE=$(jf rt curl -XGET "/api/storage/${REPO}/${PACKAGE}" 2>/dev/null | \
    jq -r '.properties["security.scan.type"][0]')

  if [ -n "$SCAN_TYPE" ] && [ "$SCAN_TYPE" != "null" ]; then
    ((SCANNED++))
    echo "✓ $PACKAGE - Scanned ($SCAN_TYPE)"
  else
    ((NOT_SCANNED++))
    echo "✗ $PACKAGE - NOT SCANNED"
  fi
done

echo ""
echo "Summary"
echo "-------"
echo "Total Packages: $TOTAL"
echo "Scanned: $SCANNED"
echo "Not Scanned: $NOT_SCANNED"
echo "Coverage: $((SCANNED * 100 / TOTAL))%"

if [ $NOT_SCANNED -gt 0 ]; then
  exit 1
fi
```

## Best Practices

1. **Always verify bidirectional links** after creation
2. **Use consistent property naming** across repositories
3. **Include timestamp properties** for audit trails
4. **Automate link validation** in CI/CD pipelines
5. **Set up monitoring** for packages without scans
6. **Document custom properties** in team wiki
7. **Use AQL for complex queries** across repositories

## Troubleshooting

### Missing Links

**Symptom:** Package has no `security.sarif.path` property

**Solutions:**

- Check if the "Link package to SARIF" step ran successfully
- Verify the step runs AFTER SARIF upload
- Check workflow logs for errors

### Broken Links

**Symptom:** SARIF path in package properties points to non-existent file

**Solutions:**

- Verify SARIF was uploaded successfully
- Check SARIF repository name matches
- Verify retention policies haven't deleted the SARIF

### Query Returns No Results

**Symptom:** AQL queries return empty results

**Solutions:**

- Verify property names match exactly (case-sensitive)
- Check if properties were set (use `/api/storage/...` endpoint)
- Ensure you have read permissions on both repositories

## Future Enhancements

Potential additions to the linking system:

1. **Multiple Scan Types**: Link SAST, DAST, dependency scans
2. **Historical Links**: Track scan results across package versions
3. **Compliance Links**: Link to compliance attestations
4. **License Scans**: Link to license analysis reports
5. **Test Results**: Link to test coverage reports
6. **Performance Reports**: Link to performance benchmarks

## Related Documentation

- [SECURITY_REPOSITORY_SETUP.md](./SECURITY_REPOSITORY_SETUP.md) - Security repository setup
- [ATTESTATION_VERIFICATION.md](./ATTESTATION_VERIFICATION.md) - Attestation verification
- [JFrog Properties API](https://jfrog.com/help/r/jfrog-rest-apis/set-item-properties)
- [JFrog AQL Documentation](https://jfrog.com/help/r/jfrog-artifactory-documentation/artifactory-query-language)
