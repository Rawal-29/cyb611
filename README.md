# ☁️ Automated Secure S3 Deployment (GitOps)

This repository demonstrates a fully automated **Infrastructure as Code (IaC)** pipeline. It uses **Terraform** to define AWS infrastructure and **GitHub Actions** to deploy it securely without manual console intervention.

## 🎯 Objective
To create a secure, collaborative workflow where infrastructure changes are:
1.  **Version Controlled:** All changes are tracked in Git.
2.  **Automated:** No manual execution of scripts locally.
3.  **Secure:** Uses temporary credentials (OIDC) instead of long-lived access keys[cite: 230].
4.  **Peer Reviewed:** Changes must pass a `terraform plan` on a Pull Request before deployment.

---

## 🏗️ Architecture Overview

The workflow follows a **GitOps** approach:

1.  **Remote State:** Terraform state is stored in S3 with DynamoDB locking to support team collaboration.
2.  **Authentication:** GitHub Actions authenticates to AWS using **OpenID Connect (OIDC)**, eliminating the need for storing AWS Access Keys in secrets.
3.  **CI/CD Pipeline:**
    * **PR Created:** Triggers `terraform plan` (Read-Only).
    * **PR Merged:** Triggers `terraform apply` (Write/Deploy).

---

## 🛠️ Implementation Steps

Here is the step-by-step process of how this environment was built.

### Phase 1: The "Bootstrap" (Manual AWS Setup)
Before automation can run, the "backend" infrastructure must exist to store the Terraform state file.

* **S3 Bucket Created:** `cyb611-tf-state-phish-bits`
    * *Why:* Stores the `terraform.tfstate` file so the whole team sees the same infrastructure state.
    * *Configuration:* **Versioning enabled** (for recovery) and **Encryption enabled**.
* **DynamoDB Table Created:** `terraform-state-locks`
    * *Why:* Prevents two people (or workflows) from modifying infrastructure at the same time.
    * *Key:* `LockID`.

### Phase 2: Secure Authentication (OIDC)
Instead of creating an IAM User with permanent access keys (which is a security risk)[cite: 229], I configured **OIDC Federation**.

1.  **Identity Provider:** Connected AWS IAM to GitHub (`token.actions.githubusercontent.com`).
2.  **Created IAM Roles:**
    * **`GitHubActions-Plan`**:
        * *Permissions:* Read-only access to S3 and state.
        * *Trust Policy:* Allows **any branch** in this repo to assume the role.
    * **`GitHubActions-Apply`**:
        * *Permissions:* Write access to S3 and state.
        * *Trust Policy:* Strictly limited to the **main branch** only.

### Phase 3: Repository Configuration
I created the following Terraform configurations and GitHub Workflows:

#### 1. Terraform Files
* `versions.tf`: Configures the **S3 Backend** connection.
* `secure_bucket.tf`: Defines the actual resource (S3 Bucket) with mandatory security controls[cite: 206]:
    * ✅ Block Public Access enabled[cite: 216].
    * ✅ Versioning enabled[cite: 245].
    * ✅ Encryption (SSE-S3) enabled[cite: 233].
    * ✅ Bucket Owner Enforced (ACLs disabled)[cite: 210].

#### 2. GitHub Actions (`.github/workflows/`)
* **`plan.yml`**: Runs `terraform plan`.
    * *Trigger:* Pull Requests.
    * *Output:* Posts the plan results as a comment on the PR for review.
* **`apply.yml`**: Runs `terraform apply`.
    * *Trigger:* Push to `main` (Merge).
    * *Action:* Deploys the actual resources to AWS.

---

## 🚀 The Workflow (How to use)

We enforced **Branch Protection Rules** on `main` to ensure this workflow is followed:

1.  **Create a Branch:** Create a new branch (e.g., `feature/add-bucket`).
2.  **Write Code:** Update `.tf` files.
3.  **Push & PR:** Push changes and open a Pull Request.
4.  **Automatic Plan:** GitHub Actions runs `plan.yml`. It comments exactly what will change.
5.  **Review:** If the plan is correct, merge the PR.
6.  **Automatic Deploy:** GitHub Actions runs `apply.yml` and creates/updates the resources in AWS.

---

## 🛡️ Security Decisions

| Decision | Reason |
| :--- | :--- |
| **Remote State (S3)** | Prevents "it works on my machine" issues and enables collaboration. |
| **DynamoDB Locking** | Prevents state corruption from simultaneous deploys. |
| **OIDC Auth** | **Security Best Practice.** Removes the risk of leaking long-lived AWS Access Keys[cite: 229]. |
| **Separate IAM Roles** | **Least Privilege.** The `Plan` role cannot modify infrastructure; only the `Apply` role (running on the protected main branch) can[cite: 224]. |
| **Branch Protection** | Ensures no code is deployed without passing a `terraform plan` check first. |