# Database Migration Guide: Content Attributes Normalization

## Overview

This migration converts all Apple Messages for Business `content_attributes` from mixed camelCase/snake_case to consistent snake_case format.

**Why**: Frontend naturally sends camelCase (JavaScript), but Rails convention is snake_case internally. The new CaseTransformer handles conversion at boundaries, but existing data needs normalization.

**Impact**: ~1,000-10,000 records (varies by deployment)

**Duration**: ~1-5 minutes for 10,000 records

**Risk Level**: **LOW** (idempotent, no data loss)

---

## Quick Start

### Option 1: Automated Migration (Recommended)

```bash
# 1. Test with dry-run
DRY_RUN=true rails db:migrate

# 2. Run for real
rails db:migrate
```

### Option 2: Manual Analysis + Migration

```bash
# 1. Analyze current state
rails runner docs/apple-messages/scripts/dry_run_normalization.rb

# 2. Review sample changes
rails runner docs/apple-messages/scripts/dry_run_normalization.rb VERBOSE=true

# 3. Create backup
pg_dump chatwoot_production > backup_$(date +%Y%m%d).sql

# 4. Run migration
rails db:migrate

# 5. Verify results
rails runner docs/apple-messages/scripts/verify_normalization.rb
```

---

## Pre-Migration Checklist

### Required Steps

- [ ] **Review Phase 1 completion**
  - CaseTransformer module deployed
  - API normalization active
  - Tests passing

- [ ] **Create database backup**
  ```bash
  # PostgreSQL
  pg_dump chatwoot_production > backup_before_normalization_$(date +%Y%m%d).sql

  # Verify backup
  ls -lh backup_before_normalization_*.sql
  ```

- [ ] **Run dry-run analysis**
  ```bash
  rails runner docs/apple-messages/scripts/dry_run_normalization.rb > dry_run_results.txt

  # Review results
  cat dry_run_results.txt
  ```

- [ ] **Check for any critical issues**
  - Look for "DATA LOSS DETECTED" warnings
  - Check "ROUND-TRIP VALIDATION FAILED" errors
  - Review sample changes for unexpected transformations

### Optional (Staging Environment)

- [ ] Test migration in staging first
- [ ] Run for 24-48 hours
- [ ] Monitor application logs
- [ ] Verify frontend functionality

---

## Migration Files

### 1. Migration Script
**Location**: `db/migrate/20251026114341_normalize_apple_messages_content_attributes.rb`

**Features**:
- Batch processing (100 records at a time)
- Transaction per record (atomic updates)
- Progress tracking
- Error handling
- Statistics reporting

**Environment Variables**:
```bash
# Dry-run mode (no changes)
DRY_RUN=true rails db:migrate

# Verbose logging
VERBOSE=true rails db:migrate

# Combined
DRY_RUN=true VERBOSE=true rails db:migrate
```

### 2. Dry-Run Analysis Script
**Location**: `docs/apple-messages/scripts/dry_run_normalization.rb`

**What it does**:
- Analyzes all Apple Messages records
- Shows what changes would be made
- Validates transformation safety
- Provides detailed statistics
- Identifies potential issues

**Usage**:
```bash
# Basic analysis
rails runner docs/apple-messages/scripts/dry_run_normalization.rb

# Verbose mode (detailed output)
rails runner docs/apple-messages/scripts/dry_run_normalization.rb VERBOSE=true

# Save results to file
rails runner docs/apple-messages/scripts/dry_run_normalization.rb > analysis.txt
```

**Expected Output**:
```
========================================================================
Apple Messages Content Attributes Normalization - DRY RUN
========================================================================

Found 1,234 Apple Messages records

Analyzing records...
------------------------------------------------------------------------

========================================================================
DRY RUN RESULTS
========================================================================

Summary:
  Total records:             1,234
  Need normalization:        456 (37.0%)
  Already normalized:        778 (63.0%)
  Empty (skipped):           0
  Errors:                    0

Changes by content type:
  apple_list_picker         234 records
  apple_time_picker         122 records
  apple_form                 89 records
  apple_quick_reply          11 records

Most affected fields (top 10):
  imageIdentifier                     234 occurrences
  multipleSelection                   112 occurrences
  receivedImageIdentifier             89 occurrences
  ...

========================================================================
SAFETY CHECKS
========================================================================

✅ No data loss detected
✅ Round-trip transformation validated

========================================================================
RECOMMENDATIONS
========================================================================

✅ Migration appears safe to proceed

Next steps:
  1. Review sample changes above
  2. Create database backup:
     pg_dump chatwoot_development > backup_before_normalization.sql
  3. Run migration in staging first:
     DRY_RUN=true rails db:migrate
  4. Test application thoroughly in staging
  5. Run migration in production:
     rails db:migrate
```

