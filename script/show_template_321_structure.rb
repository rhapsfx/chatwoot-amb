#!/usr/bin/env ruby
# frozen_string_literal: true

# Show full structure of template 321

require 'json'

template = MessageTemplate.find_by(id: 321)

unless template
  puts '❌ Template 321 not found'
  exit 1
end

puts "\n" + ('=' * 80)
puts 'Template 321 Full Structure'
puts ('=' * 80) + "\n"

puts "Name: #{template.name}"
puts "Category: #{template.category}"
puts ''

puts "Content Blocks: #{template.content_blocks.count}"
puts ''

template.content_blocks.each_with_index do |block, idx|
  puts "Block #{idx + 1}:"
  puts "  block_type: #{block.block_type}"
  puts '  properties:'
  puts JSON.pretty_generate(block.properties)
  puts ''
end

puts('=' * 80)
puts 'build_content result:'
puts('=' * 80)
content = template.build_content
puts JSON.pretty_generate(content)
puts ''
