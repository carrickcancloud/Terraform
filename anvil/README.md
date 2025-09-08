# Project Anvil: A Scalable WordPress Infrastructure on AWS

Welcome to Project Anvil. This repository contains the complete Terraform and Packer code to deploy a secure, scalable, and highly observable three-tier WordPress application on Amazon Web Services.

This guide provides a detailed, "cradle-to-grave" set of instructions for all prerequisite setup and deployment. It is designed for a DevOps engineer to follow from start to finish using the command line, with minimal reliance on the AWS Management Console.

## Core Architectural Principles

- **Infrastructure as Code:** 100% of the cloud infrastructure is defined declaratively in version-controlled Terraform.
- **Immutable Infrastructure:** Servers are never modified after deployment. All changes are handled by building a new "Golden AMI" and rolling out fresh instances.
- **GitOps for Operations:** Day-to-day operational changes (like resizing instances) are managed through a version-controlled Git workflow, providing a complete audit trail and a formal review process for every change.

---

## Phase I: Initial Account & Workstation Setup (One-Time)

This phase covers the absolute basics needed before any code can be run.

### 1. Account Creation
1.  **AWS Account:** Sign up at [aws.amazon.com](https://aws.amazon.com/). Note your 12-digit AWS Account ID.
2.  **GitHub Account:** Sign up at [github.com](https://github.com/).
3.  **PagerDuty Account:** Sign up for the [PagerDuty Free plan](https://www.pagerduty.com/). Go through the UI to create a single Service named `Anvil - All Environments`, add an **AWS CloudWatch** integration, and **save the generated Integration URL**.

### 2. Local Workstation Setup
1.  **Install AWS CLI:** Follow the official guide to [install the AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html).
2.  **Install GitHub CLI:** Follow the official guide to [install `gh`](https://github.com/cli/cli#installation).
3.  **Install `jq`:** This is a command-line JSON processor.
    -   macOS: `brew install jq`
    -   Ubuntu: `sudo apt-get install jq`
4.  **Configure Tools:**
    -   Create an IAM User in the AWS Console with an access key for administrative access.
    -   Run `aws configure --profile anvil-admin` to set up your credentials.
    -   Run `gh auth login` to authenticate with GitHub.

---

## Phase II: Repository & AWS Prerequisite Setup (CLI)

This phase uses CLI commands to configure your repositories and prepare AWS.

### 1. Create and Configure Repositories

```bash
# === Set Environment Variables (run this first) ===
export GITHUB_ORG="acme-corp" # Your GitHub Organization name
export ANVIL_REPO="$GITHUB_ORG/project-anvil"
export OPS_REPO="$GITHUB_ORG/project-anvil-ops"
export REVIEWER_USERNAME="<YOUR_GITHUB_USERNAME>" # GitHub user to approve deployments

# === Create Repositories ===
gh repo create $ANVIL_REPO --private
gh repo create $OPS_REPO --private

# === Protect the 'main' branch of the Anvil Repo ===
gh api -X PUT /repos/$ANVIL_REPO/branches/main/protection -f 'required_status_checks=null' -f 'enforce_admins=true' -f 'required_pull_request_reviews[required_approving_review_count]=1' -F 'restrictions=null' -F 'required_linear_history=true'

# === Protect the 'main' branch of the Ops Repo ===
gh api -X PUT /repos/$OPS_REPO/branches/main/protection -f 'required_status_checks=null' -f 'enforce_admins=true' -f 'required_pull_request_reviews[required_approving_review_count]=1' -F 'restrictions=null'

# === Protect the Environments in the Anvil Repo ===
REVIEWER_ID=$(gh api /users/$REVIEWER_USERNAME --jq .id)
gh api -X PUT /repos/$ANVIL_REPO/environments/prod -f "reviewers[0][type]=User" -f "reviewers[0][id]=$REVIEWER_ID"
gh api -X PUT /repos/$ANVIL_REPO/environments/uat -f "reviewers[0][type]=User" -f "reviewers[0][id]=$REVIEWER_ID"
gh api -X PUT /repos/$ANVIL_REPO/environments/qa -f "reviewers[0][type]=User" -f "reviewers[0][id]=$REVIEWER_ID"
```

### 2. Create AWS OIDC Roles and GitHub Secrets

```bash
# === Set Environment Variables (run this first) ===
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text --profile anvil-admin)

# === Create Trust Policy for Anvil Repo ===
cat > trust-policy-anvil.json << EOL
{
    "Version": "2012-10-17",
    "Statement": [{
        "Effect": "Allow",
        "Principal": { "Federated": "arn:aws:iam::${AWS_ACCOUNT_ID}:oidc-provider/token.actions.githubusercontent.com" },
        "Action": "sts:AssumeRoleWithWebIdentity",
        "Condition": { "StringLike": { "token.actions.githubusercontent.com:sub": "repo:${ANVIL_REPO}:*" } }
    }]
}
EOL

# === Create Trust Policy for Ops Repo ===
cat > trust-policy-ops.json << EOL
{
    "Version": "2012-10-17",
    "Statement": [{
        "Effect": "Allow",
        "Principal": { "Federated": "arn:aws:iam::${AWS_ACCOUNT_ID}:oidc-provider/token.actions.githubusercontent.com" },
        "Action": "sts:AssumeRoleWithWebIdentity",
        "Condition": { "StringLike": { "token.actions.githubusercontent.com:sub": "repo:${OPS_REPO}:*" } }
    }]
}
EOL

# === Create IAM Roles ===
aws iam create-role --role-name anvil-bootstrap-role --assume-role-policy-document file://trust-policy-anvil.json --profile anvil-admin
aws iam create-role --role-name anvil-packer-builder-role --assume-role-policy-document file://trust-policy-anvil.json --profile anvil-admin
aws iam create-role --role-name anvil-terraform-deploy-role --assume-role-policy-document file://trust-policy-anvil.json --profile anvil-admin
aws iam create-role --role-name anvil-ops-sync-role --assume-role-policy-document file://trust-policy-ops.json --profile anvil-admin

# === Attach Policies ===
aws iam attach-role-policy --role-name anvil-bootstrap-role --policy-arn arn:aws:iam::aws:policy/AdministratorAccess --profile anvil-admin
aws iam attach-role-policy --role-name anvil-packer-builder-role --policy-arn arn:aws:iam::aws:policy/AmazonSSMFullAccess --profile anvil-admin
aws iam attach-role-policy --role-name anvil-packer-builder-role --policy-arn arn:aws:iam::aws:policy/AmazonEC2InstanceProfileForImageBuilder --profile anvil-admin
aws iam attach-role-policy --role-name anvil-terraform-deploy-role --policy-arn arn:aws:iam::aws:policy/AdministratorAccess --profile anvil-admin
aws iam attach-role-policy --role-name anvil-ops-sync-role --policy-arn arn:aws:iam::aws:policy/AmazonSSMFullAccess --profile anvil-admin

# === Create GitHub Secrets ===
BOOTSTRAP_ARN=$(aws iam get-role --role-name anvil-bootstrap-role --query 'Role.Arn' --output text --profile anvil-admin)
PACKER_ARN=$(aws iam get-role --role-name anvil-packer-builder-role --query 'Role.Arn' --output text --profile anvil-admin)
TERRAFORM_ARN=$(aws iam get-role --role-name anvil-terraform-deploy-role --query 'Role.Arn' --output text --profile anvil-admin)
OPS_SYNC_ARN=$(aws iam get-role --role-name anvil-ops-sync-role --query 'Role.Arn' --output text --profile anvil-admin)

gh secret set AWS_IAM_ROLE_FOR_BOOTSTRAP -b"$BOOTSTRAP_ARN" --repo $ANVIL_REPO
gh secret set AWS_IAM_ROLE_FOR_PACKER -b"$PACKER_ARN" --repo $ANVIL_REPO
gh secret set AWS_IAM_ROLE_FOR_ANVIL -b"$TERRAFORM_ARN" --repo $ANVIL_REPO
gh secret set AWS_IAM_ROLE_FOR_OPS_SYNC -b"$OPS_SYNC_ARN" --repo $OPS_REPO
```

---

## Phase III: The End-to-End Deployment Lifecycle

Follow this exact sequence to bring an environment online from scratch.

### **Step 1: Run the Bootstrap Pipeline**
This prepares the AWS account with foundational resources.
-   In the `project-anvil` repo, go to **Actions** -> **"Anvil: Bootstrap Foundational Infrastructure"**.
-   Run the workflow. Download and save the `ssh-private-keys.zip` artifact securely.

### **Step 2: Populate Manual Secrets**
-   In the PagerDuty UI, get the single integration URL you created in Phase I.
-   Run the following CLI command for each environment, replacing `<PAGERDUTY_URL>`:
    ```bash
    aws secretsmanager update-secret --secret-id acmelabs-website-dev-pagerduty-url --secret-string "<PAGERDUTY_URL>" --profile anvil-admin
    aws secretsmanager update-secret --secret-id acmelabs-website-qa-pagerduty-url --secret-string "<PAGERDUTY_URL>" --profile anvil-admin
    # ... and so on for uat and prod
    ```

### **Step 3: Sync Operational Configuration**
This creates the initial SSM Parameters for instance sizes.
-   In your local `project-anvil-ops` repository, commit and push the `environments/*.json` files.
-   This automatically triggers the **"Sync Operational Config to AWS SSM"** workflow. Wait for it to complete.

### **Step 4: Build Application AMIs**
-   In the `project-anvil` repo, go to **Actions** -> **"Anvil: Build Golden AMIs"**.
-   Run the workflow, selecting `dev` as the target environment.
-   Upon success, copy the **Git commit hash**.

### **Step 5: Deploy the Application**
-   In the `project-anvil` repo, go to **Actions** -> **"Anvil: Deploy Infrastructure (Interactive)"**.
-   Provide the `target_environment` (`dev`) and the `ami_version` (the commit hash).
-   Run the workflow. Once complete, your `dev` environment is live.

---
## Phase IV: Day-to-Day Operations

After the initial deployment, use these standard workflows to manage the application.

### Workflow A: Patching OS or Deploying Application Code

This workflow is used for routine security patching or deploying new application features (like a new plugin or theme).

1.  **Commit Code (If necessary):** For an application update, a developer merges their feature branch into the `main` branch of the `project-anvil` repository. For a routine OS patch, no code change is needed.

2.  **Build a New AMI:**
    -   An operator triggers the **"Anvil: Build Golden AMIs"** workflow from the Actions tab.
    -   They select the `target_environment` (e.g., `prod`) for which they are building the image.
    -   The pipeline builds the AMI, automatically installs the latest OS patches from the base image, and runs a Trivy scan.
    -   The full vulnerability report is uploaded to the environment-specific S3 bucket (e.g., `acmelabs-vulnerability-reports-prod`).

3.  **Remediate or Deploy:**
    -   **If the build fails** the security scan, follow the remediation process in Appendix B.
    -   **If the build succeeds,** copy the **Git commit hash** from the successful workflow run. This is your new, patched AMI version.
    -   An operator triggers the **"Anvil: Deploy Infrastructure (Interactive)"** workflow with the new AMI version to perform a safe, rolling deployment.

### Workflow B: Making an Operational Change (GitOps)

This workflow is used by SREs to respond to performance issues by changing an operational parameter, such as an instance size.

1.  **Open a Pull Request:** An operator opens a PR in the **`project-anvil-ops`** repository. The change involves editing a single line in an environment's JSON file (e.g., changing `"t3.medium"` to `"t3.large"` in `environments/prod.json`).

2.  **Review and Merge:** The team reviews the PR, considering the cost and performance implications of the change. Upon approval, the PR is merged into the `main` branch.

3.  **Automatic Sync:** The merge automatically triggers the **"Sync Operational Config to AWS SSM"** pipeline. This workflow reads the updated JSON file and updates the corresponding SSM Parameter in AWS, usually within a minute. The "source of truth" in AWS is now updated.

4.  **Trigger a Rolling Restart:** The running EC2 instances are not yet aware of this change. To apply it:
    -   An operator triggers the **"Anvil: Deploy Infrastructure (Interactive)"** workflow for the affected environment.
    -   **Crucially, they use the *currently deployed* AMI version**, not a new one.
    -   Terraform will detect that the `instance_type` specified in the Auto Scaling Group's Launch Template no longer matches the value it reads from the SSM Parameter.
    -   It will plan to update the Launch Template and perform a safe, rolling update of the fleet, replacing the old instances with new ones of the correct size.

---
## Appendix A: Upgrading to a Tiered PagerDuty Configuration

The free tier of PagerDuty is excellent for getting started. When the project budget allows, upgrading to a **PagerDuty Professional** plan is recommended to enable environment-specific services and escalation policies. This reduces alert fatigue and routes issues to the correct teams.

1.  **Create Advanced Schedules and Escalation Policies:** In the PagerDuty UI, create the multi-layered schedules (e.g., `Anvil SRE - Primary Rotation`, `Anvil Developers - Business Hours`) and the `Anvil Tiered Escalation Policy` that uses them.

2.  **Create Environment-Specific Services:** Instead of a single service, create four distinct services in PagerDuty:
    - `Anvil - Production` (assign the full tiered escalation policy)
    - `Anvil - UAT` (assign the full tiered escalation policy)
    - `Anvil - QA` (assign the full tiered escalation policy)
    - `Anvil - Development` (assign a simpler, low-urgency policy)

3.  **Generate a unique CloudWatch Integration URL for each service.**

4.  **Update the corresponding secret** in AWS Secrets Manager with the new, environment-specific URL using the `aws secretsmanager update-secret` command. No code changes are needed in the Terraform project.

---
## Appendix B: Vulnerability Management

This project uses a "Crawl, Walk, Run" approach to DevSecOps.

### Crawl: Security Gate (Implemented)

The build pipeline fails on any `CRITICAL` or `HIGH` severity vulnerability, preventing insecure code from being deployed.

### Walk: Manual Report Analysis (Implemented)

When a build fails, or for routine audits, an engineer can analyze the detailed vulnerability reports.

1.  **Identify the Build:** Check the GitHub Actions logs for the failed build. Note the environment, date, and tier (`web` or `app`).
2.  **Locate the Full Report:** Navigate to the appropriate S3 bucket (e.g., `acmelabs-vulnerability-reports-dev`). Download the corresponding JSON report (e.g., `2025-09-08-dev-web-server-report.json`).
3.  **Remediate:**
    - **OS Package CVE:** In most cases, the vulnerability is in a base OS package like `openssl`. The fix is to wait for the upstream provider (e.g., Ubuntu) to release a patch. Once available, simply re-running the build pipeline will automatically install the patched version.
    - **Application Code CVE:** If the issue is in a plugin or theme, a developer must update the vulnerable dependency in the code, commit the fix, and then a new build can be triggered.
4.  **Deploy:** Once the build succeeds, deploy the new, patched AMI using the standard deployment workflow.

### Run: Automated Security Dashboard (Future Enhancement)

For mature teams needing at-a-glance visibility, the JSON reports in S3 can be used to power a low-cost, serverless security dashboard. This provides trend analysis and a single pane of glass for your security posture.

**Architecture:**
-   Use **AWS Glue** to crawl the S3 report buckets and create a data catalog.
-   Use **Amazon Athena** to run standard SQL queries against the reports.
-   Use **Amazon QuickSight** to connect to Athena and build interactive dashboards, charts, and tables.

