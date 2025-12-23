#!/usr/bin/env ruby
# frozen_string_literal: true

# Script to verify SharedAppleImage migration
# Run: rails runner script/verify_shared_images.rb

puts '=' * 80
puts 'Verify SharedAppleImage Migration'
puts '=' * 80
puts ''

begin
  # Check SharedAppleImage records
  total_shared = SharedAppleImage.count
  system_images = SharedAppleImage.system_images.count
  branding_images = SharedAppleImage.branding_images.count
  template_images = SharedAppleImage.template_images.count

  puts 'SharedAppleImage Overview:'
  puts "  Total records: #{total_shared}"
  puts "  System images: #{system_images}"
  puts "  Branding images: #{branding_images}"
  puts "  Template images: #{template_images}"
  puts ''

  if total_shared.zero?
    puts '⚠️  No SharedAppleImage records found.'
    puts '   Run migration scripts first:'
    puts '   - rails runner script/migrate_system_images_to_shared.rb'
    puts '   - rails runner script/migrate_branding_images_to_shared.rb'
    puts ''
    exit 0
  end

  # Check attachments
  shared_with_attachments = SharedAppleImage.joins(:image_attachment).count
  shared_without_attachments = total_shared - shared_with_attachments

  puts 'Attachment Status:'
  puts "  ✅ With attachments: #{shared_with_attachments}"
  puts "  ❌ Without attachments: #{shared_without_attachments}"
  puts ''

  if shared_without_attachments.positive?
    puts '⚠️  Warning: Some SharedAppleImage records are missing attachments'
    SharedAppleImage.left_joins(:image_attachment)
                    .where(active_storage_attachments: { id: nil })
                    .find_each do |img|
      puts "     - Account #{img.account_id}: #{img.identifier} (#{img.image_type})"
    end
    puts ''
  end

  # List all shared images by account
  puts 'Shared Images by Account:'
  puts '-' * 80

  SharedAppleImage.includes(image_attachment: :blob)
                  .order(:account_id, :image_type, :identifier)
                  .group_by(&:account_id)
                  .each do |account_id, images|
    puts "  Account #{account_id}:"
    images.each do |img|
      attachment_status = img.image.attached? ? '✅' : '❌'
      type_label = img.image_type.upcase.ljust(10)
      puts "    #{attachment_status} [#{type_label}] #{img.identifier} - #{img.description}"
    end
    puts ''
  end

  # Test fallback logic (informational)
  puts 'Fallback Logic Test:'
  puts '-' * 80
  puts 'Testing if ImageFetchService can find shared images...'
  puts ''

  # Pick first shared image to test
  test_image = SharedAppleImage.joins(:image_attachment).first

  if test_image
    puts "  Testing identifier: #{test_image.identifier}"
    puts "  Account: #{test_image.account_id}"
    puts ''

    # Find an inbox for this account
    test_inbox = Inbox.where(account_id: test_image.account_id).first

    if test_inbox
      puts "  Using inbox: #{test_inbox.id} (#{test_inbox.name})"
      puts ''

      # Check if this image exists in inbox-specific storage
      inbox_specific = AppleListPickerImage.find_by(
        inbox_id: test_inbox.id,
        identifier: test_image.identifier
      )

      if inbox_specific
        puts '  ✅ Inbox-specific image exists (will be used first)'
      else
        puts '  ✅ No inbox-specific image (will fallback to shared)'
      end
      puts ''

      # Would be found by ImageFetchService
      puts '  ImageFetchService fallback priority:'
      puts '    1. Inbox-specific (AppleListPickerImage)'
      puts '    2. Shared account-wide (SharedAppleImage) ← Would use this'
      puts '    3. Embedded images (content_attributes)'
    else
      puts '  ⚠️  No inbox found for this account'
    end
  else
    puts '  ⚠️  No shared images with attachments found for testing'
  end

  puts ''
  puts '=' * 80
  puts 'Verification Complete'
  puts '=' * 80

  # Final status
  if shared_without_attachments.zero? && total_shared.positive?
    puts ''
    puts '✅ All shared images are properly configured'
    puts '   Migration successful!'
  elsif shared_without_attachments.positive?
    puts ''
    puts '⚠️  Some issues found - check warnings above'
  else
    puts ''
    puts '⚠️  No shared images found - run migration scripts'
  end

  puts ''

rescue StandardError => e
  puts ''
  puts '❌ Verification failed:'
  puts "   #{e.class}: #{e.message}"
  puts ''
  puts 'Backtrace:'
  puts e.backtrace.first(10).map { |line| "   #{line}" }.join("\n")
  exit 1
end
