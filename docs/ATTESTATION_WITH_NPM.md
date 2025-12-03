# Publishing to NPM with Attestations

If you want to publish your package to the public npm registry with attestations, you can add this workflow step after publishing to JFrog.

## Why Publish to Public npm?

- `gh attestation verify` can automatically verify packages without downloading
- Users can verify packages directly: `gh attestation verify nodejs-template@1.0.1`
- Better integration with the npm ecosystem

## Add to Workflow (Optional)

Add this after the JFrog publish step in `unified-build.yml`:

```yaml
- name: Setup npm authentication (public registry)
  run: |
    echo "//registry.npmjs.org/:_authToken=${{ secrets.NPM_TOKEN }}" > ~/.npmrc

- name: Publish to public npm with attestation
  run: |
    npm publish --provenance --access public
  env:
    NODE_AUTH_TOKEN: ${{ secrets.NPM_TOKEN }}
```

## Setup Required

1. Create an npm account and token:
   - Go to https://www.npmjs.com/
   - Settings → Access Tokens → Generate New Token
   - Choose "Automation" token type

2. Add to GitHub Secrets:
   - Repository Settings → Secrets → Actions
   - Add `NPM_TOKEN` with your npm token

3. Update package.json:
   ```json
   {
     "publishConfig": {
       "access": "public",
       "provenance": true
     }
   }
   ```

## Verification After Publishing to npm

Once published to npm, anyone can verify:

```bash
# No download needed - works automatically
gh attestation verify nodejs-template@1.0.1 --owner <your-org>

# Or verify from npm registry
npm view nodejs-template attestations
```

## Dual Publishing Strategy

You can publish to both:
- **JFrog**: For internal/private consumption with full metadata
- **Public npm**: For external users with automatic verification

Both will have attestations, but the npm ones are more easily verifiable by end users.
