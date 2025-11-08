#!/usr/bin/env ruby
# frozen_string_literal: true

# Fix AHA19 template image identifiers
# The template was created with database IDs instead of identifiers

t = MessageTemplate.find(341)
attrs = t.metadata['apple_message_content']['content_attributes']

# Map of database ID to correct identifier
id_to_identifier = {
  '32' => 'aha19_0',  # header
  '33' => 'aha19_1',  # item 1
  '34' => 'aha19_2',  # item 2
  '35' => 'aha19_3',  # item 3
  '43' => 'aha19_4',  # item 4 (Apple Pay, reused)
  '36' => 'aha19_5',  # item 5
  '37' => 'aha19_6',  # item 6
  '38' => 'aha19_7',  # item 7
  '44' => 'aha19_8',  # item 8 (reused)
  '39' => 'aha19_10', # item 9
  '40' => 'aha19_11', # item 10
  '41' => 'aha19_12', # item 11
  '42' => 'aha19_13'  # item 12
}

puts 'Updating image identifiers in template 341...'
puts

# Update image_identifier in all items
attrs['sections'].each do |section|
  section['items'].each do |item|
    old_id = item['image_identifier']
    if id_to_identifier[old_id]
      item['image_identifier'] = id_to_identifier[old_id]
      puts "  Updated item '#{item['title']}': #{old_id} -> #{id_to_identifier[old_id]}"
    end
  end
end

# Update received_message if it has image_identifier
if attrs['received_message'] && attrs['received_message']['image_identifier']
  old_id = attrs['received_message']['image_identifier']
  if id_to_identifier[old_id]
    attrs['received_message']['image_identifier'] = id_to_identifier[old_id]
    puts "  Updated received_message: #{old_id} -> #{id_to_identifier[old_id]}"
  end
end

# Update reply_message if it has image_identifier
if attrs['reply_message'] && attrs['reply_message']['image_identifier']
  old_id = attrs['reply_message']['image_identifier']
  if id_to_identifier[old_id]
    attrs['reply_message']['image_identifier'] = id_to_identifier[old_id]
    puts "  Updated reply_message: #{old_id} -> #{id_to_identifier[old_id]}"
  end
end

t.save!
puts
puts '✅ Template updated successfully!'
