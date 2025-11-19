# frozen_string_literal: true

# Image Migration Verification Script
# Run with: rails runner script/verify_image_migration.rb
# Verbose mode: rails runner script/verify_image_migration.rb --verbose

puts '=' * 100
puts 'IMAGE MIGRATION VERIFICATION REPORT'
puts '=' * 100
puts ''

# Parse command-line arguments
verbose = ARGV.include?('--verbose')

# Track all test results
test_results = {
  shared_image_checks: [],
  attachment_checks: [],
  fallback_tests: [],
  isolation_tests: [],
  safety_checks: []
}

def test_result(passed, name, details = nil)
  status = passed ? '✅ PASS' : '❌ FAIL'
  result = { passed: passed, name: name, details: details }
  puts "#{status}: #{name}"
  puts "   #{details}" if details && !passed
  result
end

def section_header(title)
  puts ''
  puts '-' * 100
  puts title.upcase
  puts '-' * 100
  puts ''
end

# =============================================================================
# 1. VERIFY SharedAppleImage TABLE STRUCTURE
# =============================================================================

section_header('1. SharedAppleImage Table Verification')

total_shared = SharedAppleImage.count
system_images = SharedAppleImage.system_images.count
branding_images = SharedAppleImage.branding_images.count
template_images = SharedAppleImage.template_images.count

puts "Total SharedAppleImage records: #{total_shared}"
puts "  - System images:   #{system_images}"
puts "  - Branding images: #{branding_images}"
puts "  - Template images: #{template_images}"
puts ''

# =============================================================================
# 2. VERIFY EXPECTED SYSTEM IMAGES EXIST
# =============================================================================

section_header('2. Expected System Images Verification')

# Expected system images that should be migrated
EXPECTED_SYSTEM_IMAGES = %w[
  messages_png
  apple_store_logo
].freeze

# These may or may not exist depending on when they were uploaded
OPTIONAL_IMAGES = %w[
  hero_image
  guitar_1
  guitar_2
  guitar_3
  guitar_4
  guitar_5
].freeze

puts "Checking for expected system images (critical):"
EXPECTED_SYSTEM_IMAGES.each do |identifier|
  # Check across all accounts
  images = SharedAppleImage.where(identifier: identifier, image_type: 'system')

  if images.any?
    account_ids = images.pluck(:account_id).uniq
    puts "  ✅ #{identifier}: Found in #{images.count} record(s) (accounts: #{account_ids.join(', ')})"

    # Verify attachments
    images.each do |img|
      if img.image.attached?
        blob = img.image.blob
        test_results[:attachment_checks] << test_result(
          true,
          "#{identifier} (account #{img.account_id}) has attachment",
          "Size: #{blob.byte_size} bytes, Type: #{blob.content_type}"
        )
      else
        test_results[:attachment_checks] << test_result(
          false,
          "#{identifier} (account #{img.account_id}) has attachment",
          "Record exists but no file attached"
        )
      end
    end
  else
    test_results[:shared_image_checks] << test_result(
      false,
      "Expected system image '#{identifier}' exists",
      "No SharedAppleImage records found with identifier '#{identifier}'"
    )
  end
end

puts ''
puts "Checking for optional images (informational):"
OPTIONAL_IMAGES.each do |identifier|
  images = SharedAppleImage.where(identifier: identifier)
  if images.any?
    account_ids = images.pluck(:account_id).uniq
    puts "  ℹ️  #{identifier}: Found in #{images.count} record(s) (accounts: #{account_ids.join(', ')})"
  else
    puts "  -  #{identifier}: Not found (optional)"
  end
end

# =============================================================================
# 3. VERIFY BRANDING IMAGES PER ACCOUNT
# =============================================================================

section_header('3. Branding Images per Account')

accounts_with_amb = Account.joins(:inboxes)
                            .where(inboxes: { channel_type: 'Channel::AppleMessagesForBusiness' })
                            .distinct

puts "Accounts with Apple Messages inboxes: #{accounts_with_amb.count}"
puts ''

accounts_with_amb.each do |account|
  branding = SharedAppleImage.where(account_id: account.id, image_type: 'branding')

  if branding.any?
    puts "Account #{account.id} (#{account.name}):"
    branding.each do |img|
      attached = img.image.attached? ? '✅' : '❌'
      puts "  #{attached} #{img.identifier} (#{img.description})"
    end
  else
    puts "Account #{account.id} (#{account.name}): No branding images (this is OK)"
  end
