# frozen_string_literal: true

# Export numeric images to temp directory for visual identification
# Run with: rails runner script/export_numeric_images.rb

require 'fileutils'

puts '=' * 80
puts 'Export Numeric Images for Identification'
puts '=' * 80
puts ''

template = MessageTemplate.find_by(id: 366)
inbox_id = template.account.inboxes.where(channel_type: 'Channel::AppleMessagesForBusiness').first&.id

numeric_images = AppleListPickerImage.where(inbox_id: inbox_id)
                                     .where("identifier ~ '^[0-9]+$'")
                                     .order(Arel.sql('CAST(identifier AS INTEGER)'))

# Create export directory
export_dir = Rails.root.join('tmp/exported_menu_images')
FileUtils.mkdir_p(export_dir)

puts "Exporting images to: #{export_dir}"
puts ''

exported_files = []

numeric_images.each do |img|
  next unless img.image.attached?

  blob = img.image.blob

  # Determine file extension from content type
  extension = case blob.content_type
              when 'image/png' then 'png'
              when 'image/jpeg', 'image/jpg' then 'jpg'
              when 'image/svg+xml' then 'svg'
              else 'bin'
              end

  # Export with descriptive filename
  filename = "#{img.identifier}_#{blob.byte_size}bytes.#{extension}"
  filepath = export_dir.join(filename)

  # Download and save
  File.open(filepath, 'wb') do |file|
    blob.download { |chunk| file.write(chunk) }
  end

  exported_files << { id: img.identifier, path: filepath, size: blob.byte_size }
  puts "✅ Exported: #{filename}"
end

puts ''
puts '=' * 80
puts "EXPORTED #{exported_files.count} IMAGES"
puts '=' * 80
puts ''
puts "Location: #{export_dir}"
puts ''
puts 'Next steps:'
puts "1. Open Finder and navigate to: #{export_dir}"
puts '2. View each image to identify which icon it is'
puts '3. Create a mapping list like:'
puts "   '0' => Messages icon (for received message)"
puts "   '1' => list.bullet icon"
puts "   '2' => ARKit icon"
puts '   etc...'
puts ''
puts 'Then we can apply the correct mapping to template 366'
puts ''
