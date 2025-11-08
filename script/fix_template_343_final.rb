#!/usr/bin/env ruby
# frozen_string_literal: true

# Script to PROPERLY fix template 343 for form detection
# Usage: rails runner script/fix_template_343_final.rb

template = MessageTemplate.find(343)

puts '=' * 80
puts "🔧 Final Fix for Template: #{template.name} (ID: #{template.id})"
puts '=' * 80

# Get current metadata
metadata = template.metadata
apple_content = metadata['apple_message_content']

if apple_content.nil?
  puts '❌ ERROR: No apple_message_content found'
  exit 1
end

content_attrs = apple_content['content_attributes'] || {}

puts "\n📋 Current structure:"
puts "   Keys: #{content_attrs.keys.inspect}"
puts "   Has 'form' key: #{content_attrs['form'].present?}"
puts "   Has 'pages' at root: #{content_attrs['pages'].present?}"

# FIX 1: Add 'content' field for BotRendererService
apple_content['content'] = 'Guitar Information Form'
puts "\n✅ FIX 1: Added 'content' field to apple_message_content"

# FIX 2: Wrap everything in 'form' key for content type detection
# The detector (line 214) checks: attrs['form'].present?
if content_attrs['pages'].present? && !content_attrs['form'].present?
  # Move pages, title, description, etc. under 'form' key
  form_data = {
    'title' => content_attrs['title'] || 'Guitar Information Form',
    'description' => content_attrs['description'] || 'Please fill out your guitar details',
    'show_summary' => content_attrs['show_summary'] || true,
    'pages' => content_attrs['pages']
  }

  # Keep received_message and reply_message at root level (they're not part of form structure)
  new_content_attrs = {
    'form' => form_data,
    'received_message' => content_attrs['received_message'],
    'reply_message' => content_attrs['reply_message']
  }

  apple_content['content_attributes'] = new_content_attrs
  puts "✅ FIX 2: Wrapped pages in 'form' key for content type detection"
  puts "   form.title: #{form_data['title']}"
  puts "   form.pages: #{form_data['pages'].length}"
end

# Update template
metadata['apple_message_content'] = apple_content
template.update!(metadata: metadata)
puts "\n✅ Updated template metadata"

# Update content block
content_block = template.content_blocks.find_by(block_type: 'form')
if content_block
  content_block.update!(properties: apple_content['content_attributes'])
  puts '✅ Updated content block'
end

puts "\n📊 Final structure:"
final_attrs = apple_content['content_attributes']
puts "   apple_message_content.content: '#{apple_content['content']}'"
puts "   content_attributes keys: #{final_attrs.keys.inspect}"
puts "   content_attributes.form present: #{final_attrs['form'].present? ? '✅' : '❌'}"

if final_attrs['form']
  puts "   content_attributes.form.title: '#{final_attrs['form']['title']}'"
  puts "   content_attributes.form.pages: #{final_attrs['form']['pages']&.length || 0}"
end

puts "   content_attributes.received_message: #{final_attrs['received_message'].present? ? '✅' : '❌'}"
puts "   content_attributes.reply_message: #{final_attrs['reply_message'].present? ? '✅' : '❌'}"

puts "\n" + ('=' * 80)
puts '✨ Template fixed! Now BotRendererService will:'
puts "   1. Detect content_type as 'apple_form' (line 214: attrs['form'].present?)"
puts "   2. Return content: 'Guitar Information Form'"
puts '   3. SendMessageService will call send_interactive_message (line 26-27)'
puts "\n🎸 Try sending from n8n again!"
puts '=' * 80
