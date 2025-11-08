#!/usr/bin/env ruby
# frozen_string_literal: true

# Script to fix template 343 - add content field WITHOUT form wrapper
# Usage: rails runner script/fix_template_343_final_v2.rb

template = MessageTemplate.find(343)

puts '=' * 80
puts "🔧 Final Fix v2 for Template: #{template.name} (ID: #{template.id})"
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

# Remove 'form' wrapper if it exists (from previous fix attempt)
if content_attrs['form'].present? && !content_attrs['pages'].present?
  puts "   Found 'form' wrapper, unwrapping..."
  form_data = content_attrs.delete('form')
  content_attrs['title'] = form_data['title']
  content_attrs['description'] = form_data['description']
  content_attrs['show_summary'] = form_data['show_summary']
  content_attrs['pages'] = form_data['pages']
  puts '   ✅ Unwrapped form data to root level'
end

# FIX 1: Add 'content' field at apple_message_content level
apple_content['content'] = 'Guitar Information Form'
puts "\n✅ FIX 1: Added 'content' field to apple_message_content"

# FIX 2: Ensure title and description at content_attributes root level
content_attrs['title'] ||= 'Guitar Information Form'
content_attrs['description'] ||= 'Please fill out your guitar details'
content_attrs['show_summary'] = true if content_attrs['show_summary'].nil?
puts '✅ FIX 2: Ensured title, description, show_summary at root level'

# Ensure pages structure is correct
if content_attrs['pages'].present?
  puts "✅ Pages structure present (#{content_attrs['pages'].length} pages)"
else
  puts '❌ ERROR: No pages found!'
  exit 1
end

# Update template
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

puts "\n📊 Final structure:"
puts '   apple_message_content:'
puts "      content: '#{apple_content['content']}'"
puts "      content_type: '#{apple_content['content_type']}'"
puts '   content_attributes (ROOT LEVEL):'
puts "      title: '#{content_attrs['title']}'"
puts "      description: '#{content_attrs['description']}'"
puts "      show_summary: #{content_attrs['show_summary']}"
puts "      pages: #{content_attrs['pages'].length} (direct at root, no 'form' wrapper)"
puts "      received_message: #{content_attrs['received_message'].present? ? '✅' : '❌'}"
puts "      reply_message: #{content_attrs['reply_message'].present? ? '✅' : '❌'}"

puts "\n" + ('=' * 80)
puts '✨ Template fixed with correct structure!'
puts "\n🔍 How it works now:"
puts '   1. BotRendererService.detect_content_type_from_attributes (NEW line 220):'
puts "      Checks: attrs['pages'].present? && pages have items"
puts "      Returns: 'apple_form' ✅"
puts '   2. BotRendererService.render_from_metadata (line 92):'
puts "      Uses: apple_content['content'] = 'Guitar Information Form' ✅"
puts '   3. Message validation:'
puts '      Accepts: pages at root level (ALLOWED_APPLE_FORM_KEYS) ✅'
puts '   4. SendMessageService.perform (line 26-27):'
puts "      Sees content_type: 'apple_form'"
puts '      Calls: send_interactive_message ✅'
puts "\n🎸 Try sending from n8n now!"
puts '=' * 80
