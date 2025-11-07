# Project Anvil: Scalable & Observable WordPress Infrastructure on AWS

![Project Anvil Logo/Banner](https://img.shields.io/badge/Project%20Anvil-IaC%20WordPress-blueviolet?style=for-the-badge&logo=wordpress)
![Terraform](https://img.shields.io/badge/Terraform-v1.3.0+-5C4EE5?style=for-the-badge&logo=terraform)
![AWS](https://img.shields.io/badge/AWS-Cloud-orange?style=for-the-badge&logo=amazon-aws)
![GitHub Actions](https://img.shields.io/badge/CI%2FCD-GitHub%20Actions-2088FF?style=for-the-badge&logo=githubactions)
![WordPress](https://img.shields.io/badge/Application-WordPress-21759B?style=for-the-badge&logo=wordpress)

---

## 🚀 Project Overview

Project Anvil is an infrastructure-as-code (IaC) solution designed to deploy a secure, scalable, and highly observable three-tier WordPress application on Amazon Web Services (AWS). This repository contains all the Terraform, Packer, and CI/CD workflow definitions necessary to build, deploy, and manage your WordPress environments automatically.

This guide provides an end-to-end set of instructions, from initial setup to full deployment, making it easy for junior administrators and new team members to get started.

---

## 💡 Core Architectural Principles

Our infrastructure is built upon the following modern cloud and DevOps principles:

- **Infrastructure as Code (IaC):** 100% of the AWS infrastructure is defined declaratively using Terraform and version-controlled in Git.
- **Immutable Infrastructure:** Servers (EC2 instances) are never modified after deployment. All updates (OS patches, application code) are handled by building new "golden AMIs" (Amazon Machine Images) with Packer and performing safe, rolling deployments.
- **Layered Architecture:** The infrastructure is logically separated into distinct, independently managed layers (Bootstrap, Network, Platform, Applications). Each layer has its own Terraform state and deployment pipeline, enhancing clarity, isolation, and maintainability.
- **GitOps for Operations:** Day-to-day operational changes (like resizing instances or updating configurations) are managed through a version-controlled Git workflow, providing a complete audit trail and a formal review process for every change.
- **Golden AMIs:** Application and web server AMIs are pre-built, security-scanned (Trivy), and hardened before deployment.
- **CI/CD Driven:** All deployments, updates, and AMI builds are automated via GitHub Actions pipelines.
- **Automated Code Quality & Security Gates:** All Terraform workflows (deploy, rotate, and optionally destroy) use automated format checks, linting, static security scanning (tfsec, checkov), and graph visualization for safe, auditable changes.
- **Observability:** Comprehensive monitoring, logging, and alerting are integrated using AWS CloudWatch, Kinesis Firehose, and optional OpenSearch Serverless.
- **Security First:** Strong focus on secrets management (AWS Secrets Manager), least-privilege IAM roles, secure networking (VPC, Security Groups), and Web Application Firewall (WAF).
- **Destructive Operations with Safety:** All destroy workflows require explicit confirmation and generate a visual graph of resources to be destroyed before proceeding.
- **AMI/Snapshot Lifecycle Management:** Scheduled and on-demand reporting and safe deletion of AMIs and EBS snapshots, with “latest” protection and dry-run modes.
- **Environment Parity:** Dedicated, isolated environments (Dev, QA, UAT, Prod) with consistent configurations.

---

## 🗺️ AWS Services Used

This project leverages a wide array of AWS services to deliver a robust WordPress solution:

**Compute & Application:**

- **EC2:** Virtual servers for Web and Application tiers.
- **Auto Scaling Groups (ASG):** Automatically scales and manages EC2 instance fleets.
- **Application Load Balancer (ALB):** Distributes traffic and handles SSL/TLS termination.
- **AWS RDS (MySQL):** Managed relational database service.

**Networking & Content Delivery:**

- **VPC, Subnets, Internet Gateway, NAT Gateway:** Isolated, secure network infrastructure.
- **Route 53:** DNS management and domain routing.
- **CloudFront:** Content Delivery Network (CDN) for performance and security.

**Security & Identity:**

- **AWS IAM:** Roles, policies, and instance profiles for least-privilege access.
- **AWS Secrets Manager:** Secure storage and retrieval of sensitive data (DB passwords, WP salts, PagerDuty URLs).
- **AWS SSM Parameter Store:** Secure storage for application configurations and AMI IDs.
- **AWS WAFv2:** Web Application Firewall for protection against common web exploits.
- **AWS ACM (Public & Private CA):** TLS/SSL certificates for HTTPS (public) and internal mTLS (private CA).

**Monitoring, Logging & Observability:**

- **AWS CloudWatch:** Metrics, logs, alarms, and dashboards.
- **AWS Kinesis Firehose:** Streaming data delivery for log archiving.
- **AWS S3:** Storage for raw logs, packaged application code, vulnerability reports, and Terraform state.
- **AWS OpenSearch Serverless:** (Optional) For centralized log analytics.
- **AWS X-Ray:** (Optional) Application tracing for performance monitoring.
- **AWS RUM:** (Optional) Real User Monitoring for front-end performance.

**Management & Governance:**

- **AWS DynamoDB:** Table for Terraform state locking.
- **AWS Budgets:** Cost monitoring and alerting.
- **AWS FIS:** (Optional) Fault Injection Simulator for chaos engineering experiments.

**Build & Automation:**

- **Packer:** Tool for building golden AMIs.
- **GitHub Actions:** CI/CD platform for automating builds and deployments.
- **Trivy:** Vulnerability scanner integrated into AMI build process.
- **TFLint, tfsec, Checkov, Graphviz:** Open-source tools integrated into all Terraform CI/CD workflows for code quality, security, and visualization.

---

## Phase 0: Initial Account & GitHub Setup (One-Time)

This foundational phase covers the very first, one-time manual steps needed in AWS and GitHub. These steps do not require any local tools to be installed yet.

### 1. AWS Account Setup

1. Sign up at [aws.amazon.com](https://aws.amazon.com/).
2. Enable Multi-Factor Authentication (MFA) for your root account.
3. Record your 12-digit AWS Account ID. You will need this for various configurations.
4. Create an administrative IAM User with programmatic access (Access Key ID and Secret Access Key). This user will be used *temporarily* on your local machine to perform initial setup steps (like creating the OIDC provider and running the IAM Bootstrap Terraform). Ensure this user has permissions to create OIDC providers, IAM roles/policies, S3 buckets, and DynamoDB tables. Later, all CI/CD will use OIDC.

### 2. GitHub Account Setup

1. Sign up at [github.com](https://github.com/).
2. Create a GitHub Organization (e.g., `AcmeLabsCloud`). All your project repositories will reside here.
3. Create two new private repositories within your GitHub Organization:
    - `project-anvil` (This repository, containing all IaC code)
    - `project-anvil-ops` (A separate repository for operational configuration files for GitOps)

### 3. PagerDuty Account Setup (Optional but Recommended)

1. Sign up at [pagerduty.com](https://www.pagerduty.com/) (must use a non-generic address).
2. Create a PagerDuty Service and add an AWS CloudWatch integration.
3. Save the generated Integration URL. You will provide this later as an input to the bootstrap workflow if you wish to pre-populate this secret.

---

## Phase I: Local Workstation & GitHub Tools Setup

This phase guides you through installing and configuring the necessary command-line tools on your local machine. These tools are required to perform the subsequent setup steps.

### 1. Install Local Workstation Tools

Ensure your local development environment has the necessary tools installed:

1. **Install AWS CLI:**
    Follow the official guide to [install the AWS CLI v2](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html).

2. **Install GitHub CLI (`gh`):**
    Follow the official guide to [install `gh`](https://github.github.com/cli/cli#installation).

3. **Install `jq`:**
    This is a command-line JSON processor, essential for script execution.
    - macOS: `brew install jq`
    - Ubuntu/Debian: `sudo apt-get install jq`

4. **Install `openssl`:**
    Required for certificate operations and for retrieving OIDC thumbprints.
    - macOS: `brew install openssl` (or it may be pre-installed)
    - Ubuntu/Debian: `sudo apt-get install openssl` (or it may be pre-installed)

### 2. Configure Local Tools Authentication

Now that the tools are installed, you need to configure them to authenticate with AWS and GitHub.

1. **Configure AWS CLI:**
    Use the administrative IAM User Access Key ID and Secret Access Key you created in Phase 0, Step 1.

    ```bash
    aws configure --profile anvil-admin
    # You will be prompted for:
    # AWS Access Key ID [None]: <YOUR_ACCESS_KEY_ID>
    # AWS Secret Access Key [None]: <YOUR_SECRET_ACCESS_KEY>
    # Default region name [None]: us-east-1  (or your preferred region)
    # Default output format [None]: json
    ```

    **Note:** This profile (`anvil-admin`) provides temporary administrative access for initial setup. All CI/CD operations will later use OIDC for secure, role-based access.

2. **Configure GitHub CLI (`gh`):**
    Authenticate `gh` with your GitHub account. This is needed for creating repositories and setting secrets.

    ```bash
    gh auth login
    ```

    - When prompted, choose **"Paste your authentication token"** and use a **Classic Personal Access Token (PAT)**.
    - **How to generate a PAT:**
        - Go to **GitHub.com > Settings > Developer settings > Personal access tokens > Tokens (classic)**.
        - Click **"Generate new token (classic)"**.
        - **Note:** Give it a descriptive name (e.g., "Project Anvil Setup PAT").
        - **Expiration:** Set an appropriate expiration (e.g., 7 or 30 days, or "No expiration" if this is your primary PAT).
        - **Select scopes:** You will need the following scopes (permissions):
            - `repo` (full control of private and public repositories)
            - `admin:org` (read and write organization and team membership, only if creating repos in an Org)
            - `workflow` (access GitHub Actions workflows)
        - Generate token and **immediately copy the token string**.
        - Paste this token when `gh auth login` prompts you.

---

## Phase II: GitHub Repository Setup & AWS Identity Provider

This phase prepares your GitHub repositories and establishes the trust relationship with AWS, allowing GitHub Actions to securely interact with your AWS account.

### 1. Create and Populate GitHub Repositories

**Set Environment Variables (run this first in your terminal):**

```bash
# Replace <YOUR_GITHUB_ORG_OR_USERNAME> with your actual GitHub Organization name or personal username.
# E.g., export GITHUB_ORG="AcmeLabsCloud"
export GITHUB_ORG="<YOUR_GITHUB_ORG_OR_USERNAME>"
export ANVIL_REPO_NAME="project-anvil"
export OPS_REPO_NAME="project-anvil-ops"
export ANVIL_REPO="$GITHUB_ORG/$ANVIL_REPO_NAME"
export OPS_REPO="$GITHUB_ORG/$OPS_REPO_NAME"
export REVIEWER_USERNAME="<YOUR_GITHUB_USERNAME>" # GitHub user to approve deployments (can be your own username initially)
export AWS_PROFILE="anvil-admin"
export AWS_REGION="us-east-1" # <-- IMPORTANT: Replace with your actual AWS region
export PROJECT_NAME="project-anvil"
export ACCOUNT_ID="<YOUR_AWS_ACCOUNT_ID>" # <-- IMPORTANT: Replace with your actual AWS Account ID
export OIDC_THUMBPRINT="6938fd4d98bab03faadb97b34396831e3780aea1" # This is the current thumbprint for token.actions.githubusercontent.com
```

**Create Repositories on GitHub:**

```bash
# Create the 'project-anvil' and 'project-anvil-ops' repositories as private.
# Note: If your GitHub plan does not support private repos, use --public.
gh repo create $ANVIL_REPO --private --clone
gh repo create $OPS_REPO --private --clone
```

**Populate `project-anvil` (this repo) and Push to GitHub:**

- Copy all files from your Project Anvil course materials (Terraform, Packer, scripts, etc.) into the local `project-anvil` directory that was just created by the `gh repo create` command.
- **Exclude** any `.git` folder from your source materials if you're copying an existing repo's contents, as `gh repo create` already initialized a new `.git` for you.
- Then, from within the local `project-anvil` directory, run these commands:

```bash
cd project-anvil # Ensure you are in the correct directory
git add .
git commit -m "Initial commit of Project Anvil"
git branch -M main # Ensures your primary branch is named 'main'
git push -u origin main
```

Populate ⁠project-anvil-ops with Operational Configs (Later):

- After ⁠project-anvil is pushed, you can proceed to set up ⁠project-anvil-ops in the next phase. For now, it's an empty repo.

### 2. Configure GitHub Repository Settings

This section details how to set up `CODEOWNERS`, branch protection, teams, and environments in GitHub.

**CODEOWNERS** ensures that the right team or person must review and approve changes to specific files or directories.

1. In your repo, you may need to edit the file at `.github/CODEOWNERS`
2. If you edit the file, make sure to commit this file to your repository.

> **Tip:** You must create the corresponding GitHub Teams (see below) and add users to those teams for CODEOWNERS to work. Adjust to fit your organization's team structure.

#### Configure Classic Branch Protection Rules

1. Go to your repository on GitHub.
2. Navigate to **Settings > Branches > Branch protection rules**.
3. Click **Add rule** and enter `main` as the branch name pattern.
4. Set the following options:

    - ✅ Require a pull request before merging
    - ✅ Require approvals
    - ✅ Dismiss stale pull request approvals when new commits are pushed
    - ✅ Require review from Code Owners
    - ✅ Restrict who can dismiss pull request reviews
        — *Set this to yourself (This is OK to start, once you go live, this should be configured properly)*
    - ✅ Allow specified actors to bypass required pull requests
        — *Set this to yourself (This is OK to start, once you go live, this should be configured properly)*
    - ✅ Require approval of the most recent reviewable push
    - ✅ Require status checks to pass before merging
    - ✅ Require branches to be up to date before merging
    - ✅ Require conversation resolution before merging
    - ✅ Require linear history
    - ✅ Do not allow bypassing the above settings

5. Click **Create** or **Save changes**.

#### Create GitHub Teams and Set Access

1. Go to your GitHub organization (e.g., `AcmeLabsCloud`).
2. Click **Teams**.
3. Create teams for each environment:
    - `dev-team`
    - `qa-team`
    - `sre-team`
4. Add members to each team as appropriate.
5. In your repository, go to **Settings > Manage access > Teams** and add each team with the appropriate role (write or maintain access).

#### Configure GitHub Environments and Workflow Deployment Permissions

1. In your repo, go to **Settings > Environments**.
2. Create environments for:
    - `dev`
    - `qa`
    - `uat`
    - `prod`
3. For each environment, set deployment protection rules:
   - Click on the environment name (e.g., `dev`).
   - In **Deployment branches and tags**, click on the dropdown Selected branches and tags:
     - Select **Only allow specific branches** and add `main`.

4. In your workflow YAMLs, ensure the `environment:` property matches the environment name (already present in your templates).

> **Tip:** This ensures that only the right team can approve and execute deployments to their environment.

#### Configure CI/CD Workflows for Team-Based Deployment

- Each deploy workflow (`3-deploy-app-dev.yml`, `4-deploy-app-qa.yml`, etc.) should have the `environment:` field set (which you already do).
- GitHub Environments + Teams + CODEOWNERS + branch protection ensure:
  - Only the right team can run deployments to each environment
  - All changes to critical files require review by the right team(s)
  - No one can merge or deploy to production without SRE approval and passing all checks

---

## Phase III: AWS IAM Bootstrap & GitHub Secrets

This phase establishes the foundational IAM roles in AWS and configures GitHub repository secrets, enabling your GitHub Actions workflows to securely manage your AWS infrastructure.

### What’s Automated in the Bootstrap Workflow

You do NOT need to manually create:

- S3 buckets for Terraform state (any environment)
- DynamoDB tables for state locking
- SSH key pairs or AWS Secrets Manager secrets
- ACM certificates
  
The bootstrap workflow will:

- Create all S3 buckets and DynamoDB tables needed for all layers (⁠network, ⁠platform, ⁠apps)
- Provision foundational IAM roles and policies (except the initial bootstrap role)
- Create SSH key pairs, secrets containers, and base ACM certs for all environments
- Run all code quality and security checks (⁠terraform fmt, ⁠tflint, ⁠tfsec, ⁠checkov)
- Upload artifacts (Terraform graph, scan results)
- Optionally, update the PagerDuty secret in AWS Secrets Manager

#### 1. One-Time: Create GitHub OIDC Provider in AWS

> **Tip:** Do this ONCE per AWS account.

#### 2. Create the ODIC Provider

```bash
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list $OIDC_THUMBPRINT \
  --region $AWS_REGION
```

#### 3. Create the Bootstrap IAM Role

```bash
cat > anvil-bootstrap-trust-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::${ACCOUNT_ID}:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:${GITHUB_ORG}/${ANVIL_REPO_NAME}:*"
        }
      }
    }
  ]
}
EOF
```

#### 4. Create the role

```bash
aws iam create-role \
  --role-name anvil-bootstrap-role \
  --assume-role-policy-document file://anvil-bootstrap-trust-policy.json \
  --region $AWS_REGION
```

#### 5. Attach Admin Policy to the Role

```bash
aws iam attach-role-policy \
  --role-name anvil-bootstrap-role \
  --policy-arn arn:aws:iam::aws:policy/AdministratorAccess \
  --region $AWS_REGION
```

#### 6. Set the Role ARN as a GitHub Secret

```bash
export BOOTSTRAP_ROLE_ARN=$(aws iam get-role --role-name anvil-bootstrap-role --region $AWS_REGION --query 'Role.Arn' --output text)
gh secret set AWS_IAM_ROLE_FOR_BOOTSTRAP -b"$BOOTSTRAP_ROLE_ARN" --repo $ANVIL_REPO
```

---

## Phase IV: End-to-End Deployment Lifecycle

Deployments to QA, UAT, and PROD are typically only possible after an approved and merged Pull Request to `main`, which is enforced by GitHub branch protection and `CODEOWNERS` rules.

The infrastructure is deployed layer-by-layer, respecting dependencies. Always deploy/update layers in this sequence.

> **All deploy and rotate workflows include automated format, lint, security, and policy checks (`terraform fmt`, `tflint`, `tfsec`, `checkov`), and generate a Terraform graph for review. Destroy workflows require explicit confirmation and generate/upload a Terraform graph of resources to be destroyed.**

### Deployment Order (from Foundation to Application)

Each layer is deployed by triggering its dedicated GitHub Actions workflow. Ensure the previous layer is successfully deployed before proceeding to the next.

#### 1. Bootstrap Layer (`bootstrap/`)

- **Purpose:** Provisions foundational resources like S3 buckets for Terraform state, DynamoDB tables for state locking, SSH keys, and base ACM certificates. This layer **creates all S3 buckets and DynamoDB tables for the Network, Platform, and Apps layers**.
- **Workflow:** `.github/workflows/0-deploy-bootstrap.yml`
- **Trigger:** Manual `workflow_dispatch`
- **Action:** Go to your ⁠project-anvil repo on GitHub, navigate to the Actions tab, find "0-Deploy Bootstrap Infra", click "Run workflow".
  - Select `target_environment` (e.g., `dev`).
  - Provide `aws_region` (e.g., `us-east-1`).
  - Optionally provide `pagerduty_url` (the Integration URL saved from Phase 0, Step 3, if you wish to pre-populate this secret).
  - Click "Run workflow".
- **After the workflow completes:**
  - Copy the output ARNs for these roles from the workflow summary:

    - `network_role_arn`
    - `platform_role_arn`
    - `ops_sync_role_arn`
    - `packer_role_arn`

  - Set them as GitHub secrets for your repos:

      ```bash
      gh secret set AWS_IAM_ROLE_FOR_NETWORK -b"<network_role_arn>" --repo $ANVIL_REPO
      gh secret set AWS_IAM_ROLE_FOR_PLATFORM -b"<platform_role_arn>" --repo $ANVIL_REPO
      gh secret set AWS_IAM_ROLE_FOR_OPS_SYNC -b"<ops_sync_role_arn>" --repo $OPS_REPO
      gh secret set AWS_IAM_ROLE_FOR_PACKER -b"<packer_role_arn>" --repo $ANVIL_REPO
      ```

  > **Tip:** You must do this after every time you re-run the bootstrap workflow and new ARNs are created.
  > `AWS_IAM_ROLE_FOR_BOOTSTRAP` must be set **before** running the workflow (see Phase III).
  > The others (`AWS_IAM_ROLE_FOR_PACKER`, `AWS_IAM_ROLE_FOR_ANVIL`, `AWS_IAM_ROLE_FOR_OPS_SYNC`) must be set **after** the workflow completes, using the ARNs output from the workflow.

- **Expected Outcome:** Core state management resources, SSH keys, basic secrets containers, and bootstrap certificates are created for the selected environment. **Crucially, all S3 buckets and DynamoDB tables needed for `network`, `platform`, and `apps` layer states are also created.**

---

#### 2. Network Layer (`network/`)

- **Purpose:** Provisions the core Virtual Private Cloud (VPC), subnets (public, private, DB), Internet Gateway, NAT Gateways, and shared Route 53 DNS records.
- **Workflow:** `.github/workflows/1-deploy-network.yml`
- **Trigger:** Manual `workflow_dispatch`
- **Action:** Go to the **Actions** tab, find **"1-Deploy Network Infra"**, click **"Run workflow"**.
  - Select `target_environment` (e.g., `dev`).
  - Provide `aws_region`.
  - Click "Run workflow".
- **Expected Outcome:** A fully configured and segmented VPC network is established for the selected environment.

---

#### 3. Platform Layer (`platform/`)

- **Purpose:** Provisions shared services like logging (CloudWatch, Kinesis Firehose), monitoring (CloudWatch dashboards), shared S3 buckets, and private/public ACM Certificates used by application tiers. This layer also sets up the necessary SNS topics and subscriptions for **automated PagerDuty integration** using the URL provided during the bootstrap phase.
- **Workflow:** `.github/workflows/2-deploy-platform.yml`
- **Trigger:** Manual `workflow_dispatch`
- **Action:** Go to the **Actions** tab, find **"2-Deploy Platform Infra"**, click **"Run workflow"**.
  - Select `target_environment` (e.g., `dev`).
  - Provide `aws_region`.
  - Click "Run workflow".
- **Expected Outcome:** Environment-wide shared services are available for application layers, including automated PagerDuty alerting.

---

#### 4. Application Layer (`apps/<env>/`)

- **Purpose:** Provisions the application-specific infrastructure for a given environment, including EC2 web/app tiers, RDS database, CloudFront CDN, and WAF.
- **Workflows:**
  - `.github/workflows/3-deploy-app-dev.yml`
  - `.github/workflows/4-deploy-app-qa.yml`
  - `.github/workflows/5-deploy-app-uat.yml`
  - `.github/workflows/6-deploy-app-prod.yml`
- **Trigger:** Manual `workflow_dispatch`
- **Action:** Go to the **Actions** tab, find the appropriate workflow (e.g., **"3-Deploy App Infra (dev)"**), click **"Run workflow"**.
  - Select `ami_version` (Git commit hash of the golden AMI).
  - Provide `aws_region`.
  - Click "Run workflow".
- **Expected Outcome:** The WordPress application is fully deployed and operational for the selected environment.

---

## Phase V: Day-to-Day Operations

After the initial deployment, use these standard workflows to manage the application efficiently.

---

### Workflow A: Building Golden AMIs (`ami-builder` layer)

This workflow builds new immutable AMIs for web and app tiers, integrating security scanning. These AMIs can then be used by application deployment workflows.

1. **Workflow:** `.github/workflows/ami-builder.yml`
2. **Trigger:** Manual `workflow_dispatch`
3. **Action:** Go to the **Actions** tab, find **"AMI Builder"**, click **"Run workflow"**.
    - Select `target_environment` (e.g., `dev`) for which the AMI is primarily intended.
    - Provide `aws_region`.
    - Click "Run workflow".
4. **Expected Outcome:**
    - Application packages are created (`dist/app_package.tar.gz`, `dist/web_package.tar.gz`).
    - Packer builds new AMIs based on the specified tiers (web/app).
    - Trivy vulnerability scanning is performed.
    - Vulnerability reports are uploaded to S3 (e.g., `acmelabs-vulnerability-reports-dev`).
    - New AMI IDs are stored in AWS SSM Parameter Store (e.g., `/anvil/ami/web/<git-commit-hash>`, `/anvil/ami/web/latest-dev`).
    - AMI ID artifacts and Packer build logs are available for download from the GitHub Actions run.
    - **Build scripts include a cleanup step to minimize AMI size and attack surface.**

---

### Workflow B: Patching OS or Deploying Application Code (via AMI updates)

This is the standard procedure for applying OS patches or deploying new application code without modifying running instances.

1. **Build a New AMI:**
    - An operator triggers the **"AMI Builder"** workflow (Phase V, Workflow A).
    - They select the `target_environment` (e.g., `prod`) and `aws_region`.
    - The pipeline builds new AMIs, automatically installing the latest OS patches and baking in new application code (if `create_packages.sh` was updated).
    - The full vulnerability report is uploaded to the environment-specific S3 bucket.
    - If the build fails security checks, remediate as per Appendix B.
    - If the build succeeds, **copy the Git commit hash** from the successful workflow run. This is your new, patched `ami_version`.

2. **Deploy the New AMI:**
    - An operator triggers the appropriate **"Deploy App Infra (`<ENV>`)"** workflow (e.g., `.github/workflows/6-deploy-app-prod.yml`).
    - **Provide the `ami_version` (Git commit hash)** obtained from the AMI build step.
    - Provide `aws_region`.
    - Click "Run workflow".
    - **Expected Outcome:** Terraform detects the `ami_id` change in the Launch Template and performs a safe, rolling update of your application's EC2 fleet to the new golden AMI.

---

### Workflow C: Making an Operational Change (GitOps)

This workflow is used to respond to performance issues or modify operational parameters (e.g., instance size, scaling capacity) using a GitOps approach.

1. **Edit Operational Config:** An operator edits the `apps/<env>/environments/<env>.tfvars` file (e.g., changing `web_max_size` from `10` to `15` in `apps/prod/environments/prod.tfvars`).
2. **Open a Pull Request:** Open a PR targeting `main` with this change.
3. **Review and Merge:** The team reviews the PR. Upon approval, the PR is merged into `main`.
4. **Trigger a Rolling Restart:**
    - An operator triggers the appropriate **"Deploy App Infra (`<ENV>`)"** workflow for the affected environment (e.g., `.github/workflows/6-deploy-app-prod.yml`).
    - **Crucially, they use the *currently deployed* `ami_version`** (e.g., `latest-<env>` or the specific commit hash used last). Terraform will detect that a parameter in the Auto Scaling Group or its Launch Template no longer matches the value it reads from the SSM Parameter.
    - **Expected Outcome:** Terraform plans to update the necessary resources and performs a safe, rolling update of the fleet to apply the new operational parameters.

---

### Workflow D: Updating CloudWatch Agent Configuration

Each environment has its own CloudWatch Agent config file (e.g., `platform/config/cloudwatch-agent-config-dev.json`).

1. **Edit the config file:** Make changes to the relevant JSON file (e.g., `platform/config/cloudwatch-agent-config-dev.json`).
2. **Open a Pull Request:** Open a PR targeting `main` for review.
3. **Review and Merge:** Upon approval, merge the PR into `main`.
4. **Redeploy Platform Layer:** An operator triggers the **"2-Deploy Platform Infra"** workflow for the affected environment (e.g., `.github/workflows/2-deploy-platform.yml`).
5. **Trigger Rolling Restart on Apps:** After the platform layer applies, trigger the appropriate **"Deploy App Infra (`<ENV>`)"** workflow for the affected environment (e.g., `.github/workflows/3-deploy-app-dev.yml`). This will force existing instances to pick up the new SSM parameter value on their next reboot/replacement. New instances will get it automatically.
    - **Expected Outcome:** The CloudWatch Agent configuration is updated in SSM, and instances in the app layer will pick up the new configuration when they next restart or are replaced by the rolling update.

---

### Workflow E: AMI/Snapshot Lifecycle Management

This workflow provides both scheduled and manual reporting of all AMIs and EBS snapshots in your AWS account, and enables safe, auditable deletion of unused images and snapshots.

1. **Workflow:** `.github/workflows/ami-lifecycle-report.yml`
2. **Trigger:** Scheduled nightly at midnight UTC and on manual trigger.
3. **Action:** Go to the **Actions** tab, find **"AMI/Snapshot Lifecycle Report"**, click **"Run workflow"** or view last scheduled run.
    - Download the artifact to see a full table (markdown and CSV) of all AMIs and snapshots, including creation date, tags, and state.
4. **To safely delete AMIs or snapshots:**
    - Review the report, select IDs to delete.
    - Trigger the **"Delete Selected AMIs/Snapshots"** workflow (`.github/workflows/ami-snapshot-delete.yml`) from the Actions tab.
    - Paste the comma-separated list of IDs to delete, select the AWS region, and choose whether to do a dry run or actual deletion.
    - **Protection:** The workflow will never delete an AMI that is currently set as the "latest" for any tier/environment, and will print/report any skipped IDs.
    - **Reporting:** A full report of deleted/skipped resources is uploaded as an artifact and printed in the workflow log.

---

## Phase VI: Cleanup & Destroy Operations

Destroying infrastructure is a highly destructive action and should be performed with extreme caution. **Always destroy layers in reverse order of deployment** to respect dependencies.

> **All destroy workflows generate and upload a Terraform graph PNG of the resources to be destroyed for review before confirmation. Destructive actions require explicit user confirmation and will not proceed without it. Destroy workflows will not run any deletion if confirmation is not provided.**

### Destroy Order (from Application to Foundation)

#### 1. Destroy Application Layer (`apps/<env>/`)

- **Workflows:** `destroy-app-dev.yml`, `destroy-app-qa.yml`, `destroy-app-uat.yml`, `destroy-app-prod.yml`
- **Trigger:** Manual `workflow_dispatch`
- **Action:** Go to the **Actions** tab, find the appropriate destroy workflow (e.g., **"Destroy App Infra (dev)"**), click **"Run workflow"**.
  - Provide `aws_region` (e.g., `us-east-1`).
  - Type `yes` in the `confirm_destroy` input.
  - Click "Run workflow".
- **Expected Outcome:** All application-specific infrastructure for the selected environment (EC2, RDS, CDN, WAF, SGs, IAM) is removed.
- **Safety:** A graph of resources to be destroyed is generated and uploaded as an artifact before destruction.

---

#### 2. Destroy Platform Layer (`platform/`)

- **Workflows:** `.github/workflows/destroy-platform.yml`
- **Trigger:** Manual `workflow_dispatch`
- **Action:** Go to the **Actions** tab, find **"Destroy Platform Infra"**, click **"Run workflow"**.
  - Provide `aws_region`.
  - Type `yes` in the `confirm_destroy` input.
  - Click "Run workflow".
- **Expected Outcome:** Shared platform services (logging, monitoring, shared S3, ACM certs) are removed for the selected environment.
- **Safety:** A graph of resources to be destroyed is generated and uploaded as an artifact before destruction.

---

#### 3. Destroy Network Layer (`network/`)

- **Workflows:** `.github/workflows/destroy-network.yml`
- **Trigger:** Manual `workflow_dispatch`
- **Action:** Go to the **Actions** tab, find **"Destroy Network Infra"**, click **"Run workflow"**.
  - Provide `aws_region`.
  - Type `yes` in the `confirm_destroy` input.
  - Click "Run workflow".
- **Expected Outcome:** The VPC, subnets, NAT Gateways, and associated resources are removed for the selected environment.
- **Safety:** A graph of resources to be destroyed is generated and uploaded as an artifact before destruction.

---

#### 4. Destroy Bootstrap Layer (`bootstrap/`)

- **Workflows:** `.github/workflows/destroy-bootstrap.yml`
- **Trigger:** Manual `workflow_dispatch`
- **Action:** Go to the **Actions** tab, find **"Destroy Bootstrap Infra"**, click **"Run workflow"**.
  - Provide `aws_region`.
  - Type `yes` in the `confirm_destroy` input.
  - Click "Run workflow".
- **Expected Outcome:** Foundational resources (S3 state buckets, DynamoDB lock tables, SSH keys, basic secrets containers) are removed for the selected environment.
- **Note:** S3 buckets and DynamoDB tables configured with `prevent_destroy = true` will require manual deletion.
- **Safety:** A graph of resources to be destroyed is generated and uploaded as an artifact before destruction.

---

## Appendix A: Upgrading to a Tiered PagerDuty Configuration

The free tier of PagerDuty is excellent for getting started. When the project budget allows, upgrading to a **PagerDuty Professional** plan is recommended to enable environment-specific services and escalation policies. This reduces alert fatigue and routes issues to the correct teams.

1. **Create Advanced Schedules and Escalation Policies:** In the PagerDuty UI, create the multi-layered schedules (e.g., `Anvil SRE - Primary Rotation`, `Anvil Developers - Business Hours`) and the `Anvil Tiered Escalation Policy` that uses them.
2. **Create Environment-Specific Services:** Instead of a single service, create four distinct services in PagerDuty:
    - `Anvil - Production` (assign the full tiered escalation policy)
    - `Anvil - UAT` (assign the full tiered escalation policy)
    - `Anvil - QA` (assign the full tiered escalation policy)
    - `Anvil - Development` (assign a simpler, low-urgency policy)
3. **Generate a unique CloudWatch Integration URL for each service.**
4. **Update the corresponding secret** in AWS Secrets Manager with the new, environment-specific URL using the `rotate-or-update.yml` workflow.

---

## Appendix B: Vulnerability Management

This project uses a "Crawl, Walk, Run" approach to DevSecOps.

### Crawl: Security Gate (Implemented)

The AMI build pipeline fails on any `CRITICAL` or `HIGH` severity vulnerability, preventing insecure code from being deployed.

### Walk: Manual Report Analysis (Implemented)

When a build fails, or for routine audits, an engineer can analyze the detailed vulnerability reports.

1. **Identify the Build:** Check the GitHub Actions logs for the failed build. Note the environment, date, and tier (`web` or `app`).
2. **Locate the Full Report:** Navigate to the appropriate S3 bucket (e.g., `acmelabs-vulnerability-reports-dev`). Download the corresponding JSON report (e.g., `2025-09-08-dev-web-server-report.json`).
3. **Remediate:**
    - **OS Package CVE:** In most cases, the vulnerability is in a base OS package like `openssl`. The fix is to wait for the upstream provider (e.g., Ubuntu) to release a patch. Once available, simply re-running the build pipeline will automatically install the patched version.
    - **Application Code CVE:** If the issue is in a plugin or theme, a developer must update the vulnerable dependency in the code, commit the fix, and then a new build can be triggered.
4. **Deploy:** Once the build succeeds, deploy the new, patched AMI using the standard deployment workflow.

### Run: Automated Security Dashboard (Future Enhancement)

For mature teams needing at-a-glance visibility, the JSON reports in S3 can be used to power a low-cost, serverless security dashboard. This provides trend analysis and a single pane of glass for your security posture.

**Architecture:**

- Use **AWS Glue** to crawl the S3 report buckets and create a data catalog.
- Use **Amazon Athena** to run standard SQL queries against the reports.
- Use **Amazon QuickSight** to connect to Athena and build interactive dashboards, charts, and tables.

---

## Appendix C: Code Quality, Security, and Lifecycle Automation

All Terraform-based workflows in Project Anvil use the following open-source tools for automated code and security checks:

- **terraform fmt:** Ensures code is formatted consistently.
- **TFLint:** Lints Terraform code for best practices and errors.
- **tfsec:** Scans Terraform code for security vulnerabilities and misconfigurations.
- **Checkov:** Performs policy-as-code and compliance checks.
- **Graphviz:** Visualizes the Terraform dependency graph for each plan and destroy operation.

**Destroy workflows** always generate a graph of resources to be destroyed and require explicit confirmation before proceeding.

**Rotate/update workflows** (for secrets, keys, etc.) use the same safeguards as deploy workflows.

**All results and graphs are uploaded as artifacts for full traceability.**

---

## Appendix D: AMI/Snapshot Lifecycle Management

- **Reporting:** Nightly and on-demand reports are generated listing all AMIs and EBS snapshots (with creation date, tags, and state) and are uploaded as workflow artifacts.
- **Safe Deletion:** Manual workflow allows you to select AMIs and/or snapshots for deletion, with:
  - **Dry run mode (default):** See what would be deleted before actually deleting.
  - **Protection for "latest" AMIs:** Any AMI set as "latest" for a tier/environment in SSM will not be deleted.
  - **Reporting:** A full report of deleted, skipped, or errored resources is uploaded as a workflow artifact and printed in the workflow log.

---

## 🔗 Quick Reference

- **Deploy/Update Workflows:**
  - `.github/workflows/0-deploy-bootstrap.yml`
  - `.github/workflows/1-deploy-network.yml`
  - `.github/workflows/2-deploy-platform.yml`
  - `.github/workflows/3-deploy-app-dev.yml`
  - `.github/workflows/4-deploy-app-qa.yml`
  - `.github/workflows/5-deploy-app-uat.yml`
  - `.github/workflows/6-deploy-app-prod.yml`

- **AMI Builder:**
  - `.github/workflows/ami-builder.yml`

- **Rotate/Update (Keys, Secrets, PagerDuty):**
  - `.github/workflows/rotate-or-update.yml`

- **Destroy Workflows:**
  - `.github/workflows/destroy-app-dev.yml`
  - `.github/workflows/destroy-app-qa.yml`
  - `.github/workflows/destroy-app-uat.yml`
  - `.github/workflows/destroy-app-prod.yml`
  - `.github/workflows/destroy-platform.yml`
  - `.github/workflows/destroy-network.yml`
  - `.github/workflows/destroy-bootstrap.yml`

- **AMI/Snapshot Lifecycle:**
  - `.github/workflows/ami-lifecycle-report.yml`
  - `.github/workflows/ami-snapshot-delete.yml`

---

## ❓ FAQ

**Q: What happens if I try to delete an AMI that is set as “latest” in SSM?**
A: The workflow will detect this and skip deletion for that AMI, reporting the skip in the results.

**Q: How do I safely clean up old AMIs and snapshots?**
A: Use the nightly or manual AMI/Snapshot Lifecycle Report to review what’s in your account, then use the Delete workflow in dry run mode first. When you’re confident, run with dry run set to false.

**Q: How do I know my Terraform code is secure and compliant?**
A: All deploy, rotate, and (optionally) destroy workflows run `terraform fmt`, `tflint`, `tfsec`, and `checkov` before applying any changes. Destroy workflows also generate a resource graph before proceeding.

**Q: Can I customize the destroy/reporting workflow for more tiers or custom tagging?**
A: Yes! Edit the workflow YAML to add more tiers or custom logic as needed for your organization.

**Q: Where are all build logs, scan results, and reports stored?**
A: All relevant logs, scan results, and reports are uploaded as workflow artifacts and can be downloaded from the Actions run in GitHub.

---

## 📣 Contributions & Support

Pull requests, issues, and suggestions are welcome!
For questions, bug reports, or to propose new automation, open an issue or contact the maintainers.

---
