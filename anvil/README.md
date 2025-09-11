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

1. **AWS Account:** Sign up at [aws.amazon.com](https://aws.amazon.com/). Note your 12-digit AWS Account ID.
2. **GitHub Account:** Sign up at [github.com](https://github.com/).
3. **GitHub Repository Setup Choice:**
    Choose one of the following options based on your GitHub plan and project goals. The `GITHUB_ORG` variable in **Phase II: Repository & AWS Prerequisite Setup (CLI)** will depend on your choice.

    - **Option A: Free GitHub Account for Lab/Learning (Public Repositories)**
        This option allows you to experience all the advanced GitHub features (like branch protection rules and deployment environments) on a **free personal GitHub account** by using **public repositories**. This is ideal for learning and experimentation without any cost.
        - Set the `GITHUB_ORG` variable in **Phase II** to your **personal GitHub username** (e.g., `your-github-username`).
        - **NOTE:** Public repositories are suitable for lab/learning environments. **In real-world production, Infrastructure-as-Code (IaC) should always be in private repositories** due to its sensitive nature.

    - **Option B: Paid GitHub Plan for Real-World Best Practices (Private Repositories)**
        This option enables true real-world best practices by using private repositories with advanced GitHub features (branch protection, deployment environments).
        - This guide assumes you will upgrade your GitHub plan. For a single user, this means subscribing to the **GitHub Team plan (1 seat, paid monthly)** for your organization.
        - You **must create a GitHub Organization** now. Your personal account will automatically be an owner.
            - Go to your [Organizations page on GitHub](https://www.github.com/organizations/new).
            - Choose the **Team** plan (or upgrade from Free).
            - Provide the organization name (e.g., `acme-corp`) and follow the prompts.
        - Set the `GITHUB_ORG` variable in **Phase II** to your **Organization's name** (e.g., `acme-corp`).
4. **PagerDuty Account:** Sign up for the [PagerDuty Free plan](https://www.pagerduty.com/). Go through the UI to create a single Service named `Anvil - All Environments`, add an **AWS CloudWatch** integration, and **save the generated Integration URL in a secure password manager**. You will need it in a later step. Note: You can't use a gmail.com address for PagerDuty, must be a custom domain, so consider using an email address like `yourname@yourcompany.com`. I use [ProtonMail](https://www.protonMail.com) to facilitate this.

### 2. Local Workstation Setup

1. **Install AWS CLI:** Follow the official guide to [install the AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html).
2. **Install GitHub CLI:** Follow the official guide to [install `gh`](https://github.com/cli/cli#installation).
3. **Install `jq`:** This is a command-line JSON processor.
    - macOS: `brew install jq`
    - Ubuntu: `sudo apt-get install jq`
4. **Configure Tools:**
    - Create an IAM User in the AWS Console with an access key for administrative access.
    - Run `aws configure --profile anvil-admin` to set up your credentials.
    - Run `gh auth login` to authenticate with GitHub.
        - When prompted for authentication method, choose **"Paste your authentication token"** and use a **Classic Personal Access Token (PAT)**. This is the most reliable method for the `gh` CLI for initial setup.
            - Go to **GitHub.com > Settings > Developer settings > Personal access tokens > Tokens (classic)**.
            - Click **"Generate new token (classic)"**.
            - **Note:** Give it a descriptive name (e.g., "Project Anvil Setup").
            - **Expiration:** Set an appropriate expiration (e.g., 7 or 30 days).
            - **Select scopes:** You will need the following scopes:
                - `repo` (full control of private and public repositories)
                - `admin:org` (read and write organization and team membership, only if creating repos in an Org)
                - `workflow` (access GitHub Actions workflows)
            - Generate token and **immediately copy the token string**.
            - Paste this token when `gh auth login` prompts you.
        - **Alternatively, you can try "Login with a web browser"** for simplicity, but if you encounter permission errors during repository creation, you may need to use a PAT as described above.
        - *(For future reference: Fine-grained Personal Access Tokens offer more granular control and are recommended for production environments. If you wish to use one, ensure it has `Administration`, `Contents`, `Secrets`, `Environments`, `Actions` and `Workflows` permissions all set to `Read and write`.) I recommend using a PAT Classic Token for initial setup.*

---

## Phase II: Repository & AWS Prerequisite Setup (CLI)

This phase uses CLI commands to configure your repositories and prepare AWS.

### 1. Create and Configure Repositories

```bash
# === Set Environment Variables (run this first) ===
# Set GITHUB_ORG based on your choice in Phase I, Section 3.
# If using Option A (Free/Public): export GITHUB_ORG="your-github-username"
# If using Option B (Paid/Private): export GITHUB_ORG="your-organization-name"
export GITHUB_ORG="acme-corp" # Your GitHub Organization name or personal username
export ANVIL_REPO_NAME="project-anvil"
export OPS_REPO_NAME="project-anvil-ops"
export ANVIL_REPO="$GITHUB_ORG/$ANVIL_REPO_NAME"
export OPS_REPO="$GITHUB_ORG/$OPS_REPO_NAME"
export REVIEWER_USERNAME="<YOUR_GITHUB_USERNAME>" # GitHub user to approve deployments

# 1. Create the 'project-anvil' and 'project-anvil-ops' repositories on GitHub.
#    NOTE: The --public or --private flag used here MUST match your choice in Phase I, Section 3.
#    If you chose Option A (Free/Public) in Phase I, use --public.
#    If you chose Option B (Paid/Private) in Phase I, use --private.
gh repo create $ANVIL_REPO --private --clone
gh repo create $OPS_REPO --private --clone

# Your repositories are now created on GitHub and cloned locally (empty).
# You must now populate 'project-anvil' with its source code and push it.

# 2. Populate 'project-anvil' with its source code and push to GitHub:
#    Copy all files from the Project Anvil course materials (Terraform, Packer, scripts, etc.)
#    into the local 'project-anvil' directory that was just created by the 'gh repo create' command.
#    Then, from within the 'project-anvil' directory, run these commands:
cd project-anvil
git add .
git commit -m "Initial commit of Project Anvil infrastructure"
git branch -M main # Ensures your primary branch is named 'main'
git push -u origin main

# After 'project-anvil' is pushed, you can proceed to create and populate the 'project-anvil-ops'
# repository in the next section (1.1).
```

### 1.1. Populate the GitOps Repository (`project-anvil-ops`)

This second repository holds the operational configuration files. After cloning the empty `project-anvil-ops` repository, create the following files and directories inside it.

1. **Add Configuration Files:**
    - **File: `environments/dev.json`**

        ```json
        {
          "web_instance_type": "t2.micro",
          "app_instance_type": "t2.micro",
          "db_instance_class": "db.t3.micro",
          "web_min_size": 1,
          "web_max_size": 2,
          "web_desired_capacity": 1,
          "app_min_size": 1,
          "app_max_size": 2,
          "app_desired_capacity": 1
        }
        ```

    - **File: `environments/qa.json`**

        ```json
        {
          "web_instance_type": "t3.small",
          "app_instance_type": "t3.small",
          "db_instance_class": "db.t3.micro",
          "web_min_size": 2,
          "web_max_size": 4,
          "web_desired_capacity": 2,
          "app_min_size": 2,
          "app_max_size": 4,
          "app_desired_capacity": 2
        }
        ```

    - **File: `environments/uat.json`**

        ```json
        {
          "web_instance_type": "t3.small",
          "app_instance_type": "t3.medium",
          "db_instance_class": "db.t3.small",
          "web_min_size": 2,
          "web_max_size": 4,
          "web_desired_capacity": 2,
          "app_min_size": 2,
          "app_max_size": 4,
          "app_desired_capacity": 2
        }
        ```

    - **File: `environments/prod.json`**

        ```json
        {
          "web_instance_type": "t3.medium",
          "app_instance_type": "t3.large",
          "db_instance_class": "db.t3.medium",
          "web_min_size": 2,
          "web_max_size": 10,
          "web_desired_capacity": 3,
          "app_min_size": 3,
          "app_max_size": 10,
          "app_desired_capacity": 3
        }
        ```

2. **Add the GitOps Pipeline File:**

    - **File: `.github/workflows/sync-ops-config.yml`**

        ```yaml
        name: 'Sync Operational Config to AWS SSM'
        on:
          push:
            branches: [main]
            paths: ['environments/**']
        permissions:
          id-token: write
          contents: read
        jobs:
          sync-to-ssm:
            name: 'Sync to SSM'
            runs-on: ubuntu-latest
            steps:
              - name: 'Checkout Code'
                uses: actions/checkout@v4
              - name: 'Configure AWS Credentials'
                uses: aws-actions/configure-aws-credentials@v4
                with:
                  role-to-assume: ${{ secrets.AWS_IAM_ROLE_FOR_OPS_SYNC }}
                  aws-region: us-east-1
              - name: 'Find Changed Files'
                id: changed_files
                uses: tj-actions/changed-files@v41
                with:
                  files: environments/*.json
              - name: 'Sync Changed Configs to SSM'
                if: steps.changed_files.outputs.any_changed == 'true'
                run: |
                  for file in ${{ steps.changed_files.outputs.all_changed_files }}; do
                    ENV=$(basename "$file" .json)
                    echo "--- Syncing configuration for $ENV environment ---"
                    jq -r 'to_entries|map("/anvil/\(env.ENV)/\(.key) \(.value)")|.[]' "$file" | \
                    while read -r param_name param_value; do
                      echo "Updating SSM parameter: $param_name"
                      aws ssm put-parameter --name "$param_name" --value "$param_value" --type "String" --overwrite
                    done
                    echo "Successfully synced all parameters for $ENV."
                  done
        ```

3. **Commit and Push:** After creating the `environments` and `.github` directories/files as described above, run the following commands from within your `project-anvil-ops` directory to commit and push them to the `main` branch of your `project-anvil-ops` repository.

    ```bash
    # Ensure you are in the 'project-anvil-ops' directory
    # cd project-anvil-ops # Use this if you are not already in the directory
    git add environments/ .github/
    git commit -m "Initial commit of Project Anvil operational configs and sync workflow"
    git branch -M main # Ensures your primary branch is named 'main'
    git push -u origin main
    ```

#### 1.2. Configure Branch Protections

Branch protection rules and GitHub Deployment Environments are advanced features that enhance security and control within your Git workflow. While these can be configured via `gh cli`, some environments may experience issues. Therefore, we provide manual configuration steps via the GitHub UI.

During the initial setup as a solo maintainer, the branch protection rule allows `@your-github-username` to bypass required pull requests. This is to streamline bootstrapping and avoid “chicken-and-egg” issues with CODEOWNERS and branch protection. When additional maintainers join, remove yourself from the bypass list to enforce proper review gates.

1. **Configure `project-anvil` Branch Protection:**
    - Go to your `project-anvil` repository on GitHub.com (`https://github.com/<YOUR_GITHUB_ORG_OR_USERNAME>/project-anvil`).
    - Click on **"Settings"** (usually located near the top right, under the repository name).
    - In the left sidebar, click on **"Branches"**.
    - Under "Branch protection rules," click the **"Add rule"** button.
    - **For "Branch name pattern," type `main`**.
    - **Enable the following settings by checking their boxes:**
        - **`Require a pull request before merging`**:
            - `Require approvals`: Set to **`1`**.
            - `Dismiss stale pull request approvals when new commits are pushed`: Check this.
            - `Require review from Code Owners`: Check this.
              - Set your GitHub username or team name explicitly (e.g., `@github-username-or-teamname`).
            - `Restrict who can dismiss pull request reviews`: Check this.
            - `Allow specified actors to bypass required pull requests`: Check this.
              - Set your GitHub username or team name explicitly (e.g., `@github-username-or-teamname`).
            - `Require approval of the most recent reviewable push`: Check this.
        - **`Require status checks to pass before merging`**:
            - `Require branches to be up to date before merging`: Check this.
        - `Require conversation resolution before merging`: Check this.
        - `Require linear history`: Check this.
        - **`Do not allow bypassing the above settings`**: Check this.
    - Click **"Create"** or **"Save changes"** at the bottom.

2. **Configure `project-anvil-ops` Branch Protection:**
    - Go to your `project-anvil-ops` repository on GitHub.com (`https://github.com/<YOUR_GITHUB_ORG_OR_USERNAME>/project-anvil-ops`).
    - Click on **"Settings"** (usually located near the top right, under the repository name).
    - In the left sidebar, click on **"Branches"**.
    - Under "Branch protection rules," click the **"Add rule"** button.
    - **For "Branch name pattern," type `main`**.
    - **Enable the following settings by checking their boxes:**
        - **`Require a pull request before merging`**:
            - `Require approvals`: Set to **`1`**.
            - `Dismiss stale pull request approvals when new commits are pushed`: Check this.
            - `Require review from Code Owners`: Check this.
            - `Restrict who can dismiss pull request reviews`: Check this.
            - `Allow specified actors to bypass required pull requests`: Check this.
            - `Require approval of the most recent reviewable push`: Check this.
        - **`Require status checks to pass before merging`**:
            - `Require branches to be up to date before merging`: Check this.
        - `Require conversation resolution before merging`: Check this.
        - `Require linear history`: Check this.
        - **`Do not allow bypassing the above settings`**: Check this.
    - Click **"Create"** or **"Save changes"** at the bottom.

3. **Configure Environment Protection for `project-anvil`:**
    - Go to your `project-anvil` repository on GitHub.com (`https://github.com/<YOUR_GITHUB_ORG_OR_USERNAME>/project-anvil`).
    - Click on **"Settings"** (usually located near the top right, under the repository name).
    - In the left sidebar, click on **"Environments"**.
    - For each environment (`prod`, `uat`, `qa`), click on the environment name.
    - **Configure the following settings:**
        - **"Deployment branches and tags"**:
            - From the dropdown list, choose **"Selected branches and tags"**.
            - Under "Add deployment branch or tag rule," specify which branches or tags are allowed to deploy to this environment:
                - **For `prod`**: Add `main`.
                - **For `uat`/`qa`**: Add `main` (or specific feature branches if desired for testing).
        - *(Note: "Required reviewers" and "Wait timers" for environments are only available with an enterprise plan.)*
    - Click **"Save environment"** at the bottom.

**Deployments to QA, UAT, and PROD are only possible after an approved and merged PR to `main`, which is enforced by GitHub branch protection and CODEOWNERS.**

---

### **1.3. Implementing Code Owners for Required Reviews**

The Branch Protection Rules above enable **"Require review from Code Owners"**. To make this work, you need a `CODEOWNERS` file in your repository. This file specifies individuals or teams responsible for reviewing code in specific parts of your codebase. When a pull request modifies code owned by a designated owner, that owner's review is automatically requested and required before the PR can be merged.

1. **Create a `CODEOWNERS` file:**
    - In your `project-anvil` repository, create a file named `CODEOWNERS` in the root directory, or within a `.github/` or `docs/` subdirectory (e.g., `.github/CODEOWNERS`).
    - **Example `.github/CODEOWNERS` content for `project-anvil`:**

        ```bash
        # Require @YOUR_GITHUB_USERNAME to review all infrastructure changes
        * @<YOUR_GITHUB_USERNAME>

        ```

        *Replace `<YOUR_GITHUB_USERNAME>` with your actual GitHub username (e.g., `github-username-or-teamname`). If you have a team, you can use `@your-org/team-slug` format.*

2. **Add the `CODEOWNERS` file via Pull Request:**
    - Create a new branch (e.g., `add-codeowners`).
    - Add the `CODEOWNERS` file to your repository in this branch.
    - Commit your changes.
    - Push your branch to GitHub.
    - Open a pull request targeting `main`.
    - After review and approval, merge the PR into `main`.

Once this file is in place and the branch protection rule "Require review from Code Owners" is enabled, any pull request affecting the specified code will automatically require a review from the listed Code Owners. This serves as your manual approval gate for code changes, including those that initiate deployments.

### 2. Create AWS OIDC Roles and GitHub Secrets

Before creating IAM roles for GitHub Actions, you must create an OpenID Connect (OIDC) provider in your AWS account. This allows GitHub Actions to authenticate securely to AWS.

```bash
# Create OIDC Provider
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list ffffffffffffffffffffffffffffffffffffffff \
  --profile anvil-admin

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

aws iam attach-role-policy --role-name anvil-bootstrap-role \
  --policy-arn arn:aws:iam::aws:policy/AdministratorAccess \
  --profile anvil-admin

aws iam attach-role-policy --role-name anvil-packer-builder-role \
  --policy-arn arn:aws:iam::aws:policy/AmazonSSMFullAccess \
  --profile anvil-admin

aws iam attach-role-policy --role-name anvil-packer-builder-role \
  --policy-arn arn:aws:iam::aws:policy/AmazonEC2FullAccess \
  --profile anvil-admin

cat > passrole-policy.json << EOL
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "iam:PassRole",
      "Resource": "*"
    }
  ]
}
EOL

aws iam put-role-policy --role-name anvil-packer-builder-role \
  --policy-name AllowPassRole \
  --policy-document file://passrole-policy.json \
  --profile anvil-admin

aws iam attach-role-policy --role-name anvil-terraform-deploy-role \
  --policy-arn arn:aws:iam::aws:policy/AdministratorAccess \
  --profile anvil-admin

aws iam attach-role-policy --role-name anvil-ops-sync-role \
  --policy-arn arn:aws:iam::aws:policy/AmazonSSMFullAccess \
  --profile anvil-admin

# === Create GitHub Secrets ===
BOOTSTRAP_ARN=$(aws iam get-role --role-name anvil-bootstrap-role --query 'Role.Arn' --output text --profile anvil-admin)
PACKER_ARN=$(aws iam get-role --role-name anvil-packer-builder-role --query 'Role.Arn' --output text --profile anvil-admin)
TERRAFORM_ARN=$(aws iam get-role --role-name anvil-terraform-deploy-role --query 'Role.Arn' --output text --profile anvil-admin)
OPS_SYNC_ARN=$(aws iam get-role --role-name anvil-ops-sync-role --query 'Role.Arn' --output text --profile anvil-admin)

gh secret set AWS_IAM_ROLE_FOR_BOOTSTRAP -b"$BOOTSTRAP_ARN" --repo $ANVIL_REPO
gh secret set AWS_IAM_ROLE_FOR_PACKER -b"$PACKER_ARN" --repo $ANVIL_REPO
gh secret set AWS_IAM_ROLE_FOR_ANVIL -b"$TERRAFORM_ARN" --repo $ANVIL_REPO
gh secret set AWS_IAM_ROLE_FOR_OPS_SYNC -b"$OPS_SYNC_ARN" --repo $OPS_REPO
# These secrets are then referenced by the GitHub Actions workflows to assume the respective IAM roles.
```

---

## Phase III: The End-to-End Deployment Lifecycle

**Deployments to QA, UAT, and PROD are only possible after an approved and merged PR to `main`, which is enforced by GitHub branch protection and CODEOWNERS.**

Follow this exact sequence to bring an environment online from scratch.

### **Step 1: Run the Bootstrap Pipeline**

This prepares the AWS account with foundational resources, including per-environment S3 buckets for Terraform state and **dedicated DynamoDB tables for state locking.**

- In the `project-anvil` repo, go to **Actions** -> **"Anvil: Bootstrap Foundational Infrastructure"**.
- Run the workflow. Download and save the `ssh-private-keys.zip` artifact securely.

### **Step 2: Populate Manual Secrets**

This is a critical security step to ensure sensitive URLs are never committed to Git.

- In the PagerDuty UI, get the single integration URL you created in Phase I.
- Run the following CLI command for each environment, replacing `<PAGERDUTY_URL>`:

    ```bash
    export PAGERDUTY_URL="<YOUR_SINGLE_PAGERDUTY_URL_FROM_PHASE_I>"
    
    aws secretsmanager update-secret --secret-id acmelabs-website-dev-pagerduty-url --secret-string "$PAGERDUTY_URL" --profile anvil-admin
    aws secretsmanager update-secret --secret-id acmelabs-website-qa-pagerduty-url --secret-string "$PAGERDUTY_URL" --profile anvil-admin
    aws secretsmanager update-secret --secret-id acmelabs-website-uat-pagerduty-url --secret-string "$PAGERDUTY_URL" --profile anvil-admin
    aws secretsmanager update-secret --secret-id acmelabs-website-prod-pagerduty-url --secret-string "$PAGERDUTY_URL" --profile anvil-admin
    ```

### **Step 3: Sync Operational Configuration**

This creates the initial SSM Parameters that define your instance and fleet sizes.

- Go to your `project-anvil-ops` repository **Actions** tab.
- Manually trigger the **"Sync Operational Config to AWS SSM"** workflow. Wait for it to complete.

### **Step 4: Build Application AMIs**

- In the `project-anvil` repo, go to **Actions** -> **"Anvil: Build Golden AMIs"**.
- Run the workflow, selecting `dev` as the target environment.
- Upon success, copy the **Git commit hash**.

### **Step 5: Deploy the Application**

- In the `project-anvil` repo, go to **Actions** -> **"Anvil: Deploy Infrastructure (Interactive)"**.
- Provide the `target_environment` (`dev`) and the `ami_version` (the commit hash).
- Run the workflow. Once complete, your `dev` environment is live.

---

## Phase IV: Day-to-Day Operations

After the initial deployment, use these standard workflows to manage the application.

### Workflow A: Patching OS or Deploying Application Code

1. **Commit Code (If necessary):** For an application update, a developer merges their feature branch into the `main` branch of the `project-anvil` repository. For a routine OS patch, no code change is needed.

2. **Build a New AMI:**
    - An operator triggers the **"Anvil: Build Golden AMIs"** workflow from the Actions tab.
    - They select the `target_environment` (e.g., `prod`) for which they are building the image.
    - The pipeline builds the AMI, automatically installs the latest OS patches from the base image, and runs a Trivy scan.
    - The full vulnerability report is uploaded to the environment-specific S3 bucket (e.g., `acmelabs-vulnerability-reports-prod`).

3. **Remediate or Deploy:**
    - **If the build fails** the security scan, follow the remediation process in Appendix B.
    - **If the build succeeds,** copy the **Git commit hash** from the successful workflow run. This is your new, patched AMI version.
    - An operator triggers the **"Anvil: Deploy Infrastructure (Interactive)"** workflow with the new AMI version to perform a safe, rolling deployment.

### Workflow B: Making an Operational Change (GitOps)

This workflow is used by SREs to respond to performance issues by changing an operational parameter, such as an instance size or fleet capacity.

1. **Open a Pull Request:** An operator opens a PR in the **`project-anvil-ops`** repository. The change involves editing a value in an environment's JSON file (e.g., changing `web_max_size` from `10` to `15` in `environments/prod.json`).

2. **Review and Merge:** The team reviews the PR, considering the cost and performance implications of the change. Upon approval, the PR is merged into the `main` branch.

3. **Automatic Sync:** The merge automatically triggers the **"Sync Operational Config to AWS SSM"** pipeline. This workflow reads the updated JSON file and updates the corresponding SSM Parameter in AWS, usually within a minute. The "source of truth" in AWS is now updated.

4. **Trigger a Rolling Restart:** The running EC2 instances are not yet aware of this change. To apply it:
    - An operator triggers the **"Anvil: Deploy Infrastructure (Interactive)"** workflow for the affected environment.
    - **Crucially, they use the *currently deployed* AMI version**, not a new one.
    - Terraform will detect that a parameter in the Auto Scaling Group (e.g., `max_size`) or its Launch Template (e.g., `instance_type`) no longer matches the value it reads from the SSM Parameter.
    - It will plan to update the necessary resources and perform a safe, rolling update of the fleet.

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

4. **Update the corresponding secret** in AWS Secrets Manager with the new, environment-specific URL using the `aws secretsmanager update-secret` command. No code changes are needed in the Terraform project.

---

## Appendix B: Vulnerability Management

This project uses a "Crawl, Walk, Run" approach to DevSecOps.

### Crawl: Security Gate (Implemented)

The build pipeline fails on any `CRITICAL` or `HIGH` severity vulnerability, preventing insecure code from being deployed.

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
