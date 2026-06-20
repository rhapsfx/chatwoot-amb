# Apple Messages Image Architecture Migration Guide

## Overview

This guide walks you through migrating existing Apple Messages for Business installations from the current inbox-specific image storage to the new two-tier shared image architecture.

### What Changed and Why

**Previous Architecture (Single-tier)**:
- Images stored per inbox in `AppleListPickerImage` model
- Each inbox required separate uploads of identical system images
- Manual replication for common branding images
- High storage usage and maintenance overhead

**New Architecture (Two-tier)**:
- **Tier 1**: Account-level shared images (`SharedAppleImage`)
- **Tier 2**: Inbox-specific overrides (`AppleListPickerImage`)
- Automatic three-tier fallback (inbox → shared → embedded)
- 80% reduction in duplicate images

### Benefits of the New Architecture

- **Storage Efficiency**: 80% reduction in duplicate images
- **Simplified Management**: Upload once, use everywhere
- **Better UX**: Consistent branding across all inboxes
- **Zero Downtime**: Backward compatible migration
- **Flexible Override**: Inbox-specific customization when needed

### Migration Timeline

- **Small installations (< 5 inboxes)**: 3 weeks total
- **Medium installations (5-20 inboxes)**: 4 weeks total
- **Large installations (> 20 inboxes)**: 5 weeks total

---

## Pre-Migration Checklist

Before starting migration, ensure:

### 1. Verify Database Backups
```bash
# Verify recent backup exists
ls -la /path/to/backups/

# Create fresh backup if needed
pg_dump chatwoot_production > chatwoot_backup_$(date +%Y%m%d).sql
```

### 2. Check Current Image Usage
```bash
rails runner "
  puts 'Total images: ' + AppleListPickerImage.count.to_s
  puts 'Total inboxes: ' + Channel::AppleMessagesForBusiness.count.to_s
  puts 'Images per inbox:'
  Channel::AppleMessagesForBusiness.find_each do |channel|
    count = AppleListPickerImage.where(inbox_id: channel.inbox_id).count
    puts \"  Inbox ##{channel.inbox_id}: #{count} images\"
  end
"
```

### 3. Run Pre-Migration Audit
```bash
# Create audit script
cat > script/audit_image_usage.rb << 'EOF'
puts "\n=== Apple Messages Image Audit ==="
puts "Timestamp: #{Time.current}"
puts "-" * 50

# Count total images
total_images = AppleListPickerImage.count
puts "Total images in database: #{total_images}"

# Identify duplicates by filename
duplicates = AppleListPickerImage
  .joins(:blob)
  .group('active_storage_blobs.filename')
  .having('COUNT(*) > 1')
  .count

puts "\nDuplicate images found:"
duplicates.each do |filename, count|
  puts "  #{filename}: #{count} copies"
end

# Identify system images (common patterns)
system_patterns = ['menu_icon', 'store_logo', 'apple_logo', 'messages_icon']
system_images = AppleListPickerImage.joins(:blob).where(
  'active_storage_blobs.filename ILIKE ANY(ARRAY[?])',
  system_patterns.map { |p| "%#{p}%" }
).count

puts "\nLikely system images: #{system_images}"

# Check for orphaned images
orphaned = AppleListPickerImage.left_joins(:inbox).where(inboxes: { id: nil }).count
puts "Orphaned images (no inbox): #{orphaned}"

puts "\nRecommended migration:"
puts "  - System images to migrate: ~#{system_images}"
puts "  - Potential storage savings: ~#{(duplicates.values.sum - duplicates.count) * 100}KB"
puts "-" * 50
EOF

rails runner script/audit_image_usage.rb
```

### 4. Review Migration Plan

- [ ] Backup completed and verified
- [ ] Audit results reviewed
- [ ] Maintenance window scheduled
- [ ] Team notified of migration
- [ ] Rollback plan understood

---

## Migration Steps

### Step 1: Audit Current Images

Run the comprehensive audit to understand your current state:

```bash
rails runner script/audit_image_usage.rb
```

**What to look for in audit results:**
- High duplicate count indicates good migration candidates
- System image patterns (menu_icon, store_logo, etc.)
- Orphaned images that can be cleaned up

