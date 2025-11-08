#!/usr/bin/env ruby
# frozen_string_literal: true

# Script to fix template 343 - add missing content field for BotRendererService
# Usage: rails runner script/fix_template_343_add_title.rb

template = MessageTemplate.find(343)

puts "Fixing template: #{template.name} (ID: #{template.id})"

# Get current metadata
metadata = template.metadata
apple_content = metadata['apple_message_content']

if apple_content.nil?
  puts '❌ ERROR: No apple_message_content found'
  exit 1
end

content_attrs = apple_content['content_attributes']

if content_attrs.nil?
  puts '❌ ERROR: No content_attributes found'
  exit 1
end

# FIX 1: Add 'content' field at apple_message_content level
# This is used by BotRendererService line 92: content: apple_content['content'] || ''
apple_content['content'] = 'Guitar Information Form'
puts "✅ Added 'content' field to apple_message_content"

# FIX 2: Add title and description at content_attributes level
# These are used for the form display
content_attrs['title'] = 'Guitar Information Form'
content_attrs['description'] = 'Please fill out your guitar details'
puts "✅ Added 'title' and 'description' to content_attributes"

# Update the template
metadata['apple_message_content'] = apple_content
template.update!(metadata: metadata)

puts '✅ Updated template metadata'

# Also update the content block
content_block = template.content_blocks.find_by(block_type: 'form')
if content_block
  content_block.update!(properties: content_attrs)
  puts '✅ Updated content block'
end

puts "\n📋 Fixed structure:"
puts "   apple_message_content.content: #{apple_content['content']}"
puts "   content_attributes.title: #{content_attrs['title']}"
puts "   content_attributes.description: #{content_attrs['description']}"
puts "   pages: #{content_attrs['pages']&.length || 0}"
puts "   received_message: #{content_attrs['received_message'].present? ? '✅' : '❌'}"
puts "   reply_message: #{content_attrs['reply_message'].present? ? '✅' : '❌'}"

puts "\n✨ Template fixed! The message will now have:"
puts "   - content: '#{apple_content['content']}' (prevents 'no content' error)"
puts "   - content_type: 'apple_form'"
puts '   - content_attributes: (form structure)'
puts "\n🎸 Try sending again via n8n!"