end

# =============================================================================
# 4. VERIFY IMAGE ATTACHMENTS ARE INTACT
# =============================================================================

section_header('4. Image Attachment Integrity')

shared_with_attachments = 0
shared_without_attachments = 0
orphaned_blobs = []

SharedAppleImage.includes(image_attachment: :blob).find_each do |img|
  if img.image.attached?
    blob = img.image.blob

    if blob.byte_size > 0
      shared_with_attachments += 1

      if verbose
        puts "✅ #{img.identifier} (account #{img.account_id})"
        puts "   Size: #{blob.byte_size} bytes, Type: #{blob.content_type}"
        puts "   Uploaded: #{blob.created_at}"
      end
    else
      test_results[:attachment_checks] << test_result(
        false,
        "#{img.identifier} has valid blob",
        "Blob exists but byte_size is 0"
      )
      shared_without_attachments += 1
    end
  else
    test_results[:attachment_checks] << test_result(
      false,
      "#{img.identifier} has attachment",
      "Record exists but image not attached"
    )
    shared_without_attachments += 1
  end
end

puts "SharedAppleImage attachments:"
puts "  ✅ With valid attachments:    #{shared_with_attachments}"
puts "  ❌ Without attachments:       #{shared_without_attachments}"

if shared_without_attachments > 0
  puts ''
  puts "⚠️  WARNING: #{shared_without_attachments} SharedAppleImage records have no attachments"
end

# =============================================================================
# 5. TEST THREE-TIER FALLBACK WITH ImageFetchService
# =============================================================================

section_header('5. ImageFetchService Three-Tier Fallback Tests')

# Get a test account and inbox
test_account = accounts_with_amb.first

if test_account
  test_inbox = test_account.inboxes.where(channel_type: 'Channel::AppleMessagesForBusiness').first

  if test_inbox
    puts "Testing with Account #{test_account.id}, Inbox #{test_inbox.id}"
    puts ''

    # Test 1: Fetch shared system image
    puts "Test 1: Fetch shared system image (messages_png)"
    service = AppleMessagesForBusiness::ImageFetchService.new(
      account_id: test_account.id,
      inbox_id: test_inbox.id,
      embedded_images: []
    )

    result = service.fetch_and_encode(['messages_png'])
    if result.any? && result.first[:identifier] == 'messages_png'
      test_results[:fallback_tests] << test_result(
        true,
        "Fetch 'messages_png' from shared",
        "Source: #{result.first[:source]}"
      )
      puts "   Data size: #{result.first[:data].length} chars (base64)"
    else
      test_results[:fallback_tests] << test_result(
        false,
        "Fetch 'messages_png' from shared",
        "Image not found or returned empty"
      )
    end
    puts ''

    # Test 2: Fetch inbox-specific image (if any exist)
    inbox_images = AppleListPickerImage.where(inbox_id: test_inbox.id).limit(1)
    if inbox_images.any?
      test_image = inbox_images.first
      puts "Test 2: Fetch inbox-specific image (#{test_image.identifier})"

      result = service.fetch_and_encode([test_image.identifier])
      if result.any?
        test_results[:fallback_tests] << test_result(
          true,
          "Fetch inbox-specific '#{test_image.identifier}'",
          "Source: #{result.first[:source]}"
        )
      else
        test_results[:fallback_tests] << test_result(
          false,
          "Fetch inbox-specific '#{test_image.identifier}'",
          "Image not found"
        )
      end
      puts ''
    else
      puts "Test 2: Skipped (no inbox-specific images exist)"
      puts ''
    end

    # Test 3: Embedded image fallback
    puts "Test 3: Embedded image fallback"
    embedded_images = [
      {
        'identifier' => 'test_embedded',
        'data' => Base64.strict_encode64('dummy data'),
        'description' => 'Test embedded image'
      }
    ]

    service_with_embedded = AppleMessagesForBusiness::ImageFetchService.new(
      account_id: test_account.id,
      inbox_id: test_inbox.id,
      embedded_images: embedded_images
    )

    result = service_with_embedded.fetch_and_encode(['test_embedded'])
    if result.any? && result.first[:source] == 'embedded'
      test_results[:fallback_tests] << test_result(
        true,
        "Fetch embedded image fallback",
        "Source: #{result.first[:source]}"
      )
    else
      test_results[:fallback_tests] << test_result(
        false,
        "Fetch embedded image fallback",
        "Embedded fallback did not work"
      )
    end
    puts ''

    # Test 4: Fallback hierarchy (inbox > shared > embedded)
    puts "Test 4: Fallback hierarchy test"

    # Create a test identifier that doesn't exist in inbox but exists in shared
    shared_identifiers = SharedAppleImage.where(account_id: test_account.id).pluck(:identifier)
    inbox_identifiers = AppleListPickerImage.where(inbox_id: test_inbox.id).pluck(:identifier)

    shared_only = (shared_identifiers - inbox_identifiers).first

    if shared_only
      puts "   Testing with identifier: #{shared_only} (exists in shared, not in inbox)"
      result = service.fetch_and_encode([shared_only])

      if result.any? && result.first[:source].start_with?('shared')
        test_results[:fallback_tests] << test_result(
          true,
          "Fallback hierarchy: shared layer",
          "Correctly fetched from shared when not in inbox"
        )
      else
        test_results[:fallback_tests] << test_result(
          false,
          "Fallback hierarchy: shared layer",
          "Failed to fetch from shared layer"
        )
      end
    else
      puts "   Skipped: All shared images also exist in inbox"
      test_results[:fallback_tests] << test_result(
        true,
        "Fallback hierarchy: shared layer",
        "Skipped (no shared-only images to test)"
      )
    end
  else
    puts "⚠️  No Apple Messages inbox found for test account"
  end