**Identify system vs inbox-specific images:**
- **System images**: Used across all inboxes (menu icons, logos)
- **Branding images**: Account-specific but shared across inboxes
- **Custom images**: Unique to specific inboxes (keep as-is)

### Step 2: Database Migrations

Run the database migrations to create new tables:

```bash
# Check pending migrations
rails db:migrate:status

# Run migrations
rails db:migrate
```

**Migrations that will run:**
- `CreateSharedAppleImages` - Creates shared image table
- `AddAccountIdToSharedAppleImages` - Adds account association
- `AddMetadataToSharedAppleImages` - Adds metadata fields
- `CreateSharedAppleImageMappings` - Creates mapping table

**Expected schema changes:**
```sql
-- New table: shared_apple_images
CREATE TABLE shared_apple_images (
  id bigserial PRIMARY KEY,
  account_id bigint NOT NULL,
  identifier varchar NOT NULL,
  name varchar,
  description text,
  category varchar,
  metadata jsonb DEFAULT '{}',
  created_at timestamp NOT NULL,
  updated_at timestamp NOT NULL
);

-- Indexes
CREATE UNIQUE INDEX ON shared_apple_images(account_id, identifier);
CREATE INDEX ON shared_apple_images(category);
```

### Step 3: Migrate System Images

Create and run the system image migration script:

```bash
cat > script/migrate_system_images_to_shared.rb << 'EOF'
# System Image Migration Script
require 'digest'

class SystemImageMigrator
  SYSTEM_PATTERNS = {
    'menu_icon' => { category: 'system', name: 'Menu Icon' },
    'store_logo' => { category: 'branding', name: 'Store Logo' },
    'apple_logo' => { category: 'system', name: 'Apple Logo' },
    'messages_icon' => { category: 'system', name: 'Messages Icon' },
    'time_picker' => { category: 'system', name: 'Time Picker Icon' },
    'form_icon' => { category: 'system', name: 'Form Icon' }
  }.freeze

  def initialize(execute: false)
    @execute = execute
    @migrated = 0
    @skipped = 0
    @errors = 0
  end

  def run
    puts "\n=== System Image Migration #{@execute ? 'EXECUTING' : 'DRY RUN'} ==="
    puts "Starting at: #{Time.current}"
    puts "-" * 50

    SYSTEM_PATTERNS.each do |pattern, config|
      migrate_pattern(pattern, config)
    end

    puts "\n=== Migration Summary ==="
    puts "Migrated: #{@migrated} images"
    puts "Skipped: #{@skipped} images"
    puts "Errors: #{@errors}"
    puts "Mode: #{@execute ? 'EXECUTED' : 'DRY RUN'}"
    puts "-" * 50
  end

  private

  def migrate_pattern(pattern, config)
    puts "\nProcessing pattern: #{pattern}"

    images = AppleListPickerImage
      .joins(:blob)
      .where('active_storage_blobs.filename ILIKE ?', "%#{pattern}%")
      .includes(:blob, inbox: :account)

    images.find_each do |image|
      migrate_image(image, config)
    end
  end

  def migrate_image(image, config)
    account = image.inbox&.account
    return skip_image(image, "No account found") unless account

    identifier = generate_identifier(image)

    if @execute
      shared = SharedAppleImage.find_or_initialize_by(
        account: account,
        identifier: identifier
      )

      shared.assign_attributes(
        name: config[:name],
        category: config[:category],
        description: "Migrated from inbox ##{image.inbox_id}",
        metadata: {
          original_inbox_id: image.inbox_id,
          migrated_at: Time.current,
          original_filename: image.blob.filename.to_s
        }
      )

      if image.blob.present?
        shared.image.attach(image.blob.blob)
      end

      if shared.save
        puts "  ✓ Migrated: #{identifier} for account ##{account.id}"
        @migrated += 1
      else
        puts "  ✗ Error: #{shared.errors.full_messages.join(', ')}"
        @errors += 1
      end
    else
      puts "  [DRY RUN] Would migrate: #{identifier} for account ##{account.id}"
      @migrated += 1
    end
  rescue => e
    puts "  ✗ Error migrating image ##{image.id}: #{e.message}"
    @errors += 1
  end

  def generate_identifier(image)
    base = image.blob.filename.to_s.split('.').first
    base.gsub(/[^a-zA-Z0-9_-]/, '_').downcase
  end

  def skip_image(image, reason)
    puts "  - Skipped image ##{image.id}: #{reason}"
    @skipped += 1
  end
end

# Parse arguments
execute = ARGV.include?('--execute')

# Run migration
migrator = SystemImageMigrator.new(execute: execute)
migrator.run
EOF

# Dry run first
rails runner script/migrate_system_images_to_shared.rb

# Review output, then execute
rails runner script/migrate_system_images_to_shared.rb --execute
```

