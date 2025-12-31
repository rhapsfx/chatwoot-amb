#!/usr/bin/env ruby
# frozen_string_literal: true

# Find all templates with split-brain storage issue
# (has content_blocks but metadata['storage_strategy'] = 'metadata')

puts '=' * 80
puts 'Scanning for templates with split-brain storage issue...'
puts '=' * 80
puts

affected_templates = []

MessageTemplate.where("metadata->>'storage_strategy' = 'metadata'").find_each do |template|
  # Check if template also has content_blocks
  if template.content_blocks.exists?
    affected_templates << {
      id: template.id,
      name: template.name,
      block_count: template.content_blocks.count,
      metadata_strategy: template.metadata['storage_strategy']
    }
  end
end

if affected_templates.empty?
  puts '✅ No split-brain templates found (all storage flags are correct)'
else
  puts "❌ Found #{affected_templates.length} template(s) with split-brain issue:"
  puts

  affected_templates.each do |t|
    puts "  Template ID #{t[:id]}: #{t[:name]}"
    puts "    - Has #{t[:block_count]} content block(s)"
    puts "    - But metadata says: storage_strategy = '#{t[:metadata_strategy]}'"
    puts
  end

  puts '=' * 80
  puts 'To fix these templates, run:'
  puts
  puts "rails runner \"MessageTemplate.where(id: [#{affected_templates.map do |t|
    t[:id]
  end.join(', ')}]).find_each { |t| t.metadata['storage_strategy'] = 'content_blocks'; t.save! }; puts 'Fixed!'\""
  puts
end

puts '=' * 80
