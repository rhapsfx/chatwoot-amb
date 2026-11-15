# Log Archiving and Cleanup Feature

**Date**: November 21, 2025  
**Script**: `script/dev-server.sh`  
**Status**: ✅ Implemented

## Overview

Automatic log file archiving and cleanup has been added to the development server script. This feature runs every time the server starts or restarts, keeping the log directory clean and organized.

## Features

### 1. **Automatic Log Archiving**
- Archives all `.log` files when the server starts/restarts
- Compresses logs using gzip for space efficiency
- Preserves original log files (clears content instead of deleting)
- Archives numbered log files (e.g., `development.log.0`, `development.log.1`)
- Adds timestamp to archived files for easy identification

### 2. **Automatic Cleanup**
- Deletes `.gz` archives older than 5 days
- Runs automatically on each server start/restart
- Prevents log directory from growing indefinitely

## How It Works

### Archive Process

When you run `./script/dev-server.sh start` or `restart`:

1. **Archive current logs**:
   ```
   log/development.log → log/development_20251121_075530.log.gz
   log/sidekiq.log     → log/sidekiq_20251121_075530.log.gz
   log/rails.log       → log/rails_20251121_075530.log.gz
   ```

2. **Clear original files**:
   - Original `.log` files are cleared (not deleted) so Rails can continue writing
   - Numbered backups (`.log.0`, `.log.1`) are deleted after archiving

3. **Clean up old archives**:
   - Scans for `.gz` files older than 5 days
   - Automatically deletes them

### File Naming Convention

Archived files use this format:
```
{original_name}_{timestamp}.log.gz
```

Examples:
- `development_20251121_075530.log.gz`
- `sidekiq_20251120_143022.log.gz`
- `rails_20251119_091545.log.gz`

## Benefits

1. **Disk Space Management**: Compressed archives use ~90% less space than raw logs
2. **Automatic Cleanup**: No manual intervention needed to manage old logs
3. **Historical Records**: Keeps 5 days of archived logs for debugging
4. **Clean Workspace**: Log directory stays organized and manageable
5. **No Downtime**: Archives are created before starting new services

## Configuration

### Retention Period

To change the 5-day retention period, edit the `archive_and_cleanup_logs()` function in `script/dev-server.sh`:

```bash
# Change this line (currently 5 days):
local cutoff_date=$(date -v-5d +%s 2>/dev/null || date -d '5 days ago' +%s 2>/dev/null)

# For 7 days:
local cutoff_date=$(date -v-7d +%s 2>/dev/null || date -d '7 days ago' +%s 2>/dev/null)

# For 3 days:
local cutoff_date=$(date -v-3d +%s 2>/dev/null || date -d '3 days ago' +%s 2>/dev/null)
```

### Disable Archiving

To disable automatic archiving, comment out the function call in the script:

```bash
start)
    print_status "Starting Chatwoot development server (localhost only)..."
    cleanup_stale_processes
    # archive_and_cleanup_logs  # ← Comment this line
    start_rails
    start_sidekiq
    show_status
    ;;
```

## Manual Archiving

You can also manually archive logs without restarting the server:

```bash
# Create a simple script to archive logs manually
cd log
timestamp=$(date +%Y%m%d_%H%M%S)
for log in *.log; do
    [ -e "$log" ] || continue
    gzip -c "$log" > "${log%.log}_${timestamp}.log.gz"
    > "$log"  # Clear the file
done
```

## Troubleshooting

### Archives Not Being Created

Check if gzip is installed:
```bash
which gzip
# Should output: /usr/bin/gzip or similar
```

### Old Archives Not Being Deleted

The script uses different date commands for macOS and Linux:
- macOS: `date -v-5d`
- Linux: `date -d '5 days ago'`

If neither works, you'll see a warning message. Install GNU coreutils on macOS:
```bash
brew install coreutils
```

### Permission Issues

Ensure the script has write permissions to the log directory:
```bash
chmod 755 script/dev-server.sh
chmod 755 log
```

## Example Output

When starting the server:
```
[INFO] Starting Chatwoot development server (localhost only)...
[INFO] Cleaning up stale processes and PID files...
[SUCCESS] Cleanup completed
[INFO] Archiving and cleaning up log files...
[SUCCESS] Archived 3 log file(s)
[SUCCESS] Deleted 2 old archive(s) (>5 days)
[SUCCESS] Log archiving and cleanup completed
[INFO] Starting Rails server with Ruby 3.3.9...
```

## Files Modified

- `script/dev-server.sh` - Added `archive_and_cleanup_logs()` function and integrated it into start/restart commands

## Related Features

This feature complements:
- Nil log filtering (prevents empty log entries)
- Log sanitization (removes sensitive data from logs)
- Job argument suppression (reduces log verbosity)