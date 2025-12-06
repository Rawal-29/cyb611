# Serverless Security Functions

This directory contains the source code for our two AWS Lambda functions. Both scripts are deployed automatically by Terraform.

## 📂 Function Overview

| Script | Role | Type | Deployment | Description |
| :--- | :--- | :--- | :--- | :--- |
| **`app.py`** | 🔵 **Auditor** | Compliance | AWS Lambda | Scans **configurations** (ACLs, Policies) and assigns a Security Score (0-100). |
| **`verify_exploits.py`** | 🔴 **Attacker** | Penetration | AWS Lambda | Executes **real exploits** (HTTP Downloads, CORS) to prove vulnerabilities. |

---

## 1. 🔵 The Auditor (`app.py`)

A **White Box** scanner that inspects AWS settings via the API.

### 📡 Usage (Curl)
Use the **Scanner Function URL** from your Terraform outputs.

* **Scan Everything (Dashboard):**
    ```bash
    curl "https://<SCANNER_URL>/"
    ```
* **Deep Dive Single Bucket:**
    ```bash
    curl "https://<SCANNER_URL>/?bucket=cyb611-insecure-phish-bits-12345"
    ```

### 🔍 Checks Performed
1. Public Access Block Status
2. Encryption Configuration
3. Policy Wildcards
4. SSL Enforcement
5. Versioning Status
6. CORS Wildcards
7. Logging Status

---

## 2. 🔴 The Attacker (`verify_exploits.py`)

A **Black Box** attacker that simulates a hacker on the open internet. It does not check if a setting is "On"; it checks if the exploit **works**.

### 📡 Usage (Curl)
Use the **Attacker Function URL** from your Terraform outputs.

* **Attack Everything:**
    ```bash
    curl "https://<ATTACKER_URL>/"
    ```
* **Attack Single Target:**
    ```bash
    curl "https://<ATTACKER_URL>/?bucket=cyb611-insecure-phish-bits-12345"
    ```

### 🧪 Attacks Simulated
1.  **Data Exfiltration:** Attempts to download `mock_pii.csv` via public HTTP.
    * *Result:* `SUCCESS` (Vulnerable) vs `BLOCKED` (Secure).
2.  **CORS Hijacking:** Sends malicious `Origin: evil.com` headers.
3.  **SSL Stripping:** Forces connection via insecure `http://`.
4.  **Plain Text Check:** Checks object metadata for encryption headers.
5.  **Ransomware Sim:** Checks if versioning allows data recovery.

### 📄 Sample JSON Output
```json
{
    "cyb611-insecure-phish-bits-12345": {
        "1. Data Exfiltration": "SUCCESS (Vulnerable)",
        "2. CORS Exploitation": "SUCCESS (Vulnerable)",
        "3. SSL Strip": "SUCCESS (Vulnerable)"
    },
    "cyb611-secure-phish-bits-12345": {
        "1. Data Exfiltration": "BLOCKED (Secure)",
        "2. CORS Exploitation": "BLOCKED (Secure)",
        "3. SSL Strip": "BLOCKED (Secure)"
    }
}