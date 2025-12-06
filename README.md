
# 🛡️ S3 Security Sandbox: Automated Compliance & Exploitation

**Course:** CYB 611 | Fall 2025
**Team:** Phish & Bits
**Repository:** [Rawal-29/cyb611](https://github.com/Rawal-29/cyb611)

---

## 📖 Executive Summary
Cloud misconfigurations are the leading cause of data breaches. This project demonstrates the real-world impact of S3 security failures by building a controlled **"Capture the Flag" (CTF)** style environment.

Using **GitOps** and **Infrastructure as Code (IaC)**, we deploy two contrasting environments:
1.  **🛡️ Secure Baseline:** A "Gold Standard" S3 bucket implementing Defense-in-Depth.
2.  **⚠️ Vulnerable Target:** An intentionally compromised bucket simulating "Shadow IT" with 7 specific security flaws.

We then validate these environments using a custom **Serverless Security Scanner** (Blue Team) and an **Automated Exploitation Suite** (Red Team).


-----

## 📂 Project Structure

The repository is organized to separate infrastructure definitions from automation logic.

```text
cyb611/
├── infrastructure/           # 🏗️ Terraform Code (Server-Side)
│   ├── secure_bucket.tf      # Defines the hardened bucket
│   ├── insecure_rawal.tf     # Defines the vulnerable bucket
│   ├── cloudtrail.tf         # Defines auditing/logging
│   ├── app.tf                # Defines Lambda infrastructure
│   ├── versions.tf           # Backend configuration
│   └── README.md             # Tech docs for Infra
│
├── scripts/                  # 🐍 Python Automation (Client-Side)
│   ├── app.py                # Blue Team: Compliance Scanner (Lambda)
│   ├── verify_exploits.py    # Red Team: Exploitation Script (Local)
│   ├── mock_pii.csv          # Dummy data for proof-of-concept
│   └── README.md             # Tech docs for Scripts
│
└── .github/workflows/        # ⚙️ CI/CD Pipelines
```

-----

## 🛡️ vs ⚠️ Environment Comparison

We successfully implemented and tested **7 specific misconfigurations**:

| Security Control | 🛡️ Secure Baseline | ⚠️ Vulnerable Target | Risk / Impact |
| :--- | :--- | :--- | :--- |
| **1. Public Access Block** | ✅ **Enabled** | ❌ **Disabled** | Guardrails removed; bucket accepts public traffic. |
| **2. Bucket Policy** | ✅ **Least Privilege** | ❌ **Wildcard (`*`)** | Explicitly allows `s3:GetObject` to anyone. |
| **3. ACLs** | ✅ **Disabled** | ❌ **Public-Read** | Legacy access control allowing anonymous reads. |
| **4. CORS** | ✅ **Restricted** | ❌ **Wildcard (`*`)** | Allows malicious sites to steal data via browser. |
| **5. Encryption** | ✅ **AES-256** | ❌ **Missing** | Data stored in plain text (Compliance failure). |
| **6. Versioning** | ✅ **Enabled** | ❌ **Suspended** | Data integrity risk (Ransomware/Overwrites). |
| **7. SSL Enforcement** | ✅ **Active** | ❌ **Missing** | Allows interception via insecure HTTP. |

-----

## 🛠️ Tooling & Implementation

### 1\. Infrastructure as Code (Terraform)

All resources are defined in the `infrastructure/` directory.

  * **State Management:** Remote S3 backend with DynamoDB locking prevents conflicts.
  * **Authentication:** GitHub Actions uses **OIDC** (OpenID Connect) to authenticate with AWS, eliminating hardcoded access keys.

### 2\. Automated Security Scanner (`app.py`)

Deployed as an **AWS Lambda Function**, this tool acts as our **Compliance Auditor**.

  * **Function:** Scans buckets against the 7 controls above.
  * **Scoring:** Calculates a **Security Score (0-100)**.
  * **Output:** Returns a JSON report detailing Pass/Fail status and remediation steps.

### 3\. Exploitation Suite (`verify_exploits.py`)

A local Python script acting as the **Attacker**.

  * **Function:** Simulates real-world attacks (e.g., anonymous downloads, CORS hijacking).
  * **Validation:** Verifies that "Secure" buckets actually block attacks (403 Forbidden) and "Vulnerable" buckets leak data (200 OK).

-----

## 🚀 Usage Guide

### Prerequisites

  * AWS Account & CLI configured.
  * Python 3 + `boto3` installed.

### Step 1: Deploy Infrastructure

Push changes to the `infrastructure/` folder. GitHub Actions will automatically plan and apply the changes.

### Step 2: Populate Data

Use the helper script to upload dummy PII data to both environments:

```bash
cd scripts
python app.py
# (Note: Ensure the local version of app.py is configured for data upload, 
# or use: aws s3 cp mock_pii.csv s3://<BUCKET_NAME>/)
```

### Step 3: Run Security Audit

Invoke the Lambda Scanner to get a compliance report:

```bash
# Example: Scan the Vulnerable Bucket
curl "https://<YOUR_LAMBDA_URL>/?bucket=cyb611-insecure-phish-bits-12345"
```

### Step 4: Run Attack Simulation

Verify the vulnerabilities are exploitable:

```bash
cd scripts
python verify_exploits.py
```

-----

## 📊 Results Summary

| Metric | Secure Bucket | Vulnerable Bucket |
| :--- | :--- | :--- |
| **Audit Score** | **100/100 (Grade A)** | **45/100 (Grade F)** |
| **Public Access** | 🔒 Denied | 🔓 Allowed |
| **Data Encryption** | 🔒 Encrypted | 🔓 Plain Text |
| **Forensic Logs** | ✅ Available | ✅ Available |

-----
**Maintained by Team Phish & Bits**