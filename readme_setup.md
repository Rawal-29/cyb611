# 🛡️ Project Phish & Bits: Secure S3 Infrastructure Automation

**Course:** CYB 611 | Fall 2025
**Team:** Phish & Bits
**Repository:** [Rawal-29/cyb611](https://github.com/Rawal-29/cyb611)

---

## 📖 Project Overview
This project implements a **GitOps** workflow to securely deploy AWS S3 buckets. Instead of manually configuring resources in the AWS Console, we use **Terraform** (Infrastructure as Code) and **GitHub Actions** (CI/CD).

This ensures that every infrastructure change is version-controlled, peer-reviewed via Pull Request, and deployed automatically using temporary security credentials (OIDC).

---

## 📂 Project Folder Structure
```text
cyb611/
├── .github/
│   └── workflows/
│       ├── plan.yml          # CI Pipeline: Runs 'terraform plan' on Pull Requests
│       └── apply.yml         # CD Pipeline: Runs 'terraform apply' on Merge to Main
├── secure_bucket.tf          # IaC: Defines the S3 bucket and mandatory security controls
├── versions.tf               # Config: Connects Terraform to AWS and the S3 Remote Backend
└── README.md                 # Documentation: Project setup and usage guide

## 🏗️ Part 1: Account & Tool Prerequisites

Before starting the technical implementation, we set up the necessary accounts and tools.

### 1\. Accounts Created

  * **AWS Account:** Created a standard AWS Free Tier account.
      * *ID used in project:* `151462990345`
      * *Region:* `us-east-2` (Ohio)
  * **GitHub Account:** Created to host the repository `cyb611`.

### 2\. Local Tools Installed

  * **VS Code:** Used as the Integrated Development Environment (IDE).
  * **Git:** Version control tool installed on the local laptop.
  * **AWS CLI:** Command Line Interface installed to manage S3 data uploads.

-----

## ⚙️ Part 2: AWS "Bootstrap" Setup (One-Time)

We manually created two resources in AWS to allow Terraform to store its state remotely and securely.

### Step 1: Create S3 Backend Bucket

  * **Action:** Created a bucket named `cyb611-tf-state-phish-bits`.
  * **Settings:**
      * **Region:** `us-east-2`
      * **Versioning:** `Enabled` (To recover state if corrupted).
      * **Encryption:** `Enabled` (SSE-S3).
      * **Bucket Key:** `Enabled`.

### Step 2: Create DynamoDB Lock Table

  * **Action:** Created a table named `terraform-state-locks`.
  * **Settings:**
      * **Partition Key:** `LockID` (String).
  * **Purpose:** Prevents two team members from trying to deploy changes at the exact same time.

### Step 3: Configure OIDC Authentication

To avoid storing risky AWS Access Keys in GitHub, we configured OpenID Connect (OIDC).

1.  **IAM Identity Provider:** Added `token.actions.githubusercontent.com` to AWS IAM.
2.  **IAM Roles Created:**
      * **`GitHubActions-Plan`**: Read-Only access.
          * *Trust Policy:* Uses `StringLike` to allow **any branch** in the repo to run a Plan.
      * **`GitHubActions-Apply`**: Write/Admin access.
          * *Trust Policy:* Uses `StringEquals` to restrict access strictly to the **main branch**.

-----

## 💻 Part 3: Local Development Setup

How we linked GitHub to VS Code and set up the repository.

### Step 1: Clone the Repository

Open the terminal in VS Code and run:

```bash
git clone [https://github.com/Rawal-29/cyb611.git](https://github.com/Rawal-29/cyb611.git)
cd cyb611
```

### Step 2: Configure AWS CLI

To interact with the buckets for data upload, we configured the local CLI:

```bash
aws configure
# Entered Access Key ID, Secret Key, and Region (us-east-2)
```

-----

## 📄 Part 4: Repository Configuration (The Code)

We created the following files to define our secure infrastructure.

### 1\. Terraform Configuration

  * **`versions.tf`**: Configures the S3 Backend to use the bucket created in Part 2.
  * **`secure_bucket.tf`**: Defines the S3 resource with **mandatory** security controls:
      * [x] Block Public Access (All settings = true).
      * [x] Object Ownership (Bucket Owner Enforced / ACLs Disabled).
      * [x] Encryption (AES-256).
      * [x] Versioning (Enabled).

### 2\. GitHub Workflows (`.github/workflows/`)

  * **`plan.yml`**: Triggered on **Pull Requests**.
      * Connects to AWS using the `GitHubActions-Plan` role.
      * Runs `terraform plan`.
      * Posts the plan results as a comment on the PR.
  * **`apply.yml`**: Triggered on **Push to Main** (Merge).
      * Connects to AWS using the `GitHubActions-Apply` role.
      * Runs `terraform apply -auto-approve` to deploy changes.

-----

## 🚀 Part 5: The Workflow (How We Work)

We follow a strict **Branching Strategy**. Direct pushes to `main` are blocked to prevent accidental misconfigurations.

### Step 1: Create a New Branch

Whenever we want to make a change (e.g., creating a vulnerable bucket), we start a new branch.

```bash
git checkout main      # Ensure we are on the base branch
git pull origin main   # Ensure we have the latest code
git checkout -b feature/add-new-bucket  # Create and switch to new branch
```

### Step 2: Make Changes & Push

After writing code in VS Code:

```bash
git status             # Check which files changed
git add .              # Stage all changes
git commit -m "Description of what I changed"
git push origin feature/add-new-bucket
```

### Step 3: Pull Request (PR)

1.  Go to GitHub.com.
2.  Click **"Compare & pull request"**.
3.  Wait for the **"Terraform Plan on PR"** check to run.
4.  Review the comment posted by the bot to ensure the changes look correct.

### Step 4: Merge & Deploy

1.  Click **"Merge pull request"**.
2.  Go to the **Actions** tab.
3.  Watch the **"Terraform Apply on Merge"** workflow run.
4.  Once green ✅, the resources are live in AWS.

-----

## 🧪 Part 6: Data Population

After the secure bucket was deployed, we uploaded mock PII data to test the environment.

**Command used:**

```bash
aws s3 cp mock_pii.csv s3://cyb611-secure-phish-bits-12345/sensitive-data/mock_pii.csv
```
-----