### 3. Rollback Script
**Location**: `docs/apple-messages/scripts/rollback_normalization.rb`

**What it does**:
- Reverses normalization (snake_case → camelCase)
- Safety confirmations required
- Statistics and progress tracking

**Usage**:
```bash
# Dry-run (see what would change)
rails runner docs/apple-messages/scripts/rollback_normalization.rb DRY_RUN=true

# LIVE rollback (requires confirmation)
rails runner docs/apple-messages/scripts/rollback_normalization.rb CONFIRM_ROLLBACK=yes
```

**⚠️ WARNING**: Only use if you need to fully revert the migration. Services expect snake_case internally after Phase 1.

### 4. Verification Script
**Location**: `docs/apple-messages/scripts/verify_normalization.rb`

**What it does**:
- Checks normalization status
- Identifies remaining issues
- Validates data integrity
- Provides health metrics

**Usage**:
```bash
# Basic verification
rails runner docs/apple-messages/scripts/verify_normalization.rb

# Detailed analysis (includes integrity checks)
rails runner docs/apple-messages/scripts/verify_normalization.rb DETAILED=true

# Save results
rails runner docs/apple-messages/scripts/verify_normalization.rb > verification.txt
```

**Expected Output**:
```
========================================================================
Apple Messages Content Attributes Normalization - VERIFICATION
========================================================================

Found 1,234 Apple Messages records

Analyzing records...
------------------------------------------------------------------------

========================================================================
VERIFICATION RESULTS
========================================================================

Overall Health:
  Total records:           1,234
  Fully normalized:        1,234 (100.0%)
  Has camelCase:           0
  Mixed case (problem):    0

✅ EXCELLENT: All records are properly normalized

By Content Type:
------------------------------------------------------------------------
  ✅ apple_list_picker         456/456 normalized (100.0%)
  ✅ apple_time_picker         389/389 normalized (100.0%)
  ✅ apple_form                234/234 normalized (100.0%)
  ✅ apple_quick_reply         155/155 normalized (100.0%)

========================================================================
RECOMMENDATIONS
========================================================================

✅ All records are properly normalized. No action needed.

Services can now safely remove defensive dual-checks.
```

---

## Step-by-Step Migration Process

### Staging Environment

#### Step 1: Analysis (5 minutes)

```bash
# Run dry-run analysis
rails runner docs/apple-messages/scripts/dry_run_normalization.rb VERBOSE=true > staging_analysis.txt

# Review results
less staging_analysis.txt

# Look for:
# - Total records to process
# - Sample changes
# - Safety checks (should all pass ✅)
```

#### Step 2: Backup (2 minutes)

```bash
# Create database backup
pg_dump chatwoot_staging > backup_staging_$(date +%Y%m%d_%H%M%S).sql

# Verify backup size
ls -lh backup_staging_*.sql
```

#### Step 3: Migration (3-10 minutes depending on size)

```bash
# Run migration
rails db:migrate

# Watch logs
tail -f log/production.log | grep -i "normalization"
```

**Expected Output**:
```
Starting Apple Messages content_attributes normalization
Mode: LIVE
========================================================================
Found 1,234 Apple Messages to process
Processing in 13 batches of 100
------------------------------------------------------------------------
Processing batch 1/13...
  Progress: 50/1234 (4.1%)
Processing batch 2/13...
  Progress: 100/1234 (8.1%)
...
========================================================================
Migration complete!

Statistics:
  Total processed:      1,234
  Normalized:           456
  Already normalized:   778
  Skipped (empty):      0
  Errors:               0

========================================================================
MIGRATION COMPLETE - Changes applied to database
========================================================================
```

#### Step 4: Verification (2 minutes)

```bash
# Verify normalization
rails runner docs/apple-messages/scripts/verify_normalization.rb DETAILED=true > staging_verification.txt

# Review results
less staging_verification.txt

# Should show:
# ✅ EXCELLENT: All records are properly normalized
```

#### Step 5: Testing (24-48 hours)

