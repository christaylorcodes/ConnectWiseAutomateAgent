# Security Policy

## Supported Versions

We actively support the following versions of this project with security updates:

| Version | Supported          |
| ------- | ------------------ |
| Latest  | :white_check_mark: |
| < 1.0   | :x:                |

## Reporting a Vulnerability

We take the security of this module and its users seriously. If you believe you have found a security vulnerability, please report it to us as described below.

> **Note:** For documentation of the module's security model (SSL certificate validation, TripleDES encryption, credential redaction), see [Docs/Security.md](../Docs/Security.md).

### Where to Report

**Please do NOT report security vulnerabilities through public GitHub issues.**

Instead, please report them via one of the following methods:

1. **GitHub Security Advisories** (Preferred)
   - Navigate to the repository's Security tab
   - Click "Report a vulnerability"
   - Fill out the security advisory form with details

2. **Direct Email**
   - Send an email to: **security@christaylor.codes**
   - Use the subject line: `[SECURITY] ConnectWiseAutomateAgent - Brief Description`

3. **Private Message on Slack**
   - Contact **@CTaylor** on [MSPGeek Slack](https://join.mspgeek.com/)
   - Clearly mark the message as security-related

### What to Include

Please include the following information in your report to help us better understand and resolve the issue:

- **Type of issue** (e.g., code injection, privilege escalation, information disclosure)
- **Full paths of source file(s)** related to the manifestation of the issue
- **Location of the affected source code** (tag/branch/commit or direct URL)
- **Step-by-step instructions to reproduce the issue**
- **Proof-of-concept or exploit code** (if possible)
- **Impact of the issue**, including how an attacker might exploit it
- **Any special configuration required** to reproduce the issue
- **Your assessment of severity** (Critical, High, Medium, Low)

### What to Expect

After you submit a vulnerability report:

1. **Acknowledgment** - We will acknowledge receipt of your vulnerability report within **48 hours**
2. **Initial Assessment** - We will provide an initial assessment of the vulnerability within **5 business days**
3. **Updates** - We will keep you informed of the progress toward a fix and full announcement
4. **Verification** - We may ask you to verify that our fix resolves the vulnerability
5. **Public Disclosure** - We will coordinate with you on the timing of public disclosure
6. **Credit** - We will credit you in the security advisory (unless you prefer to remain anonymous)

### Response Timeline

| Phase | Timeline |
|-------|----------|
| Acknowledgment | 48 hours |
| Initial Assessment | 5 business days |
| Fix Development | Varies by severity |
| Release | Coordinated with reporter |

### Severity Levels

We use the [CVSS v3.1](https://www.first.org/cvss/calculator/3.1) scoring system to assess vulnerability severity:

- **Critical (9.0-10.0)** - Fix within 24-48 hours
- **High (7.0-8.9)** - Fix within 1 week
- **Medium (4.0-6.9)** - Fix within 2-4 weeks
- **Low (0.1-3.9)** - Fix in next regular release

## Security Best Practices for Users

When using this module, please:

1. **Use InstallerToken over ServerPassword**
   - InstallerToken is scoped and revocable
   - ServerPassword is server-wide and cannot be revoked independently

2. **Avoid `-SkipCertificateCheck` in production**
   - It bypasses ALL SSL validation for the entire PowerShell session
   - If needed, run the operation in an isolated PowerShell session

3. **Keep the Module Updated**
   - Regularly update via `Update-Module ConnectWiseAutomateAgent`
   - Enable Dependabot alerts in your repository if forking

4. **Run with Least Privilege**
   - While admin is required for most operations, avoid running as SYSTEM unless necessary
   - Use dedicated service accounts for automated deployments

5. **Protect Credentials**
   - Never commit InstallerTokens or ServerPasswords to source control
   - Use environment variables or secure secret storage for automated scripts

## Known Security Considerations

This module manages a privileged Windows agent and necessarily interacts with:

- Windows registry (credential storage in TripleDES-encrypted format)
- Windows services (start, stop, install, uninstall)
- Network downloads (agent installer MSI from Automate server)
- SSL/TLS connections (with graduated certificate validation)

For full details on the security model, see [Docs/Security.md](../Docs/Security.md).

## Questions?

If you have questions about this security policy, please:

1. Check the [Discussions](../../discussions) section
2. Open a general (non-security) issue
3. Contact the maintainers through community Slack channels

---

**Last Updated:** 2025-01-22