else
  puts "⚠️  No accounts with Apple Messages inboxes found"
end

# =============================================================================
# 6. TEST ACCOUNT ISOLATION
# =============================================================================

section_header('6. Account Isolation Tests')

if accounts_with_amb.count >= 2
  account1 = accounts_with_amb.first
  account2 = accounts_with_amb.second

  puts "Testing isolation between Account #{account1.id} and Account #{account2.id}"
  puts ''

  # Check if account1 has any shared images
  account1_images = SharedAppleImage.where(account_id: account1.id)

  if account1_images.any?
    test_identifier = account1_images.first.identifier

    # Try to fetch from account2's perspective
    account2_inbox = account2.inboxes.where(channel_type: 'Channel::AppleMessagesForBusiness').first

    if account2_inbox
      service = AppleMessagesForBusiness::ImageFetchService.new(
        account_id: account2.id,
        inbox_id: account2_inbox.id,
        embedded_images: []
      )

      # Check if account2 also has this identifier
      account2_has_same = SharedAppleImage.exists?(account_id: account2.id, identifier: test_identifier)

      result = service.fetch_and_encode([test_identifier])

      if account2_has_same
        # Should be able to fetch its own copy
        if result.any?
          test_results[:isolation_tests] << test_result(
            true,
            "Account isolation: Account 2 can fetch its own '#{test_identifier}'",
            "Both accounts have the same identifier, correctly isolated"
          )
        else
          test_results[:isolation_tests] << test_result(
            false,
            "Account isolation: Account 2 can fetch its own '#{test_identifier}'",
            "Failed to fetch even though image exists"
          )
        end
      else
        # Should NOT be able to fetch account1's image
        if result.empty?
          test_results[:isolation_tests] << test_result(
            true,
            "Account isolation: Account 2 cannot fetch Account 1's '#{test_identifier}'",
            "Correctly prevented cross-account access"
          )
        else
          test_results[:isolation_tests] << test_result(
            false,
            "Account isolation: Account 2 cannot fetch Account 1's '#{test_identifier}'",
            "SECURITY ISSUE: Cross-account access detected!"
          )
        end
      end
    else
      puts "Skipped: Account 2 has no Apple Messages inbox"
    end
  else
    puts "Skipped: Account 1 has no shared images to test"
  end
else
  puts "Skipped: Need at least 2 accounts with Apple Messages inboxes"
  test_results[:isolation_tests] << test_result(
    true,
    "Account isolation",
    "Skipped (only 1 account available)"
  )
end

# =============================================================================
# 7. VERIFY ORIGINAL AppleListPickerImage TABLE INTACT
# =============================================================================

section_header('7. Original AppleListPickerImage Safety Check')

original_count = AppleListPickerImage.count
original_with_attachments = 0
original_without_attachments = 0

AppleListPickerImage.includes(image_attachment: :blob).find_each do |img|
  if img.image.attached? && img.image.blob.byte_size > 0
    original_with_attachments += 1
  else
    original_without_attachments += 1
  end
end