**Test Cases**:
- [ ] Send Apple List Picker with images (frontend should work normally)
- [ ] Send Apple Time Picker with timeslots
- [ ] Create Apple Form with received/reply messages
- [ ] Test bot message creation
- [ ] Verify all images display correctly
- [ ] Check existing messages render properly

**Monitor**:
```bash
# Check application logs
tail -f log/production.log | grep -i "apple\|normalization"

# Check for errors
grep -i "error" log/production.log | grep -i "apple"

# Verify API normalization is working
grep -i "\[API\] Normalizing" log/production.log
```

### Production Environment

#### Pre-Flight Checklist

- [ ] Staging migration successful (no errors)
- [ ] Application tested in staging (24-48 hours)
- [ ] All tests pass
- [ ] Team notified of deployment window
- [ ] Rollback plan reviewed
- [ ] Backup plan confirmed

#### Step 1: Backup (5-10 minutes)

```bash
# Create backup (production)
pg_dump chatwoot_production > backup_production_$(date +%Y%m%d_%H%M%S).sql

# Verify backup
ls -lh backup_production_*.sql

# Optional: Test backup restore on dev
# createdb chatwoot_test_restore
# psql chatwoot_test_restore < backup_production_$(date +%Y%m%d_%H%M%S).sql
```

#### Step 2: Run Analysis (2 minutes)

```bash
# Quick sanity check
rails runner docs/apple-messages/scripts/dry_run_normalization.rb > production_analysis.txt

# Review - should match staging results (similar counts)
cat production_analysis.txt
```

#### Step 3: Migration (5-15 minutes)

```bash
# Announce maintenance window (if needed)
# Most deployments can run this live with no downtime

# Run migration
rails db:migrate

# Monitor progress
tail -f log/production.log | grep -i "normalization"
```

#### Step 4: Immediate Verification (2 minutes)

```bash
# Verify normalization
rails runner docs/apple-messages/scripts/verify_normalization.rb > production_verification.txt

# Should show 100% normalized
cat production_verification.txt | grep "Overall Health" -A 5
```

#### Step 5: Smoke Tests (10 minutes)

**Critical Paths**:
- [ ] Send test Apple Messages from frontend
- [ ] Verify images display
- [ ] Check existing conversations render
- [ ] Test bot message creation
- [ ] Verify API responses

**Quick Tests**:
```bash
# Check latest normalized message
rails runner "puts Message.where(content_type: 'apple_list_picker').last.content_attributes.inspect"

# Should show snake_case keys:
# {"sections"=>[...], "images"=>[...], "received_title"=>..., "reply_image_identifier"=>...}

# Check API normalization is working
curl -X POST http://localhost:3000/api/v1/accounts/1/conversations/123/messages \
  -H "Content-Type: application/json" \
  -d '{"content_type":"apple_list_picker","content_attributes":{"imageIdentifier":"test"}}'

# Check logs show normalization:
tail -20 log/production.log | grep "\[API\]"
```

---

## Monitoring Post-Migration

### First 24 Hours

**Check every 2 hours**:
```bash
# Error rate
grep -c "ERROR" log/production.log

# Apple Messages sent
rails runner "puts Message.where(content_type: 'apple_list_picker').where('created_at > ?', 1.hour.ago).count"

# Normalization working
grep -c "\[API\] Normalizing" log/production.log
```

### First Week

**Daily checks**:
```bash
# Verify no mixed-case records appearing
rails runner docs/apple-messages/scripts/verify_normalization.rb | grep "Overall Health" -A 5

# Should remain 100% normalized
```

### Metrics to Track

- **Message creation success rate**: Should remain stable
- **Image display success rate**: Should remain 100%
- **Frontend errors**: Should be zero
- **API normalization count**: Should match new message creation rate

---

## Troubleshooting

### Issue: "DATA LOSS DETECTED" during dry-run

**Cause**: Key count mismatch (original vs normalized)

**Solution**:
```bash
# Identify problematic messages
rails runner docs/apple-messages/scripts/dry_run_normalization.rb VERBOSE=true | grep "WARNING: Key count"

# Investigate specific message
rails runner "msg = Message.find(ID); puts msg.content_attributes.inspect"

# Check if it's an edge case
# Contact team if unexpected
```

### Issue: "ROUND-TRIP VALIDATION FAILED"

**Cause**: Transformation not reversible

