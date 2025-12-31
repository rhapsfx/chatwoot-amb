#!/usr/bin/env ruby
# frozen_string_literal: true

# Debug script to find actual category values used in templates

puts "\n" + ('=' * 80)
puts '🔍 Template Category Analysis'
puts ('=' * 80) + "\n"

# Get all templates
all_templates = MessageTemplate.all

puts "Total templates: #{all_templates.count}"
puts ''

# Group by category
categories = all_templates.group_by(&:category)

puts 'Categories found:'
categories.each do |category, templates|
  puts "  #{category || 'nil'}: #{templates.count} templates"
end
puts ''

# Show specific templates we know about
puts('=' * 80)
puts 'Known AMB Templates:'
puts('=' * 80)
puts ''

# Template 343
template_343 = MessageTemplate.find_by(id: 343)
if template_343
  puts 'Template 343:'
  puts "  Name: #{template_343.name}"
  puts "  Category: #{template_343.category.inspect}"
  puts "  Account ID: #{template_343.account_id}"
  puts ''
end

# Template 321
template_321 = MessageTemplate.find_by(id: 321)
if template_321
  puts 'Template 321:'
  puts "  Name: #{template_321.name}"
  puts "  Category: #{template_321.category.inspect}"
  puts "  Account ID: #{template_321.account_id}"
  puts ''
end

# Show templates with content_blocks that have block_type
puts('=' * 80)
puts 'Templates with Content Blocks:'
puts('=' * 80)
puts ''

MessageTemplate.includes(:content_blocks).each do |template|
  next if template.content_blocks.empty?

  block_types = template.content_blocks.map(&:block_type).uniq
  next unless block_types.any? { |bt| %w[list_picker time_picker form].include?(bt) }

  puts "Template #{template.id}: #{template.name}"
  puts "  Category: #{template.category.inspect}"
  puts "  Block types: #{block_types.inspect}"
  puts ''
end
