#!/bin/bash

# --------------------------------------------
# Cloud-Level Bi-Directional Sync Setup Script
# Google Drive <-> OneDrive (via Rclone)
# --------------------------------------------

# Update and install dependencies
sudo apt update && sudo apt upgrade -y
sudo apt install curl unzip -y

# Install Rclone (if not installed)
if ! command -v rclone &> /dev/null; then
  curl https://rclone.org/install.sh | sudo bash
fi

# Create log directory
mkdir -p /home/ubuntu/rclone_logs

# Create Rclone BiSync script
cat <<'EOF' > /home/ubuntu/run_bisync.sh

#!/bin/bash
# ------------------------------------------------------------------------
# Google Drive ↔ OneDrive | Smart Bi-Directional Sync with Self-Healing
# Automatically runs --resync if cache missing
# ------------------------------------------------------------------------

# === Paths & Folders ===
GDRIVE_PATH="gdrive:/Documents"
ONEDRIVE_PATH="onedrive:/Documents"
GDRIVE_BACKUP="gdrive:/SyncBackups"
ONEDRIVE_BACKUP="onedrive:/SyncBackups"
LOG_DIR="/home/ubuntu/rclone_logs"
CACHE_DIR="/home/ubuntu/.cache/rclone/bisync"
LOG_FILE="${LOG_DIR}/rclone_bisync_$(date +%Y%m%d).log"

# === Ensure directories exist ===
mkdir -p "$LOG_DIR"
mkdir -p "$CACHE_DIR"

# === Detect missing cache (first run or reset) ===
CACHE1="${CACHE_DIR}/gdrive_Documents..onedrive_Documents.path1.lst"
CACHE2="${CACHE_DIR}/gdrive_Documents..onedrive_Documents.path2.lst"

if [[ ! -f "$CACHE1" || ! -f "$CACHE2" ]]; then
  echo "⚙️  Cache missing — running initial --resync to initialize bisync state..." | tee -a "$LOG_FILE"
  /usr/bin/rclone bisync "$GDRIVE_PATH" "$ONEDRIVE_PATH" \
    --create-empty-src-dirs \
    --backup-dir1 "$GDRIVE_BACKUP/$(date +%d-%m-%Y)" \
    --backup-dir2 "$ONEDRIVE_BACKUP/$(date +%d-%m-%Y)" \
    --resync \
    --conflict-resolve newer \
    --compare size,modtime \
    --track-renames \
    --ignore-case-sync \
    --copy-links \
    --check-access \
    --retries 5 \
    --low-level-retries 10 \
    --timeout 60m \
    --log-level INFO \
    --log-file "$LOG_FILE" \
    --force
#    --dry-run
else
  echo "✅ Cache found — running normal bisync..." | tee -a "$LOG_FILE"
  /usr/bin/rclone bisync "$GDRIVE_PATH" "$ONEDRIVE_PATH" \
    --create-empty-src-dirs \
    --backup-dir1 "$GDRIVE_BACKUP/$(date +%d-%m-%Y)" \
    --backup-dir2 "$ONEDRIVE_BACKUP/$(date +%d-%m-%Y)" \
    --conflict-resolve newer \
    --compare size,modtime \
    --track-renames \
    --ignore-case-sync \
    --copy-links \
    --check-access \
    --retries 5 \
    --low-level-retries 10 \
    --timeout 60m \
    --log-level INFO \
    --log-file "$LOG_FILE" \
    --force
#    --dry-run
fi

# === Cleanup old logs ===
find "$LOG_DIR" -type f -mtime +14 -delete

echo "🕒  Sync completed at $(date). Log: $LOG_FILE"

EOF

# Make executable
chmod +x /home/ubuntu/run_bisync.sh

echo "Bi-directional Rclone sync script created at /home/ubuntu/run_bisync.sh"
echo "Next steps:"
echo "1. Run 'rclone config' to add Google Drive (gdrive) and OneDrive (onedrive)."
echo "2. Test manually using: sudo /home/ubuntu/run_bisync.sh"
echo "3. Once tested, add to crontab for automation."