**Solution**:
```bash
# Test round-trip manually
rails runner "
msg = Message.find(ID)
original = msg.content_attributes
to_apple = AppleMessagesForBusiness::CaseTransformer.to_apple_format(original)
back = AppleMessagesForBusiness::CaseTransformer.from_apple_format(to_apple.transform_keys(&:to_s))
puts 'Original: ' + original.inspect
puts 'After round-trip: ' + back.inspect
puts 'Match: ' + (back == original).to_s
"

# If critical, fix CaseTransformer mapping
```

### Issue: Errors during migration

**Symptoms**: "ERROR processing message" in output

**Solution**:
```bash
# Re-run with verbose logging
VERBOSE=true rails db:migrate:redo VERSION=20251026114341

# Check error details
# Fix data issues or CaseTransformer bugs
# Re-run migration
```

### Issue: Some records not normalized after migration

**Symptoms**: verify_normalization.rb shows <100%

**Solution**:
```bash
# Identify problematic records
rails runner docs/apple-messages/scripts/verify_normalization.rb DETAILED=true | grep "Message #"

# Manually fix specific records
rails runner "
msg = Message.find(ID)
msg.content_attributes = AppleMessagesForBusiness::CaseTransformer.from_apple_format(msg.content_attributes)
msg.save!
puts 'Fixed message ' + msg.id.to_s
"

# Or re-run migration (safe, idempotent)
rails db:migrate:redo VERSION=20251026114341
```

### Issue: Need to rollback everything

**When**: Critical issues found post-migration

**Solution**:
```bash
# 1. Restore from backup
pg_restore -d chatwoot_production backup_production_YYYYMMDD_HHMMSS.sql

# 2. Or use rollback script
rails runner docs/apple-messages/scripts/rollback_normalization.rb DRY_RUN=true
rails runner docs/apple-messages/scripts/rollback_normalization.rb CONFIRM_ROLLBACK=yes

# 3. Verify
rails runner docs/apple-messages/scripts/verify_normalization.rb
```

---

## FAQ

### Q: Will this cause downtime?

**A**: No. Migration runs in background, application continues to serve requests. Frontend normalization (Phase 1) is already deployed and handles new messages.

### Q: What if migration fails halfway?

**A**: Each record is updated in its own transaction. If migration fails, completed records remain normalized, others remain unchanged. Safe to re-run.

### Q: Can I run this multiple times?

**A**: Yes. Transformation is idempotent (running multiple times produces same result). Already-normalized records are skipped.

### Q: How long will it take?

**A**: ~1-2 seconds per 100 records. For 10,000 records: ~2-3 minutes.

### Q: Will frontend break?

**A**: No. Frontend continues sending camelCase, API controller normalizes to snake_case (Phase 1 already deployed).

### Q: What about new messages during migration?

**A**: New messages are automatically normalized by API controller (Phase 1). Migration only handles existing old records.

### Q: Can I rollback?

**A**: Yes. Use rollback script OR restore from backup. However, services expect snake_case after Phase 1, so code changes may also need rollback.

### Q: What gets normalized?

**A**: Only `content_attributes` for these content types:
- apple_list_picker
- apple_time_picker
- apple_quick_reply
- apple_form
- apple_custom_app
- apple_rich_link
- apple_pay
- apple_authentication

---

## Success Criteria

✅ **Migration successful** when:
- [ ] Dry-run analysis shows no critical issues
- [ ] Migration completes with 0 errors
- [ ] Verification shows 100% normalized
- [ ] Frontend functionality works normally
- [ ] Images display correctly
- [ ] No error spike in logs
- [ ] All smoke tests pass

---

## Next Steps After Migration

Once migration is complete and verified:

1. **Phase 2**: Begin service layer updates
   - Remove defensive dual-checks
   - Use CaseTransformer throughout
   - ~12-16 hours work

2. **Update CLAUDE.md**: Document new snake_case convention

3. **Team Training**: Brief team on new standards

4. **Monitor**: Watch for any edge cases over next week

---

## Support

**Issues or Questions?**
- Review specification: `docs/apple-messages/case-normalization-specification.md`
- Check Phase 1 status: `docs/apple-messages/PHASE_1_COMPLETE.md`
- Run verification: `rails runner docs/apple-messages/scripts/verify_normalization.rb`

**Emergency Rollback**:
```bash
# Contact team lead first
# Then: restore from backup OR use rollback script
```
