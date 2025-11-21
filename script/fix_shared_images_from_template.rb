#!/usr/bin/env ruby
# frozen_string_literal: true

# Fix SharedAppleImage records by extracting correct images from template 355

puts '=' * 80
puts 'Fix SharedAppleImage 1-13 Using Template 355 Images'
puts '=' * 80
puts ''

# Check both ARGV and ENV for DRY_RUN parameter
dry_run_from_argv = ARGV.any? { |arg| arg == 'DRY_RUN=false' || arg == '--execute' }
dry_run_from_env = ENV['DRY_RUN'] == 'false'
DRY_RUN = !(dry_run_from_argv || dry_run_from_env)

puts "Mode: #{DRY_RUN ? 'DRY RUN (preview only)' : 'EXECUTE (will update SharedAppleImage)'}"
puts ''

# Get template 355
template = MessageTemplate.find(355)
puts "Template: #{template.name}"
puts ''

# Use TemplateFacade to load template data with images
facade = AppleMessagesForBusiness::TemplateFacade.new(template)
data = facade.load_data_with_images('list_picker')

if data['images'].blank?
  puts '❌ No images found in template 355'
  puts '   Cannot proceed with fix'
  exit 1
end

puts "Found #{data['images'].length} images in template 355"
puts ''

# Filter to only 1-13
target_identifiers = %w[1 2 3 4 5 6 7 8 9 10 11 12 13]
template_images = data['images'].select { |img| target_identifiers.include?(img['identifier']) }

puts 'Template images for identifiers 1-13:'
template_images.each do |img|
  size_kb = (img['data'].length * 3 / 4 / 1024.0).round(2) # Base64 to bytes approximation
  puts "  #{img['identifier']}: #{size_kb} KB - #{img['description']}"
end

puts ''
puts '=' * 80
puts 'Updating SharedAppleImage Records'
puts '=' * 80
puts ''

updated_count = 0
error_count = 0

template_images.each do |img_data|
  identifier = img_data['identifier']

  # Find SharedAppleImage record
  shared_img = SharedAppleImage.find_by(account_id: 1, identifier: identifier)

  unless shared_img
    puts "⚠️  SharedAppleImage not found for identifier: #{identifier}"
    error_count += 1
    next
  end

  if DRY_RUN
    old_size = shared_img.image.byte_size if shared_img.image.attached?
    new_size = (img_data['data'].length * 3 / 4) # Base64 to bytes
    puts "  [DRY RUN] Would update #{identifier}:"
    puts "    Old size: #{(old_size / 1024.0).round(2)} KB"
    puts "    New size: #{(new_size / 1024.0).round(2)} KB"
    updated_count += 1
  else
    begin
      # Decode base64 image data
      decoded_data = Base64.strict_decode64(img_data['data'])

      # Determine content type
      content_type = if decoded_data[0..3] == "\x89PNG"
                       'image/png'
                     elsif decoded_data[0..1] == "\xFF\xD8"
                       'image/jpeg'
                     else
                       'image/png'
                     end

      # Purge old attachment
      shared_img.image.purge if shared_img.image.attached?

      # Attach new image
      shared_img.image.attach(
        io: StringIO.new(decoded_data),
        filename: identifier,
        content_type: content_type
      )

      # Update description if present
      shared_img.description = img_data['description'] if img_data['description'].present?

      # Update metadata
      shared_img.metadata = (shared_img.metadata || {}).merge(
        'fixed_from_template' => true,
        'fix_date' => Time.current.iso8601,
        'fix_source' => 'template_355'
      )

      shared_img.save!

      new_size = shared_img.image.byte_size
      puts "  ✅ Updated #{identifier}: #{(new_size / 1024.0).round(2)} KB"
      updated_count += 1
    rescue StandardError => e
      puts "  ❌ Error updating #{identifier}: #{e.message}"
      error_count += 1
    end
  end
end

puts ''
puts '=' * 80
puts 'Summary'
puts '=' * 80
puts "  #{DRY_RUN ? 'Would update' : 'Updated'}: #{updated_count}"
puts "  Errors: #{error_count}"
puts ''

if DRY_RUN
  puts '🔍 This was a DRY RUN - no changes were made.'
  puts 'To execute, run: rails runner script/fix_shared_images_from_template.rb DRY_RUN=false'
else
  puts '✅ Fix complete!'
  puts ''
  puts 'SharedAppleImage now has the correct numbered icon images.'
  puts 'Template 355 should now send the correct images!'
end

puts '=' * 80