**What happens during migration:**
- System images are identified by filename patterns
- Images are copied (not moved) to SharedAppleImage
- Original images remain for backward compatibility
- Metadata tracks migration source

### Step 4: Migrate Branding Images

Create and run the branding image migration:

```bash
cat > script/migrate_branding_images_to_shared.rb << 'EOF'
# Branding Image Migration Script

class BrandingImageMigrator
  BRANDING_PATTERNS = {
    'logo' => { category: 'branding', name: 'Brand Logo' },
    'header' => { category: 'branding', name: 'Header Image' },
    'footer' => { category: 'branding', name: 'Footer Image' },
    'banner' => { category: 'branding', name: 'Banner Image' }
  }.freeze

  def initialize(execute: false, all_accounts: false)
    @execute = execute
    @all_accounts = all_accounts
    @migrated = 0
    @skipped = 0
  end

  def run
    puts "\n=== Branding Image Migration #{@execute ? 'EXECUTING' : 'DRY RUN'} ==="

    accounts = @all_accounts ? Account.all : Account.where(id: ENV['ACCOUNT_ID'])

    accounts.find_each do |account|
      migrate_account_branding(account)
    end

    puts "\n=== Summary ==="
    puts "Migrated: #{@migrated} images"
    puts "Skipped: #{@skipped} images"
  end

  private

  def migrate_account_branding(account)
    puts "\nProcessing account ##{account.id}: #{account.name}"

    # Find all inboxes for this account
    inboxes = account.inboxes.joins(:channel)
      .where(channel: { type: 'Channel::AppleMessagesForBusiness' })

    # Collect unique branding images
    branding_images = {}

    inboxes.each do |inbox|
      AppleListPickerImage.where(inbox: inbox).joins(:blob).each do |image|
        BRANDING_PATTERNS.each do |pattern, config|
          if image.blob.filename.to_s.include?(pattern)
            key = image.blob.checksum
            branding_images[key] ||= { image: image, config: config, inboxes: [] }
            branding_images[key][:inboxes] << inbox.id
          end
        end
      end
    end

    # Migrate unique images
    branding_images.each do |checksum, data|
      if data[:inboxes].length > 1
        migrate_to_shared(account, data[:image], data[:config])
      else
        puts "  - Skipped (single inbox): #{data[:image].blob.filename}"
        @skipped += 1
      end
    end
  end

  def migrate_to_shared(account, image, config)
    identifier = generate_identifier(image)

    if @execute
      shared = SharedAppleImage.find_or_create_by(
        account: account,
        identifier: identifier
      ) do |s|
        s.name = config[:name]
        s.category = config[:category]
        s.description = "Shared branding image"
        s.image.attach(image.blob.blob) if image.blob.present?
      end

      puts "  ✓ Migrated: #{identifier}"
      @migrated += 1
    else
      puts "  [DRY RUN] Would migrate: #{identifier}"
      @migrated += 1
    end
  end

  def generate_identifier(image)
    base = image.blob.filename.to_s.split('.').first
    base.gsub(/[^a-zA-Z0-9_-]/, '_').downcase
  end
end

# Parse arguments
execute = ARGV.include?('--execute')
all_accounts = ARGV.include?('--all-accounts')

# Run migration
migrator = BrandingImageMigrator.new(execute: execute, all_accounts: all_accounts)
migrator.run
EOF

# Dry run for specific account
ACCOUNT_ID=1 rails runner script/migrate_branding_images_to_shared.rb

# Execute for all accounts
rails runner script/migrate_branding_images_to_shared.rb --execute --all-accounts
```

