#!/usr/bin/env ruby
# frozen_string_literal: true

# Script to verify Acoustic House Bot template structure
# Usage: rails runner script/verify_template_structure.rb

puts '🔍 Verifying Acoustic House Bot Template Structure'
puts '=' * 60
puts ''

# Find all Acoustic House Bot templates
templates = MessageTemplate.where("'acoustic_house_bot' = ANY(tags)")

if templates.empty?
  puts '❌ No Acoustic House Bot templates found'
  exit 1
end

puts "📋 Found #{templates.count} templates"
puts ''

templates.each do |template|
  puts '=' * 60
  puts "Template: #{template.name} (ID: #{template.id})"
  puts '=' * 60

  # Check metadata
  if template.metadata.present? && template.metadata['apple_message_content'].present?
    apple_content = template.metadata['apple_message_content']
    puts '✅ Metadata: Has apple_message_content'
    puts "   Content Type: #{apple_content['content_type']}"

    # Show content_attributes structure
    if apple_content['content_attributes'].present?
      attrs = apple_content['content_attributes']
      puts "   Content Attributes Keys: #{attrs.keys.join(', ')}"

      # Show items for quick_reply
      if attrs['items'].present?
        puts "   Items: #{attrs['items'].length} items"
        attrs['items'].each_with_index do |item, idx|
          puts "     #{idx + 1}. #{item['title']} (value: #{item['value']})"
        end
      end

      # Show sections for list_picker
      if attrs['sections'].present?
        puts "   Sections: #{attrs['sections'].length} sections"
        attrs['sections'].each_with_index do |section, idx|
          puts "     Section #{idx + 1}: #{section['items']&.length || 0} items"
        end
      end
    end
  else
    puts '❌ Metadata: Missing apple_message_content'
  end

  # Check content_blocks
  if template.content_blocks.any?
    puts "✅ Content Blocks: #{template.content_blocks.count} blocks"
    template.content_blocks.each_with_index do |block, idx|
      puts "   Block #{idx + 1}:"
      puts "     Type: #{block.block_type}"
      puts "     Order: #{block.order_index}"

      if block.properties.present?
        puts "     Properties Keys: #{block.properties.keys.join(', ')}"

        # Show items for quick_reply
        if block.properties['items'].present?
          puts "     Items: #{block.properties['items'].length} items"
          block.properties['items'].each_with_index do |item, i|
            puts "       #{i + 1}. #{item['title']} (value: #{item['value']})"
          end
        end

        # Show request_identifier
        puts "     Request ID: #{block.properties['request_identifier']}" if block.properties['request_identifier'].present?
      else
        puts '     ⚠️  Properties: Empty'
      end
    end
  else
    puts '❌ Content Blocks: None found'
  end

  # Check use_cases
  if template.use_cases.nil? || template.use_cases.empty?
    puts '✅ Use Cases: None (accessible via / command)'
  else
    puts "⚠️  Use Cases: #{template.use_cases.inspect} (may be restricted)"
  end

  puts ''
end

puts '=' * 60
puts '📊 SUMMARY'
puts '=' * 60
puts "Total templates: #{templates.count}"
puts "With metadata: #{templates.count { |t| t.metadata.present? && t.metadata['apple_message_content'].present? }}"
puts "With content_blocks: #{templates.count { |t| t.content_blocks.any? }}"
puts "Unrestricted (no use_cases): #{templates.count { |t| t.use_cases.nil? || t.use_cases.empty? }}"
