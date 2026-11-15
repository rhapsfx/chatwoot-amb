# AMB Production Log Diagnostic Scripts

## Overview

Two scripts to help diagnose Apple Messages for Business (AMB) issues on production:

1. **`list-amb-channels.sh`** - Quick lookup of all AMB channels
2. **`diagnose-amb-logs.sh`** - Comprehensive diagnostic report for a specific channel

## Prerequisites

- SSH access to production server (msp.rhaps.net)
- SSH key configured for root@msp.rhaps.net
- Production server must be running

## Scripts

### 1. List AMB Channels

**Purpose**: Quickly view all AMB channels configured on production

**Usage**:
```bash
./script/list-amb-channels.sh
```

**Output**:
```
=== Apple Messages for Business Channels ===

Total AMB Channels: 2

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Inbox: Acoustic House - Beta
  Inbox ID: 11
  Channel ID: 10
  MSP ID: af293df3-a37d-49e5-9437-c82e79899e7f
  Business ID: a7565b9a-5abd-4277-a9e2-97f34e213243
  Webhook URL: https://msp.rhaps.net/webhooks/apple/10
  Status: Active
  Messages (24h): 15
...
```

### 2. Diagnose AMB Logs

**Purpose**: Comprehensive diagnostic report for a specific AMB channel

**Usage**:
```bash
./script/diagnose-amb-logs.sh <MSP_ID> <BUSINESS_ID> [HOURS]
```

**Parameters**:
- `MSP_ID` (required) - The Apple MSP ID (UUID format)
- `BUSINESS_ID` (required) - The Apple Business ID (UUID format)
- `HOURS` (optional) - How many hours to look back (default: 6)

**Examples**:
```bash
# Check last 6 hours (default)
./script/diagnose-amb-logs.sh af293df3-a37d-49e5-9437-c82e79899e7f a7565b9a-5abd-4277-a9e2-97f34e213243

# Check last 24 hours
./script/diagnose-amb-logs.sh af293df3-a37d-49e5-9437-c82e79899e7f a7565b9a-5abd-4277-a9e2-97f34e213243 24

# Check last 1 hour
./script/diagnose-amb-logs.sh af293df3-a37d-49e5-9437-c82e79899e7f a7565b9a-5abd-4277-a9e2-97f34e213243 1
```

## Diagnostic Report Sections

The diagnostic script produces a comprehensive report with 10 sections:

### 1. Channel Configuration Lookup
- Finds the inbox ID from MSP/Business ID
- Displays channel configuration
- Shows webhook URL

### 2. Recent Messages
- Lists all messages in the time range
- Shows message types, content, and status
- Displays content attributes (for interactive messages)

### 3. Recent Conversations
- Active conversations in the time range
- Conversation status and last activity
- Contact information

### 4. Docker Logs - Web Container
- Web server logs mentioning the inbox/channel
- HTTP requests and responses
- Message processing logs

### 5. Docker Logs - Worker Container
- Background job processing
- Sidekiq job execution
- Async message handling

### 6. Rails Production Log
- Detailed Rails application logs
- Request/response cycles
- Service execution logs

### 7. Error & Exception Logs
- All errors related to the channel
- Exception stack traces
- Failed operations

### 8. Webhook Activity
- Incoming webhook requests from Apple MSP
- Webhook payload processing
- Response status codes

### 9. Service Status
- Docker container health
- Service uptime
- Resource usage

### 10. Diagnostic Summary
- Overview of findings
- Next steps recommendations
- Quick reference commands

## Common Use Cases

### Scenario 1: Messages Not Arriving

```bash
# 1. List channels to get IDs
./script/list-amb-channels.sh

# 2. Run diagnostics for last 6 hours
./script/diagnose-amb-logs.sh <MSP_ID> <BUSINESS_ID> 6

# 3. Check section 8 (Webhook Activity) - should show incoming requests
# 4. Check section 7 (Errors) - look for processing errors
# 5. Check section 2 (Messages) - verify messages were created
```

### Scenario 2: Messages Delayed

```bash
# Check last 1 hour with detailed timestamps
./script/diagnose-amb-logs.sh <MSP_ID> <BUSINESS_ID> 1

# Look at:
# - Section 5 (Worker Logs) - background job delays
# - Section 9 (Service Status) - container resource issues
```

### Scenario 3: Webhook Failures

```bash
# Check last 12 hours
./script/diagnose-amb-logs.sh <MSP_ID> <BUSINESS_ID> 12

# Focus on:
# - Section 8 (Webhook Activity) - HTTP errors
# - Section 7 (Errors) - exception details
# - Section 6 (Rails Log) - request processing
```