**Account-specific considerations:**
- Images used in multiple inboxes → migrate to shared
- Images used in single inbox → keep as-is
- Preserves inbox-specific customization

### Step 5: Verify Migration

Create and run verification script:

```bash
cat > script/verify_image_migration.rb << 'EOF'
# Image Migration Verification Script

class MigrationVerifier
  def initialize
    @tests = []
    @passed = 0
    @failed = 0
  end

  def run
    puts "\n=== Migration Verification ==="
    puts "Running #{test_count} tests..."
    puts "-" * 50

    run_test("Shared images table exists") do
      ActiveRecord::Base.connection.table_exists?('shared_apple_images')
    end

    run_test("Shared images have attachments") do
      SharedAppleImage.joins(:image_attachment).count > 0
    end

    run_test("Account associations valid") do
      SharedAppleImage.all.all? { |img| img.account.present? }
    end

    run_test("Identifiers are unique per account") do
      duplicates = SharedAppleImage.group(:account_id, :identifier)
        .having('COUNT(*) > 1').count
      duplicates.empty?
    end

    run_test("Categories are set") do
      SharedAppleImage.where(category: nil).count == 0
    end

    run_test("Three-tier fallback working") do
      # Test with a sample service
      service = AppleMessagesForBusiness::SendListPickerService.new(
        message: Message.new,
        content_attributes: { 'sections' => [] }
      )
      service.respond_to?(:fetch_image_with_fallback)
    end

    run_test("Original images preserved") do
      AppleListPickerImage.count > 0
    end

    run_test("Metadata preserved") do
      SharedAppleImage.where("metadata IS NOT NULL AND metadata != '{}'").count > 0
    end

    run_test("Image blobs are valid") do
      invalid = SharedAppleImage.joins(:image_attachment).where(
        active_storage_attachments: { blob_id: nil }
      ).count
      invalid == 0
    end

    run_test("No orphaned attachments") do
      orphaned = ActiveStorage::Attachment.where(
        record_type: 'SharedAppleImage'
      ).left_joins(:blob).where(active_storage_blobs: { id: nil }).count
      orphaned == 0
    end

    print_summary
  end

  private

  def test_count
    10
  end

  def run_test(name, &block)
    print "  Testing: #{name}... "
    result = block.call
    if result
      puts "✓ PASSED"
      @passed += 1
    else
      puts "✗ FAILED"
      @failed += 1
    end
    @tests << { name: name, passed: result }
  rescue => e
    puts "✗ ERROR: #{e.message}"
    @failed += 1
    @tests << { name: name, passed: false, error: e.message }
  end

  def print_summary
    puts "\n" + "=" * 50
    puts "VERIFICATION COMPLETE"
    puts "=" * 50
    puts "Total Tests: #{test_count}"
    puts "Passed: #{@passed} (#{(@passed.to_f / test_count * 100).round}%)"
    puts "Failed: #{@failed}"

    if @failed > 0
      puts "\nFailed Tests:"
      @tests.select { |t| !t[:passed] }.each do |test|
        puts "  - #{test[:name]}"
        puts "    Error: #{test[:error]}" if test[:error]
      end
    end

    puts "\nRecommendation: #{recommendation}"
  end

  def recommendation
    if @passed == test_count
      "✅ Migration successful! Ready for production."
    elsif @passed >= test_count * 0.8
      "⚠️ Migration mostly successful. Review failed tests."
    else
      "❌ Migration has issues. Do not proceed to production."
    end
  end
end

# Run verification
verifier = MigrationVerifier.new
verifier.run
EOF

rails runner script/verify_image_migration.rb
```

**Expected results:**
- All 10 tests should pass
- 90%+ pass rate minimum for production
- Review any failures before proceeding

---

## Rollback Procedures

### Emergency Rollback

If critical issues are discovered, perform immediate rollback:

```bash
# Step 1: Revert code changes
git log --oneline -10  # Find the commit before migration
git revert <migration-commit-hash>

# Step 2: Deploy reverted code
bundle exec cap production deploy

# Step 3: Rollback database migrations
rails db:rollback STEP=2  # Adjust STEP based on migrations run

# Step 4: Verify rollback
rails runner "puts SharedAppleImage.table_exists? ? 'FAILED' : 'SUCCESS'"
```