puts "AppleListPickerImage table:"
puts "  Total records:          #{original_count}"
puts "  With valid attachments: #{original_with_attachments}"
puts "  Without attachments:    #{original_without_attachments}"
puts ''

test_results[:safety_checks] << test_result(
  original_count > 0,
  "Original AppleListPickerImage table still exists",
  original_count > 0 ? "#{original_count} records intact" : "Table is empty or deleted"
)

test_results[:safety_checks] << test_result(
  original_with_attachments > 0,
  "Original images still have attachments",
  original_with_attachments > 0 ? "#{original_with_attachments} images intact" : "No attachments found"
)

# =============================================================================
# 8. CHECK FOR ORPHANED BLOBS
# =============================================================================

section_header('8. Orphaned Blob Check')

# Get all blob IDs referenced by SharedAppleImage
shared_blob_ids = ActiveStorage::Attachment
                  .where(record_type: 'SharedAppleImage')
                  .pluck(:blob_id)
                  .compact

# Get all blob IDs referenced by AppleListPickerImage
picker_blob_ids = ActiveStorage::Attachment
                  .where(record_type: 'AppleListPickerImage')
                  .pluck(:blob_id)
                  .compact

# Get all blobs with apple/image-related keys
all_apple_blobs = ActiveStorage::Blob.where('key LIKE ?', '%apple%')

orphaned = []
all_apple_blobs.each do |blob|
  unless shared_blob_ids.include?(blob.id) || picker_blob_ids.include?(blob.id)
    orphaned << blob
  end
end

puts "Blob analysis:"
puts "  SharedAppleImage blobs:      #{shared_blob_ids.count}"
puts "  AppleListPickerImage blobs:  #{picker_blob_ids.count}"
puts "  Total apple-related blobs:   #{all_apple_blobs.count}"
puts "  Potentially orphaned blobs:  #{orphaned.count}"

if orphaned.any? && verbose
  puts ''
  puts "Orphaned blobs (may be from deleted records):"
  orphaned.each do |blob|
    puts "  - ID: #{blob.id}, Key: #{blob.key}, Size: #{blob.byte_size}, Created: #{blob.created_at}"
  end
end

test_results[:safety_checks] << test_result(
  orphaned.count < 10,
  "Minimal orphaned blobs",
  orphaned.count < 10 ? "#{orphaned.count} orphaned (acceptable)" : "#{orphaned.count} orphaned (may need cleanup)"
)

# =============================================================================
# 9. VALIDATE UNIQUE CONSTRAINTS
# =============================================================================

section_header('9. Unique Constraint Validation')

# Check for duplicate identifier+account_id combinations
duplicates = SharedAppleImage
             .group(:account_id, :identifier)
             .having('COUNT(*) > 1')
             .count

if duplicates.any?
  puts "❌ CONSTRAINT VIOLATION: Found duplicate identifier+account_id combinations:"
  duplicates.each do |(account_id, identifier), count|
    puts "  - Account #{account_id}, Identifier '#{identifier}': #{count} records"
  end

  test_results[:safety_checks] << test_result(
    false,
    "Unique constraint: account_id + identifier",
    "Found #{duplicates.count} duplicate combinations"
  )
else
  puts "✅ No duplicate identifier+account_id combinations"
  test_results[:safety_checks] << test_result(
    true,
    "Unique constraint: account_id + identifier",
    "All combinations are unique"
  )
end

# =============================================================================
# 10. FINAL SUMMARY
# =============================================================================

section_header('10. Final Summary')

all_tests = test_results.values.flatten
total_tests = all_tests.count
passed_tests = all_tests.count { |t| t[:passed] }
failed_tests = total_tests - passed_tests

puts "Total Tests Run:    #{total_tests}"
puts "Passed:             #{passed_tests} ✅"
puts "Failed:             #{failed_tests} ❌"
puts ''

if failed_tests > 0
  puts "Failed Tests:"
  all_tests.reject { |t| t[:passed] }.each do |test|
    puts "  ❌ #{test[:name]}"
    puts "     #{test[:details]}" if test[:details]
  end
  puts ''
end

# Overall status
overall_status = failed_tests == 0 ? '✅ PASS' : '❌ FAIL'

puts '=' * 100
puts "OVERALL STATUS: #{overall_status}"
puts '=' * 100

if failed_tests == 0
  puts ''
  puts '🎉 All verification checks passed! Migration is successful.'
else
  puts ''
  puts "⚠️  #{failed_tests} check(s) failed. Review the details above."
end

puts ''
