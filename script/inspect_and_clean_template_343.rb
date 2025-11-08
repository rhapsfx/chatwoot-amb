#!/usr/bin/env ruby
# frozen_string_literal: true

# Script to inspect and clean template 343 content_attributes
# Usage: rails runner script/inspect_and_clean_template_343.rb

template = MessageTemplate.find(343)

puts '=' * 80
puts "🔍 Inspecting Template: #{template.name} (ID: #{template.id})"
puts '=' * 80

metadata = template.metadata
apple_content = metadata['apple_message_content']
content_attrs = apple_content['content_attributes']

puts "\n📋 Current ROOT LEVEL keys in content_attributes:"
content_attrs.keys.sort.each do |key|
  value_preview = content_attrs[key].is_a?(Hash) || content_attrs[key].is_a?(Array) ? "(#{content_attrs[key].class})" : content_attrs[key].inspect
  puts "   #{key}: #{value_preview.to_s.truncate(60)}"
end

puts "\n🧹 Cleaning up invalid keys..."

# These keys should be INSIDE received_message/reply_message, not at root
invalid_root_keys = %w[
  received_title received_subtitle received_image_identifier
  reply_title reply_subtitle reply_image_identifier
  received_image_title received_image_subtitle
  reply_image_title reply_image_subtitle
]

removed_keys = []
invalid_root_keys.each do |key|
  if content_attrs.key?(key)
    content_attrs.delete(key)
    removed_keys << key
  end
end

if removed_keys.any?
  puts "   ✅ Removed #{removed_keys.length} invalid keys: #{removed_keys.inspect}"
else
  puts '   ℹ️  No invalid root-level keys found'
end

# Ensure required structure
content_attrs['title'] ||= 'Guitar Information Form'
content_attrs['description'] ||= 'Please fill out your guitar details'
content_attrs['show_summary'] = true if content_attrs['show_summary'].nil?

# Ensure received_message and reply_message have proper structure
if content_attrs['received_message'].blank?
  content_attrs['received_message'] = {
    'title' => 'Guitar Information',
    'subtitle' => 'Tap to provide your guitar details',
    'style' => 'small',
    'image_identifier' => '59'
  }
  puts '   ✅ Created received_message structure'
end

if content_attrs['reply_message'].blank?
  content_attrs['reply_message'] = {
    'title' => 'Thank You!',
    'subtitle' => 'Your information has been submitted',
    'style' => 'small',
    'image_identifier' => '59'
  }
  puts '   ✅ Created reply_message structure'
end

# Verify pages structure
if content_attrs['pages'].blank?
  puts '   ❌ ERROR: No pages found!'
  exit 1
end

puts "   ✅ Pages structure verified (#{content_attrs['pages'].length} pages)"

# Update template
apple_content['content'] = 'Guitar Information Form'
apple_content['content_attributes'] = content_attrs
metadata['apple_message_content'] = apple_content
template.update!(metadata: metadata)

puts "\n✅ Updated template metadata"

# Update content block
content_block = template.content_blocks.find_by(block_type: 'form')
if content_block
  content_block.update!(properties: content_attrs)
  puts '✅ Updated content block'
end

puts "\n📊 Final CLEAN structure:"
puts '   apple_message_content:'
puts "      content: '#{apple_content['content']}'"
puts "      content_type: '#{apple_content['content_type']}'"
puts "\n   content_attributes (ROOT LEVEL - CLEAN):"
puts "      Keys: #{content_attrs.keys.sort.inspect}"
puts "\n   Required fields:"
puts "      ✅ title: '#{content_attrs['title']}'"
puts "      ✅ description: '#{content_attrs['description']}'"
puts "      ✅ show_summary: #{content_attrs['show_summary']}"
puts "      ✅ pages: #{content_attrs['pages'].length} pages"
puts "      ✅ received_message: #{content_attrs['received_message'].keys.inspect}"
puts "      ✅ reply_message: #{content_attrs['reply_message'].keys.inspect}"

puts "\n" + ('=' * 80)
puts '✨ Template cleaned and ready!'
puts '🎸 Try sending from n8n now - it should work!'
puts '=' * 80