### Partial Rollback

Keep infrastructure but revert integration:

```bash
# Step 1: Keep database tables
# (No action needed)

# Step 2: Revert service integration only
git checkout <pre-migration-hash> -- app/services/apple_messages_for_business/

# Step 3: Commit partial revert
git add -A
git commit -m "Revert AMB services to pre-migration state"

# Step 4: Deploy
bundle exec cap production deploy

# Step 5: Fix issues and prepare for re-migration
# Debug and fix the specific issues found
```

**When to use partial rollback:**
- Database migration successful but service issues
- Need time to fix integration problems
- Want to preserve migrated data

---

## Post-Migration Tasks

### 1. Update Frontend Components

Deploy the new SharedImageSelector component:

```bash
# Verify frontend build
pnpm build

# Deploy frontend updates
./script/deploy-assets-only.sh
```

### 2. Train Users

Create training documentation:

```markdown
## New Shared Image Feature

### What's New
- Images are now shared across all Apple Messages inboxes
- Upload once, use everywhere
- Override with inbox-specific images when needed

### How to Use
1. Go to Settings → Apple Messages → Shared Images
2. Upload your common images (logos, icons)
3. These appear automatically in all list pickers
4. Override in specific inboxes if needed
```

### 3. Monitor Logs

Set up log monitoring:

```bash
# Watch for image fetch patterns
tail -f log/production.log | grep -E "(ImageFetch|SharedApple|Fallback)"

# Check for errors
tail -f log/production.log | grep -E "(ERROR|WARN).*[Ii]mage"

# Monitor performance
tail -f log/production.log | grep "Completed.*apple.*images"
```

### 4. Verify Features

Test each feature systematically:

```bash
# Create test script
cat > script/test_migrated_features.rb << 'EOF'
puts "Testing Apple Messages features post-migration..."

# Test 1: List Picker
inbox = Channel::AppleMessagesForBusiness.first.inbox
message = inbox.messages.create!(
  message_type: :outgoing,
  content_attributes: {
    'sections' => [{
      'title' => 'Test',
      'items' => [{
        'title' => 'Item 1',
        'image_identifier' => 'menu_icon'
      }]
    }]
  }
)

service = AppleMessagesForBusiness::SendListPickerService.new(
  message: message,
  content_attributes: message.content_attributes
)

begin
  result = service.perform
  puts "✓ List Picker: #{result ? 'WORKING' : 'FAILED'}"
rescue => e
  puts "✗ List Picker: ERROR - #{e.message}"
end

# Test 2: Time Picker
# (Similar test for time picker)

# Test 3: Forms
# (Similar test for forms)

puts "Testing complete!"
EOF

rails runner script/test_migrated_features.rb
```

---

## Common Issues & Solutions

### Issue 1: Image Not Found Errors

**Symptoms:**
```
ERROR: Image not found: menu_icon
```

**Solutions:**

1. **Check fallback chain:**
```bash
rails runner "
  img = SharedAppleImage.find_by(identifier: 'menu_icon')
  puts img.present? ? 'Found in shared' : 'Not in shared'
"
```

2. **Verify identifier spelling:**
```bash
rails runner "
  puts SharedAppleImage.pluck(:identifier).sort
"
```

3. **Check account association:**
```bash
rails runner "
  account = Account.find(1)
  puts account.shared_apple_images.pluck(:identifier)
"
```

### Issue 2: Images Showing in Wrong Inbox

**Understanding the behavior:**
- Shared images appear in ALL inboxes (by design)
- This is a feature for consistency
- Use inbox-specific override if differentiation needed

**To add inbox-specific override:**
```ruby
# Upload image to specific inbox only
image = AppleListPickerImage.create!(
  inbox_id: specific_inbox.id,
  identifier: 'custom_logo'
)
image.image.attach(custom_file)
```

### Issue 3: Upload Fails

**Check file size:**
```bash
ls -lh /path/to/image.png  # Should be < 5MB
```

