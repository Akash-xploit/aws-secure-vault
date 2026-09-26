# Threat Model: AWS Secure Vault (v1.0)

How I made this: I listed what's valuable, listed every way into the vault,
and asked the 6 STRIDE questions at each one.

## 1. What's in scope
The v1.0 covers CloudFront, Cognito, API Gateway, Terraform State, KMS, DynamoDB Tables, Lambda Functions, S3, Github Pipeline, CloudTrail and CloudWatch. This doesn't cover AWS's own data centers, the user's computer and the multi-user file sharing feature.

## 2. What's valuable (assets)
| Asset | Where it lives | Why an attacker wants it |
|---|---|---|
| User Files | S3 Bucket | It contains all files of the Users |
| File Catalog  | DynamoDB Table | Attacker can use this to change the ownerID |
| KMS Key    | KMS | This can be used to decrypt the files also deleting or disabling can make every file unreadable |
| Logs       | S3 Bucket | The attacker wants to delete or change the logs to hide what they did |
| User Accounts | Cognito user pool | Take over and account and grab the user's files |
| Login Tokens | issued by Cognito, stored in user's browser | Act as user for 15 min without knowing their password |
| Lambda functions and their IAM roles | Lambda | Attacker can trick Lambda and get whatever its IAM role allows |
| Terraform State File | S3 State Bucket | It maps every resource and can contain sensitive value and if made any changes can lead to deletion or rebuilding of real resources |
| Deploy Pipeline | GitHub Actions | Whoever controls it can change whole AWS account |

## 3. The doors (trust boundaries)
| # | Door | What crosses it |
|---|---|---|
| Door 1 | Loading the Website | The browser downloads the web page from CloudFront |
| Door 2 | Logging in | The browser sends email + password to Cognito and gets a login token back |
| Door 3 | Calling the API | The browser sends a request plus the login token to API Gateway |
| Door 4 | API runs a Lambda | API Gateway passes the checked request to a Lambda |
| Door 5 | Lambda uses the data | A Lambda reads or writes S3, DynamoDB and the KMS key |
| Door 6 | Upload link | The browser sends a file straight to S3 with a pre-signed POST |
| Door 7 | Download link | The browser downloads a file straight from S3 |
| Door 8 | Deploy pipeline | GitHub Actions logs in to AWS and runs Terraform |
| Door 9 | Me, the admin | I use AWS from my laptop and the console |


## 4. Threats
| ID | Door | What could go wrong | How bad? | Fix | How to prove it | Done yet? |
|---|---|---|---|---|---|---|
| T3 | Door 1 | An attacker on the same network changes the web page on its way to the user so it sends their password to the attacker | High | CloudFront HTTPS only + HSTS header | | Planned (Day 4) |
| T4 | Door 1 | An attacker who gets write access to the website bucket replaces the JavaScript so every user's login is stolen | High | Private website bucket, only CloudFront can read (OAC), only the pipeline role can write; CloudTrail records changes | | Planned (Day 4-5) |
| I1 | Door 1 | Someone reads the website files straight from S3 instead of through CloudFront | Low | Private bucket + OAC; the files are public code anyway | | Planned (Day 4) |
| S2 | Door 2 | An attacker guesses common passwords, or uses a tool like Hydra to try thousands of passwords on a user's account | High | 12-character password policy with all 4 character types; Cognito temporarily locks sign-in after repeated failures | | Built (Day 1) |
| S3 | Door 2 | An attacker tries emails and passwords leaked from another site (credential stuffing) | High | Optional TOTP MFA | | Built (Day 1), see accepted risks |
| I2 | Door 2 | An attacker uses "forgot password" or sign-up replies to find out which emails have accounts (user enumeration) | Medium | Cognito user-existence errors hidden | | Built (Day 1) |
| S4 | Door 2 | Malware steals a user's login tokens from their browser and acts as that user | High | 15-minute access tokens, 7-day refresh token, revocation on sign-out; CSP header (Day 4) | | Built (Day 1) |
| S5 | Door 3 | Someone calls the API directly with no token, a fake token or an expired token | High | Cognito authorizer on every route returns 401 before any Lambda runs | | Planned (Day 3) |
| D2 | Door 3 | An attacker floods the API with requests, slowing it down and running up the bill | Medium | API Gateway throttling; authorizer rejects early; Shield Standard; CloudWatch alarm on error spikes (Day 5); budget alert | | Planned (Day 3) |
| R2 | Door 3 | Someone abuses the API and there's no record of who sent which requests | Medium | API Gateway access logs (user ID, IP, route, time) (Day 3); CloudTrail into a locked bucket (Day 5) | | Planned (Day 3) |
| S1 | Door 6 | A stranger uploads straight to the bucket without a link | High | Bucket is private; block public access is on | Upload with no credentials -> AccessDenied | Built (Day 1) |
| T1 | Door 6 | A user edits the file path in the link to overwrite another user's file | High | requestUpload locks the path userId/fileId into the link; userId comes from the login token | Change the path in the curl upload -> 403 | Planned (Day 2) |
| T2 | Door 6 | A user asks S3 to encrypt the file with a different KMS key | Medium | Bucket policy denies uploads naming any key except the vault key | Upload with --sse aws:kms -> AccessDenied (day1-encryption-enforced.png) | Built (Day 1) |
| R1 | Door 6 | Nobody can prove who uploaded a harmful file | Medium | CloudTrail records every S3 upload into a locked logs bucket | Upload, then find the event in CloudTrail | Planned (Day 5) |
| D1 | Door 6 | A user uploads huge files and runs up the bill | Medium | Link has a 100 MB limit and expires after 5 minutes | 101 MB upload -> rejected; 6-minute-old link -> rejected | Planned (Day 2) |

## 5. Risks I'm accepting (not fixing in v1.0)
- **MFA is optional, and there's no leaked-password check or login-alert email** (S3). Cognito's threat protection costs extra. Required MFA is planned for v1.1.
- **A stolen access token can't be cancelled instantly** (S4). It works until its 15 minutes run out.
- **No WAF** to block attacking IP addresses (D2). It costs $6-10/month; throttling covers the basics. Planned for v1.1.

<!-- Paused 2026-09-26: Doors 4, 5, 7, 8, 9 still to do. "How to prove it" is filled in on Day 6. -->
