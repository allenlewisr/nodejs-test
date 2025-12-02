# Testing the Environment Approval Flow

This guide walks you through testing the newly configured GitHub Environment approvals for JFrog promotions.

## Prerequisites

Before testing, ensure:

1. ✅ All four environments (DEV, QA, UAT, PROD) are configured in GitHub Settings > Environments
2. ✅ Required reviewers are assigned to each environment
3. ✅ The jfrog-promotion.yml workflow has been updated with the `environment` field
4. ✅ You have a release bundle already promoted to DEV (created by the release-bundle workflow)

## Test Scenario 1: Promote to QA (Basic Test)

### Step 1: Trigger the Promotion Workflow

1. Go to your repository on GitHub
2. Navigate to **Actions** tab
3. Click on **JFrog Promotion** workflow (left sidebar)
4. Click **Run workflow** button (right side)
5. Fill in the form:
   - **Target environment**: Select `QA`
   - **Release bundle version**: Enter the version you want to promote (e.g., `1.0.0+build.123`)
   - **Release bundle name**: (Optional) Leave empty to use default
   - **JFrog repository name**: (Optional) Leave empty to use default
6. Click **Run workflow**

### Step 2: Observe the Approval Request

1. The workflow run will start
2. You'll see the workflow status as "Waiting" with a yellow/orange indicator
3. Click on the workflow run to see details
4. You should see a message: **"Review pending deployments"** or similar
5. The `promote` job will show as waiting for approval

### Step 3: Review as an Approver

**As a configured QA approver:**

1. Navigate to the workflow run (you should receive a notification)
2. Click the **Review pending deployments** button
3. You'll see:
   - Environment name: `QA`
   - Workflow details
   - Option to approve or reject
4. Optionally add a comment (e.g., "Approved for QA testing")
5. Click **Approve and deploy**

### Step 4: Verify Workflow Completion

1. After approval, the workflow should continue
2. Watch the `promote` job run the promotion steps
3. Verify the workflow completes successfully (green checkmark ✅)
4. Check JFrog Artifactory to confirm the bundle was promoted to QA

## Test Scenario 2: Promote Through Multiple Environments

Test the full promotion path: DEV → QA → UAT → PROD

### 2.1 Promote DEV to QA
- Follow Test Scenario 1
- Verify DEV approver(s) can approve

### 2.2 Promote QA to UAT
- Trigger workflow with **Target environment**: `UAT`
- Verify different approvers (UAT reviewers) are notified
- Approve and verify completion

### 2.3 Promote UAT to PROD
- Trigger workflow with **Target environment**: `PROD`
- Verify PROD approvers are notified
- This is the most critical approval - verify extra security if configured
- Approve and verify completion

## Test Scenario 3: Rejection Test

Test what happens when an approval is rejected:

1. Trigger a promotion to any environment
2. Wait for the approval request
3. Click **Review pending deployments**
4. Add a comment explaining the rejection (e.g., "Security scan failed")
5. Click **Reject**
6. Verify the workflow is cancelled and doesn't proceed

## Test Scenario 4: Multiple Reviewers Test

If you configured multiple required reviewers for an environment:

1. Trigger a promotion to that environment
2. Verify all configured reviewers receive notifications
3. Have one reviewer approve
4. Verify the workflow continues (GitHub requires approval from any one of the reviewers, unless configured otherwise)

## Verification Checklist

After testing, verify:

- [ ] Workflow pauses and waits for approval before promoting
- [ ] Correct reviewers receive notifications for each environment
- [ ] Approval allows the workflow to continue
- [ ] Rejection cancels the workflow
- [ ] Deployment history is recorded in the environment (Settings > Environments > [Environment Name])
- [ ] Different environments have different reviewers working correctly
- [ ] JFrog promotion completes successfully after approval

## Viewing Deployment History

To see the audit trail:

1. Go to **Settings > Environments**
2. Click on an environment (e.g., `QA`)
3. Scroll down to **Deployment history**
4. You'll see:
   - All deployments to this environment
   - Who approved each deployment
   - Timestamps
   - Status (success/failure)
   - Comments from reviewers

## Common Issues and Solutions

### Issue: No approval request appears
**Solution:**
- Check that the environment name in the workflow matches exactly (case-sensitive)
- Verify the environment exists in Settings > Environments
- Ensure the `environment` field is correctly added to the job

### Issue: Reviewer doesn't receive notification
**Solution:**
- Verify the user is added as a required reviewer in environment settings
- Check the user has write access to the repository
- Ask them to check their GitHub notification settings

### Issue: "This environment requires approval from XYZ" but can't find the button
**Solution:**
- Refresh the Actions page
- Only the required reviewers will see the approval button
- Check that you're logged in as one of the configured reviewers

### Issue: Workflow fails at promotion step (after approval)
**Solution:**
- This is unrelated to approvals - check the promotion logic
- Verify JFrog credentials and bundle names are correct
- Review the step logs for specific error messages

## Tips for Production Use

1. **Start with lower environments**: Test thoroughly in DEV and QA before configuring strict PROD approvals
2. **Use teams instead of individuals**: Assign GitHub teams as reviewers for better coverage
3. **Document approval criteria**: Add comments when approving/rejecting to create an audit trail
4. **Set up notifications**: Ensure reviewers have proper notification settings
5. **Consider wait timers**: For PROD, consider adding a wait timer (e.g., 30 minutes) to allow for emergency rollbacks

## Next Steps

Once testing is complete:

1. Document your approval process for your team
2. Train all required reviewers on how to approve deployments
3. Update your deployment runbook to include approval steps
4. Consider setting up Slack/email notifications for approval requests
5. Monitor the deployment history regularly for audit purposes

## Additional Resources

- [GitHub Docs: Reviewing Deployments](https://docs.github.com/en/actions/managing-workflow-runs/reviewing-deployments)
- [GitHub Docs: Environment Deployment History](https://docs.github.com/en/actions/deployment/managing-your-deployments/viewing-deployment-history)

