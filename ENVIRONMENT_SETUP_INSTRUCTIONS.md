# GitHub Environment Configuration Instructions

This document provides step-by-step instructions for configuring GitHub Environments with required reviewers for the JFrog promotion workflow.

## Prerequisites

- You must be a repository administrator
- Required reviewers must have write access to the repository

## Step-by-Step Configuration

### 1. Access Environment Settings

1. Navigate to your GitHub repository
2. Click on **Settings** (top navigation bar)
3. In the left sidebar, click **Environments** (under "Code and automation" section)

### 2. Create DEV Environment

1. Click **New environment**
2. Enter name: `DEV`
3. Click **Configure environment**
4. Under **Environment protection rules**:
   - Check ✅ **Required reviewers**
   - Add users or teams who can approve DEV promotions
   - Example: `@dev-lead` or specific team members
5. (Optional) Set **Wait timer** if you want a delay before deployment
6. Click **Save protection rules**

### 3. Create QA Environment

1. Click **New environment** (from Environments page)
2. Enter name: `QA`
3. Click **Configure environment**
4. Under **Environment protection rules**:
   - Check ✅ **Required reviewers**
   - Add users or teams who can approve QA promotions
   - Example: `@qa-manager`, `@test-team`
5. Click **Save protection rules**

### 4. Create UAT Environment

1. Click **New environment**
2. Enter name: `UAT`
3. Click **Configure environment**
4. Under **Environment protection rules**:
   - Check ✅ **Required reviewers**
   - Add users or teams who can approve UAT promotions
   - Example: `@product-owner`, `@business-analyst`
5. Click **Save protection rules**

### 5. Create PROD Environment

1. Click **New environment**
2. Enter name: `PROD`
3. Click **Configure environment**
4. Under **Environment protection rules**:
   - Check ✅ **Required reviewers**
   - Add users or teams who can approve PROD promotions
   - Example: `@ops-manager`, `@cto`, `@release-team`
   - ⚠️ **Recommended**: Check ✅ **Prevent administrators from bypassing configured protection rules** for extra security
5. Click **Save protection rules**

## Configuration Examples

### Example 1: Individual Users

For each environment, add specific GitHub usernames:

- DEV: `alice`, `bob`
- QA: `charlie`, `diana`
- UAT: `emma`, `frank`
- PROD: `george`, `helen`

### Example 2: GitHub Teams

For each environment, add GitHub teams:

- DEV: `@myorg/dev-team`
- QA: `@myorg/qa-team`
- UAT: `@myorg/uat-team`
- PROD: `@myorg/release-managers`

### Example 3: Mixed Approach

Combine users and teams:

- DEV: `alice`, `@myorg/dev-team`
- QA: `@myorg/qa-team`
- UAT: `@myorg/product-team`
- PROD: `george`, `helen`, `@myorg/ops-team`

## Additional Settings (Optional)

For each environment, you can also configure:

### Deployment Branches

- Limit which branches can deploy to this environment
- Example: Only allow deployments from `main` or `release/*` branches

### Environment Secrets

- Add environment-specific secrets (e.g., API keys, credentials)
- These will only be available to jobs deploying to that environment

### Environment Variables

- Add environment-specific configuration variables
- Accessible via `vars.VARIABLE_NAME` in workflows

## Verification

After creating all four environments (DEV, QA, UAT, PROD):

1. Go back to **Settings > Environments**
2. You should see all four environments listed
3. Click on each one to verify the required reviewers are configured

## How Approvals Work

Once configured:

1. When a workflow targets an environment (e.g., promoting to QA):
   - The workflow run will pause
   - Required reviewers receive a notification
   - Reviewers see a "Review pending deployments" button in the Actions tab

2. Reviewers can:
   - **Approve** - Allows the workflow to continue
   - **Reject** - Cancels the workflow run
   - **Leave a comment** - Provide context for their decision

3. The workflow continues only after approval is granted

## Testing the Configuration

After setup, test the approval flow:

1. Trigger the JFrog promotion workflow to promote to QA
2. Verify that the workflow pauses and waits for approval
3. Check that the configured reviewers receive notifications
4. Have a reviewer approve the deployment
5. Confirm the workflow continues and completes the promotion

## Troubleshooting

### Issue: Reviewers don't receive notifications

- Ensure reviewers have write access to the repository
- Check their GitHub notification settings

### Issue: Cannot create environments

- You must be a repository administrator
- For organizations, check if environment creation is restricted

### Issue: Workflow doesn't wait for approval

- Verify the `environment` field is correctly set in the workflow file
- Check that the environment name matches exactly (case-sensitive)

## Additional Resources

- [GitHub Documentation: Using environments for deployment](https://docs.github.com/en/actions/deployment/targeting-different-environments/using-environments-for-deployment)
- [GitHub Documentation: Reviewing deployments](https://docs.github.com/en/actions/managing-workflow-runs/reviewing-deployments)
