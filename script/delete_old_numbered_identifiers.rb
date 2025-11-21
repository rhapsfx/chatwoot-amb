#!/usr/bin/env ruby
# frozen_string_literal: true

# Delete old numbered identifiers 1-13 from SharedAppleImage
# These have guitar images and are no longer used by template 355

puts '=' * 80
puts 'Delete Old Numbered Identifiers (1-13) from SharedAppleImage'
puts '=' * 80
puts ''

# Check both ARGV and ENV for DRY_RUN parameter
dry_run_from_argv = ARGV.any? { |arg| arg == 'DRY_RUN=false' || arg == '--execute' }
dry_run_from_env = ENV['DRY_RUN'] == 'false'
DRY_RUN = !(dry_run_from_argv || dry_run_from_env)

puts "Mode: #{DRY_RUN ? 'DRY RUN (preview only)' : 'EXECUTE (will DELETE records)'}"
puts ''

old_identifiers = %w[1 2 3 4 5 6 7 8 9 10 11 12 13]

old_images = SharedAppleImage.where(account_id: 1, identifier: old_identifiers)
                             .includes(image_attachment: :blob)

puts "Found #{old_images.count} records to delete:"
old_images.order(:identifier).each do |img|
  size_kb = img.image.attached? ? (img.image.byte_size / 1024.0).round(2) : 0
  puts "  #{img.identifier}: #{size_kb} KB - #{img.description}"
end

puts ''
puts '=' * 80
puts 'Deleting Records'
puts '=' * 80
puts ''

deleted_count = 0

old_images.each do |img|
  if DRY_RUN
    puts "  [DRY RUN] Would delete: #{img.identifier}"
    deleted_count += 1
  else
    begin
      # Purge attachment first
      img.image.purge if img.image.attached?

      # Delete record
      img.destroy!

      puts "  ✅ Deleted: #{img.identifier}"
      deleted_count += 1
    rescue StandardError => e
      puts "  ❌ Error deleting #{img.identifier}: #{e.message}"
    end
  end
end

puts ''
puts '=' * 80
puts 'Summary'
puts '=' * 80
puts "  #{DRY_RUN ? 'Would delete' : 'Deleted'}: #{deleted_count}"
puts ''

if DRY_RUN
  puts '🔍 This was a DRY RUN - no changes were made.'
  puts 'To execute, run: rails runner script/delete_old_numbered_identifiers.rb DRY_RUN=false'
else
  puts '✅ Deletion complete!'
  puts ''
  puts 'Old numbered identifiers (1-13) removed from SharedAppleImage.'
  puts 'Template 355 now only uses summary_ identifiers.'
end

puts '=' * 80
