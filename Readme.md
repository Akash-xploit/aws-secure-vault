## 🔐 Secure File Vault (AWS Cloud Security Project)

A **serverless, secure file storage system** designed with a strong focus on **cloud security, zero-trust architecture, and threat detection**.

---

## 🧠 Architecture Overview

This system allows authenticated users to securely upload, download, and manage files without exposing backend infrastructure.

![[AWS Secure Vault.png]]
### ⚙️ Core Services Used

- Amazon S3 – Secure file storage
- AWS Lambda – Backend logic
- Amazon API Gateway – API layer
- Amazon Cognito – Authentication & authorization
- Amazon DynamoDB – Metadata storage
- Amazon CloudFront + AWS Amplify – Frontend delivery
- AWS KMS – Encryption

---

## 🔄 How It Works (Flow)

1. User accesses the frontend via CloudFront
2. Authenticates using Cognito (JWT-based authentication)
3. Sends request through API Gateway
4. Lambda validates request and uploads files (if file size < 6mb) else generates a **pre-signed URL**
5. User uploads file **directly to S3** using the pre-signed URL
6. File metadata is stored in DynamoDB
7. Files are encrypted using KMS

---

## 🔐 Security Design

### 🛡️ Zero-Trust File Uploads

- Backend never handles file data
- All uploads go directly to S3 via presigned URLs

### 🔒 Encryption

- Server-side encryption using KMS (SSE-KMS)
- Secure key management and access control

### 🔑 Authentication & Authorization

- Cognito-based user authentication
- JWT tokens used for API authorization

### 🚫 Access Control

- S3 bucket configured with:
    - Block Public Access
    - IAM-based access policies

---

## 📡 Monitoring & Threat Detection

Integrated cloud-native security tools:

- AWS CloudTrail – Logs all API activity
- Amazon GuardDuty – Detects anomalies and threats
- AWS Security Hub – Centralized security findings
- Amazon CloudWatch – Metrics and alerts
- Amazon SNS – Real-time alert notifications

---

## 🚀 Key Features

- Secure file upload/download system
- Direct S3 uploads using presigned URLs
- Fully serverless architecture
- End-to-end encryption
- Real-time security monitoring
- Scalable and cost-efficient

---

## 📌 Why This Project Matters

This project demonstrates:

- Real-world **cloud security architecture design**
- Implementation of **zero-trust principles**
- Integration of **AWS-native security services**
- Hands-on experience with **blue-team monitoring and detection**

---

## 🧑‍💻 Future Improvements

- Add AWS WAF for advanced threat protection
- Implement fine-grained access control (per-user file isolation)
- Add malware scanning for uploaded files
- Introduce audit dashboards for security insights