### Scenario 4: Compare Before/After

```bash
# Check before issue started (e.g., 24 hours ago)
./script/diagnose-amb-logs.sh <MSP_ID> <BUSINESS_ID> 24 > logs_24h.txt

# Check recent period (last 6 hours)
./script/diagnose-amb-logs.sh <MSP_ID> <BUSINESS_ID> 6 > logs_6h.txt

# Compare the two files
diff logs_24h.txt logs_6h.txt
```

## Troubleshooting the Scripts

### SSH Connection Issues

If you get SSH connection errors:

```bash
# Test SSH access
ssh root@msp.rhaps.net echo "Connection successful"

# Check SSH config
cat ~/.ssh/config | grep msp.rhaps.net

# Add SSH key if needed
ssh-add ~/.ssh/your_key
```

### Permission Denied

If you get "Permission denied" errors:

```bash
# Make scripts executable
chmod +x script/diagnose-amb-logs.sh
chmod +x script/list-amb-channels.sh
```

### Channel Not Found

If the script says "Channel Not Found":

1. Run `./script/list-amb-channels.sh` to see all channels
2. Verify MSP ID and Business ID are correct
3. Check for typos (UUIDs are case-sensitive)

### No Logs Found

If many sections say "No logs found":

1. Verify the time range is appropriate (increase HOURS parameter)
2. Check if services are running (section 9)
3. Verify channel is active and configured correctly

## Output Formatting

The scripts use colored output for readability:

- 🟦 **Blue** - Headers and labels
- 🟩 **Green** - Success messages and confirmations
- 🟨 **Yellow** - Warnings and notices
- 🟥 **Red** - Errors and exceptions
- 🟪 **Magenta** - Section headers
- 🩵 **Cyan** - Main titles

To save output without colors (for sharing):
```bash
./script/diagnose-amb-logs.sh <MSP_ID> <BUSINESS_ID> 2>&1 | sed 's/\x1b\[[0-9;]*m//g' > report.txt
```

## Integration with Other Tools

### Save Report to File

```bash
./script/diagnose-amb-logs.sh <MSP_ID> <BUSINESS_ID> 6 > amb-report-$(date +%Y%m%d-%H%M%S).log
```

### Email Report

```bash
./script/diagnose-amb-logs.sh <MSP_ID> <BUSINESS_ID> 6 | mail -s "AMB Diagnostic Report" you@example.com
```

### Slack Notification

```bash
REPORT=$(./script/diagnose-amb-logs.sh <MSP_ID> <BUSINESS_ID> 1)
curl -X POST -H 'Content-type: application/json' \
  --data "{\"text\":\"AMB Diagnostic:\n\`\`\`$REPORT\`\`\`\"}" \
  YOUR_SLACK_WEBHOOK_URL
```

## Continuous Monitoring

To monitor continuously:

```bash
# Run diagnostics every 10 minutes
watch -n 600 './script/diagnose-amb-logs.sh <MSP_ID> <BUSINESS_ID> 1'

# Or create a cron job
# Add to crontab -e:
# */10 * * * * cd /path/to/chatwoot && ./script/diagnose-amb-logs.sh <MSP_ID> <BUSINESS_ID> 1 >> /tmp/amb-monitor.log 2>&1
```

## Quick Reference

```bash
# List all channels
./script/list-amb-channels.sh

# Quick 1-hour check
./script/diagnose-amb-logs.sh <MSP_ID> <BUSINESS_ID> 1

# Standard 6-hour check
./script/diagnose-amb-logs.sh <MSP_ID> <BUSINESS_ID>

# Full day review
./script/diagnose-amb-logs.sh <MSP_ID> <BUSINESS_ID> 24

# Save to file
./script/diagnose-amb-logs.sh <MSP_ID> <BUSINESS_ID> 6 > report.log 2>&1
```

## Related Documentation

- [Deployment Summary](../docs/deployment/DEPLOYMENT_SUMMARY.md)
- [Apple Messages Implementation](../CLAUDE.md#apple-messages-for-business-amb---critical-implementation-notes)
- [CaseTransformer Documentation](../docs/apple-messages/case-normalization-specification.md)

## Support

For issues with these scripts:
1. Check script permissions: `ls -la script/*.sh`
2. Verify SSH access: `ssh root@msp.rhaps.net uptime`
3. Check production server status: `ssh root@msp.rhaps.net "docker ps"`

For AMB issues found in diagnostics:
1. Review error logs (section 7)
2. Check webhook configuration (section 1)
3. Verify service health (section 9)
4. Review recent deployment logs