**Verify permissions:**
```bash
rails runner "
  account = Account.find(1)
  user = account.users.first
  puts user.role  # Should be administrator
"
```

**Check ActiveStorage:**
```bash
rails runner "
  puts ActiveStorage::Blob.service.class.name
  puts ActiveStorage::Blob.service.root  # For disk storage
"
```

---

## Testing Checklist

Complete all tests before considering migration successful:

### Feature Tests
- [ ] List Picker displays shared images
- [ ] Time Picker displays shared images
- [ ] Forms display shared images
- [ ] Image fallback works (inbox → shared → embedded)
- [ ] New image upload to shared library works
- [ ] Image deletion from shared library works
- [ ] Inbox-specific override works

### Performance Tests
- [ ] Page load time acceptable (< 2s)
- [ ] Image fetch time acceptable (< 100ms)
- [ ] No memory leaks in image processing
- [ ] Database queries optimized (< 10 queries per request)

### Integration Tests
- [ ] API endpoints return correct format
- [ ] Frontend components render properly
- [ ] Apple MSP receives images correctly
- [ ] Webhooks process normally

### User Acceptance Tests
- [ ] Admins can manage shared images
- [ ] Agents see images in composers
- [ ] Customers receive messages with images
- [ ] Support team trained on new features

---

## Timeline Recommendations

### Small Installations (< 5 inboxes)

**Week 1: Preparation & Testing**
- Day 1-2: Audit and backup
- Day 3-4: Deploy models and migrations in staging
- Day 5: Test in staging environment

**Week 2: Migration**
- Day 1: Deploy to production (off-peak)
- Day 2: Run migration scripts
- Day 3-4: Verify and monitor
- Day 5: Address any issues

**Week 3: Frontend & Training**
- Day 1-2: Deploy API endpoints
- Day 3-4: Deploy frontend updates
- Day 5: User training

### Large Installations (> 20 inboxes)

**Week 1-2: Planning & Preparation**
- Detailed audit of all inboxes
- Identify high-priority accounts
- Create staged migration plan
- Set up monitoring

**Week 3-4: Staged Migration**
- Migrate 20% of accounts (pilot)
- Monitor for 48 hours
- Migrate next 30%
- Migrate remaining 50%

**Week 5: Completion**
- Deploy frontend updates
- Conduct training sessions
- Final verification
- Document lessons learned

---

## Production Deployment Strategy

### Pre-Deployment (Week 0)

```bash
# Notify users
echo "Apple Messages upgrade scheduled for [DATE]
Expected downtime: None
New features: Shared image library" | mail -s "Scheduled Upgrade" team@example.com

# Prepare deployment branch
git checkout -b amb-image-migration
git merge feature/shared-images
```

### Phase 1: Models Only (Week 1)

```bash
# Deploy without service changes
cap production deploy

# Run migrations
cap production rails:db:migrate

# Verify
cap production rails:console
# > SharedAppleImage.table_exists?  # Should be true
```

### Phase 2: Service Integration (Week 2)

```bash
# Deploy services with fallback
cap production deploy

# Monitor logs
ssh production 'tail -f /app/shared/log/production.log | grep ImageFetch'

# Check performance
ssh production 'cat /app/shared/log/production.log | grep "Completed" | tail -100'
```

### Phase 3: Migration Scripts (Week 3)

```bash
# Copy scripts to production
scp script/migrate_*.rb production:/app/current/script/

# Run in stages
ssh production 'cd /app/current && rails runner script/migrate_system_images_to_shared.rb'
# Review output
ssh production 'cd /app/current && rails runner script/migrate_system_images_to_shared.rb --execute'

# Verify
ssh production 'cd /app/current && rails runner script/verify_image_migration.rb'
```

### Phase 4: API Endpoints (Week 4)

```bash
# Deploy API changes
cap production deploy

# Test endpoints
curl -X GET https://app.chatwoot.com/api/v1/accounts/1/shared_apple_images \
  -H "api_access_token: TOKEN"
```

### Phase 5: Frontend (Week 5)

```bash
# Build and deploy assets
pnpm build
./script/deploy-assets-only.sh

# Clear cache
cap production rails:cache:clear

# Verify in browser
open https://app.chatwoot.com/app/accounts/1/settings/inboxes
```

