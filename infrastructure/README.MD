# 🏗️ Infrastructure as Code

This directory contains the Terraform configurations that define our AWS cloud environment.

## 🏛️ Resources We Deploy

We are deploying two parallel storage environments, logging infrastructure, and scanner permissions.

### 1. 🛡️ The Secure Baseline
**Defined in:** `secure_bucket.tf`
**Goal:** To demonstrate a compliant,c "Gold Standard" storage configuration.
* **Block Public Access:** `Enabled`. Prevents any public internet access.
* **Encryption:** `AES-256`. Protects data at rest via Server-Side Encryption (SSE-S3).
* **Versioning:** `Enabled`. Protects against accidental deletion and ransomware.
* **HTTPS Enforcement:** `Enabled`. Bucket policy explicitly denies HTTP (port 80) requests.
* **Logging:** `Enabled`. Access logs are sent to a separate restricted bucket.

### 2. ⚠️ The Vulnerable Target (Phase 2)
**Defined in:** `insecure_rawal.tf`
**Goal:** To simulate a compromised resource. We intentionally implemented **6 specific misconfigurations**:
1.  ❌ **Public Access Blocks Disabled:** All 4 "guardrails" (Block Public ACLs, Block Public Policy, etc.) are turned off.
2.  ❌ **Public ACLs Enabled:** Access Control List is set to `public-read`.
3.  ❌ **Encryption Disabled:** Data is stored in plain text (no SSE-S3 or KMS).
4.  ❌ **Versioning Suspended:** Data integrity is at risk; overwritten files cannot be recovered.
5.  ❌ **Insecure CORS:** Cross-Origin Resource Sharing allows wildcards (`*`), enabling Cross-Site Scripting (XSS) attacks.
6.  ❌ **Public Bucket Policy:** Explicitly grants `s3:GetObject` permission to Principal `*` (Anyone on the internet).

### 3. 🤖 Automated Security Scanner Infrastructure
**Defined in:** `app.tf`
**Goal:** Provisions the AWS permissions required for our Python audit script.
* **Resources:** Creates IAM Roles and Policies.
* **Permissions:** Grants read-only access to `s3:GetBucketPolicy`, `s3:GetEncryptionConfiguration`, and `s3:GetBucketVersioning` so the script can generate reports.

### 4. 📝 Auditing & Forensics
**Defined in:** `cloudtrail.tf`
**Goal:** To enable forensic investigation of attacks.
* **CloudTrail:** Logs all management events (e.g., who changed a bucket policy).
* **Log Bucket:** A separate, restricted bucket that stores S3 server access logs.

---

## ⚙️ How We Deploy (GitOps Workflow)

We do not run Terraform commands locally. We use a **CI/CD Pipeline** powered by GitHub Actions:

1.  **Pull Request (The Plan):**
    * Developer pushes code to a feature branch.
    * GitHub Actions triggers `terraform plan`.
    * A bot posts the plan summary to the PR for peer review.
2.  **Merge to Main (The Apply):**
    * Upon merge, GitHub Actions triggers `terraform apply`.
    * Authenticates via **OIDC** (OpenID Connect) to avoid storing long-term keys.
    * Deploys changes to `us-east-2`.

### Prerequisites
* **State Management:** Remote state stored in S3 (`cyb611-tf-state-phish-bits`).
* **Locking:** DynamoDB table (`terraform-state-locks`) prevents concurrent deployment conflicts.