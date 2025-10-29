# **Google Drive ↔ OneDrive — Production-Ready, Cloud-Level Sync (Step-by-Step Manual)**

[![Ubuntu Tested](https://img.shields.io/badge/Tested%20on-Ubuntu%2024.04%20LTS-blue)]()
[![Rclone](https://img.shields.io/badge/Powered%20by-Rclone-green)]()
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)]()
[![Automation: Cron](https://img.shields.io/badge/Automation-Cron%20%2B%20Email%20Alerts-orange)]()

---

## 📘 Table of Contents

1. [Overview & Goal](#1--overview--goal)  
2. [Prerequisites](#2--prerequisites)  
3. [Quick Architecture](#3--quick-architecture-how-it-works)  
4. [Step 1 — Provision EC2 (Ubuntu)](#4--step-1--provision-ec2-ubuntu)  
5. [Step 2 — Deploy the Setup Script](#5--step-2--deploy-the-setup-script-one-time)  
6. [Step 3 — Configure Rclone Remotes](#6--step-3--configure-rclone-remotes-gdrive-onedrive)  
7. [Step 4 — Run & Verify First Sync](#7--step-4--run--verify-first-run-initialization---resync)  
8. [Step 5 — Key Safety Flags](#8--step-5--key-safety-flags-what-they-do--recommended-config)  
9. [Step 6 — Automation & Logging](#9--step-6--automation-cron--email-alerts--log-rotation)  
10. [Troubleshooting](#10--troubleshooting-common-errors--fixes)  
11. [Final Checklist](#11--final-checklist--recommended-readme-snippets)

---

## 1️⃣ **Overview & Goal**

The objective is to maintain a **production-ready, cloud-native, bidirectional sync** between **Google Drive** and **OneDrive**, managed entirely via **AWS EC2 (Ubuntu)** and **Rclone Bisync**.

- No desktop clients required  
- Scheduled, auditable, and fully automated  
- Safe by design — versioned backups, rename detection, retries, and logs  

**Outcome:**  
Once deployed, synchronization runs on autopilot — complete with cron automation, email alerts, and log rotation.

---

## 2️⃣ **Prerequisites**

Before you begin, ensure the following:

- ✅ AWS account (permission to create EC2 instances)  
- ✅ Ubuntu 22.04 LTS / 24.04 LTS instance  
- ✅ SSH key for secure access  
- ✅ Google and Microsoft accounts with OAuth access  
- ✅ `rclone` utility (installed automatically via setup script)  
- ✅ Optional: Gmail **App Password** or SMTP relay (for email alerts)

> 💡 **Tip:**  
> For production, consider using **AWS SES** instead of Gmail for reliable mail delivery.

---

## 3️⃣ **Quick Architecture (How It Works)**

```text
 ┌──────────────────────────────────────────────┐
 │          AWS EC2 (Ubuntu 22.04+)            │
 │                                              │
 │  ┌──────────────┐    ┌──────────────┐        │
 │  │ Google Drive │↔──▶│  OneDrive    │        │
 │  └──────────────┘    └──────────────┘        │
 │        ▲      ▲                              │
 │        │      │                              │
 │    rclone bisync engine                      │
 │        │      │                              │
 │   Logs / Backups / Email Alerts              │
 └──────────────────────────────────────────────┘
```

### Components
- **`run_bisync.sh`** — main sync execution script  
- **Rclone** — handles Drive ↔ OneDrive APIs  
- **msmtp** — sends email notifications on failure  
- **cron** — schedules sync jobs  

Logs stored at:  
`/home/ubuntu/rclone_logs/`

---

## 4️⃣ **Step 1 — Provision EC2 (Ubuntu)**

### Recommended Configuration
| Resource | Setting | Notes |
|-----------|----------|-------|
| AMI | Ubuntu 22.04 / 24.04 LTS | Latest LTS recommended |
| Instance Type | `t3.micro` / `t2.micro` | Free Tier OK for light sync |
| Storage | 20 GB | Only logs/caches local |
| Security Group | SSH (22) + Outbound HTTPS (443) | Required for Rclone API access |

### Connect via SSH
```bash
chmod 400 mykey.pem
ssh -i mykey.pem ubuntu@<EC2_PUBLIC_IP>
```

---

## 5️⃣ **Step 2 — Deploy the Setup Script (One-Time)**

This installs dependencies and generates `run_bisync.sh`.

If you’re using the provided `setup_bisync.sh`, upload it and run directly on the VM.  
Otherwise, run these steps manually:

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install dependencies
sudo apt install curl unzip -y

# Install Rclone
curl https://rclone.org/install.sh | sudo bash

# Create directories
mkdir -p /home/ubuntu/rclone_logs
mkdir -p /home/ubuntu/.cache/rclone/bisync
```

> 💡 **Note:**  
> The setup script automatically creates `/home/ubuntu/run_bisync.sh` with production-safe parameters.

---

## 6️⃣ **Step 3 — Configure Rclone Remotes (gdrive, onedrive)**

```bash
rclone config
```

Create **two remotes**:
- `gdrive` → Type: `drive` → Scope: `drive`
- `onedrive` → Type: `onedrive` → Select personal/business as applicable

### Verify Access
```bash
rclone lsd gdrive:
rclone lsd onedrive:
```
Expected output: lists directories (e.g., `/Documents`).

> ⚠️ **Important:**  
> The script expects remotes named **`gdrive`** and **`onedrive`**.  
> If you use different names, update the variable values in `run_bisync.sh`.

---

## 7️⃣ **Step 4 — Run & Verify First Run (`--resync`)**

Rclone Bisync needs baseline cache listings (`.path1.lst`, `.path2.lst`) in:
```
~/.cache/rclone/bisync/
```

If missing, the first run must include `--resync`.

### Example
```bash
rclone bisync gdrive:/Documents onedrive:/Documents   --resync   --backup-dir1 gdrive:/SyncBackups/$(date +%F)   --backup-dir2 onedrive:/SyncBackups/$(date +%F)   --conflict-resolve newer   --track-renames   --create-empty-src-dirs   --log-level INFO   --log-file /home/ubuntu/rclone_logs/init_bisync.log
```

### Validate
```bash
ls -l ~/.cache/rclone/bisync/
# Expect .path1.lst and .path2.lst files
```

> 💡 **Tip:**  
> To establish a single authoritative source before syncing, use `rclone copy` to align both folders.

---

## 8️⃣ **Step 5 — Key Safety Flags (Recommended Configuration)**

| Flag | Purpose |
|------|----------|
| `--create-empty-src-dirs` | Preserve empty directories |
| `--backup-dir1`, `--backup-dir2` | Keep daily timestamped backups per remote |
| `--conflict-resolve newer` | Prioritize newer version |
| `--compare size,modtime` | Compare by size and timestamp |
| `--track-renames` | Detect renames (saves bandwidth) |
| `--ignore-case-sync` | Normalize case sensitivity |
| `--copy-links` | Copy linked file contents |
| `--check-access` | Validate permissions with test file |
| `--retries 5` / `--low-level-retries 10` | Improve reliability |
| `--timeout 60m` | Prevent hung jobs |
| `--log-level INFO` | Verbose but production-safe logging |

> ⚙️ **Command Example:**
```bash
rclone touch gdrive:/Documents/SyncTest/RCLONE_TEST
rclone touch onedrive:/Documents/SyncTest/RCLONE_TEST
```

> ⚠️ **Why Backups Per Remote?**  
> `--backup-dir1` and `--backup-dir2` must live on the same respective remotes — or bisync will abort.

---

## 9️⃣ **Step 6 — Automation: Cron, Email Alerts & Log Rotation**

### a) Script Permissions
```bash
sudo chmod 700 /home/ubuntu/run_bisync.sh
```

---

### b) Cron Job (Example)
Run every Tuesday at 2:30 AM and send email **only on failure**:

```bash
MAILTO="youremail@gmail.com"
30 2 * * TUE /home/ubuntu/run_bisync.sh >> /home/ubuntu/rclone_logs/cron.log 2>&1 || (echo -e "Rclone bisync failed on $(date)

Last 20 log lines:
" && tail -n 20 /home/ubuntu/rclone_logs/cron.log) | mail -s "Rclone Bisync Failure" youremail@gmail.com
```

> 💡 **Explanation:**  
> - `>>` appends logs  
> - `||` triggers mail only on non-zero exit code  
> - Email includes last 20 log lines for quick triage  

---

### c) Email Alerts (msmtp + Gmail App Password)
Install & configure:

```bash
sudo apt update
sudo apt install msmtp msmtp-mta mailutils -y
```

Create config file:
```bash
nano ~/.msmtprc
```
Content:
```ini
defaults
auth on
tls on
tls_starttls on
tls_trust_file /etc/ssl/certs/ca-certificates.crt
logfile ~/.msmtp.log

account gmail
host smtp.gmail.com
port 587
from youremail@gmail.com
user youremail@gmail.com
password "YOUR_GMAIL_APP_PASSWORD"

account default : gmail
```

```bash
chmod 600 ~/.msmtprc
echo "This is a test email" | mail -s "EC2 Mail Test" youremail@gmail.com
```

> 💡 **Note:**  
> Regular Gmail passwords are rejected — use a **Gmail App Password** or **AWS SES** credentials.

---

### d) Log Rotation

Create:
```bash
sudo nano /etc/logrotate.d/rclone_bisync
```
Content:
```conf
/home/ubuntu/rclone_logs/*.log {
    daily
    rotate 14
    compress
    delaycompress
    missingok
    notifempty
    create 0640 ubuntu ubuntu
    sharedscripts
}
```

Test:
```bash
sudo logrotate -fv /etc/logrotate.d/rclone_bisync
```

---

## 🔧 10 — Troubleshooting (Common Errors & Fixes)

> ⚠️ **Error:**  
> `Bisync critical error: cannot find prior Path1 or Path2 listings`  
> **Fix:** Run first-time `--resync` manually or let script auto-detect.

> ⚠️ **Error:**  
> `parameter to --backup-dir has to be on the same remote as destination`  
> **Fix:** Use `--backup-dir1` and `--backup-dir2` per remote.

> ⚠️ **Error:**  
> `--check-access: Failed to find any files named RCLONE_TEST`  
> **Fix:** Create test marker file on both remotes.

> ⚠️ **Error:**  
> `msmtp/mail: cannot send message: Process exited with a non-zero status`  
> **Fix:** Validate `~/.msmtprc` permissions (600) and check `~/.msmtp.log` for auth/TLS issues.

> 💡 **Diagnostic Tip:**  
> Run a safe dry-run before production syncs:
```bash
rclone bisync gdrive:/Documents onedrive:/Documents   --dry-run   --create-empty-src-dirs   --compare size,modtime   --track-renames   --log-level INFO
```

---

## ✅ 11 — Final Checklist & Recommended README Snippets

- [x] EC2 up & secured  
- [x] `rclone` installed and configured  
- [x] Both remotes tested  
- [x] `run_bisync.sh` verified via `--resync`  
- [x] Cron job enabled  
- [x] Email alerts working  
- [x] Log rotation confirmed  

> 📄 **Suggested GitHub README Snippet:**
```markdown
### Cloud-Native Drive Sync
Seamlessly keep Google Drive and OneDrive in sync — powered by Rclone Bisync and AWS EC2.

```bash
sudo /home/ubuntu/run_bisync.sh
```
Logs available at `/home/ubuntu/rclone_logs/`
```