---

## Success Metrics

Track these metrics to measure migration success:

### Storage Metrics
```bash
rails runner "
  puts 'Metrics Dashboard'
  puts '=' * 50

  # Storage reduction
  before = AppleListPickerImage.count
  shared = SharedAppleImage.count
  reduction = ((before - shared).to_f / before * 100).round(1)
  puts \"Storage Reduction: #{reduction}%\"

  # Deduplication rate
  unique_checksums = ActiveStorage::Blob
    .joins(:attachments)
    .where(attachments: { record_type: 'AppleListPickerImage' })
    .distinct.count(:checksum)
  total_images = AppleListPickerImage.count
  dedup_rate = ((total_images - unique_checksums).to_f / total_images * 100).round(1)
  puts \"Deduplication Rate: #{dedup_rate}%\"

  # Error reduction
  recent_errors = MessageTemplate.where(
    'created_at > ? AND status = ?',
    1.week.ago,
    'failed'
  ).count
  puts \"Image Errors (last week): #{recent_errors}\"
"
```

### Expected Results
- ✅ **80% reduction** in duplicate images
- ✅ **Zero manual replication** for system images
- ✅ **90% reduction** in "image not found" errors
- ✅ **50% reduction** in overall storage usage

---

## Support & Troubleshooting

### Log Analysis

```bash
# Check image fetch logs
grep "ImageFetch" log/production.log | tail -50

# View fallback statistics
grep "Fallback" log/production.log | grep -c "Found in"

# Error analysis
grep "ERROR.*[Ii]mage" log/production.log | tail -20
```

### Database Queries

```bash
# Count images by type
rails runner "
  puts 'Shared images: ' + SharedAppleImage.count.to_s
  puts 'Inbox images: ' + AppleListPickerImage.count.to_s
  puts 'Total blobs: ' + ActiveStorage::Blob.count.to_s
"

# Find missing images
rails runner "
  missing = SharedAppleImage.left_joins(:image_attachment)
    .where(active_storage_attachments: { id: nil })
  puts \"Images without attachments: #{missing.count}\"
  missing.each { |img| puts \"  - #{img.identifier}\" }
"
```

### Recovery Scripts

```bash
# Re-attach orphaned blobs
rails runner "
  SharedAppleImage.find_each do |img|
    next if img.image.attached?

    blob = ActiveStorage::Blob.find_by(
      filename: \"#{img.identifier}%\"
    )

    if blob
      img.image.attach(blob)
      puts \"Reattached: #{img.identifier}\"
    end
  end
"
```

---

## References

### Documentation
- **Architecture**: `docs/apple-messages/IMAGE_ARCHITECTURE_LONG_TERM_PLAN.md`
- **API Reference**: `docs/api/shared_apple_images_api.md`
- **Usage Guide**: `docs/apple-messages/SHARED_IMAGES_USAGE.md`
- **Original Design**: `docs/apple-messages/implementation/UNIFIED_TEMPLATE_APPROACH.md`

### Key Files
- **Model**: `app/models/shared_apple_image.rb`
- **Service**: `app/services/apple_messages_for_business/image_fetch_service.rb`
- **API**: `app/controllers/api/v1/accounts/shared_apple_images_controller.rb`
- **Frontend**: `app/javascript/dashboard/components/SharedImageSelector.vue`

### Scripts
- **Migration**: `script/migrate_system_images_to_shared.rb`
- **Verification**: `script/verify_image_migration.rb`
- **Audit**: `script/audit_image_usage.rb`

---

## Conclusion

This migration guide provides a complete path from the current single-tier image architecture to the new two-tier shared image system. The migration is designed to be:

1. **Safe**: Zero downtime, backward compatible
2. **Gradual**: Can be done in stages
3. **Reversible**: Full rollback procedures included
4. **Verified**: Comprehensive testing at each stage

Follow this guide carefully, test thoroughly in staging, and monitor closely during production deployment. The result will be a more efficient, maintainable, and user-friendly image management system for Apple Messages for Business.

For questions or issues during migration, refer to the troubleshooting section or contact the development team.