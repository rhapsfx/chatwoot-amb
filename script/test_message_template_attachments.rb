#!/usr/bin/env ruby
# frozen_string_literal: true

# Test script for MessageTemplate attachment functionality
# Usage: rails runner test_message_template_attachments.rb

puts '=' * 80
puts 'Testing MessageTemplate Attachment Functionality'
puts '=' * 80
puts

# Check if MessageTemplate model has the new constants
puts '✓ Checking constants...'
puts "  MAX_ATTACHMENTS: #{MessageTemplate::MAX_ATTACHMENTS}"
puts "  MAX_ATTACHMENT_SIZE: #{MessageTemplate::MAX_ATTACHMENT_SIZE / 1.megabyte}MB"
puts "  ALLOWED_ATTACHMENT_TYPES: #{MessageTemplate::ALLOWED_ATTACHMENT_TYPES.count} types"
puts

# Check if MessageTemplate has has_many_attached
puts '✓ Checking ActiveStorage association...'
if MessageTemplate.reflect_on_attachment(:attachments)
  puts '  ✓ has_many_attached :attachments is configured'
else
  puts '  ✗ ERROR: has_many_attached :attachments not found'
  exit 1
end
puts

# Check if attachment_metadata field exists
puts '✓ Checking database schema...'
if MessageTemplate.column_names.include?('attachment_metadata')
  puts '  ✓ attachment_metadata column exists'
else
  puts '  ✗ ERROR: attachment_metadata column not found (migration may not have been run)'
  exit 1
end
puts

# Check public methods
puts '✓ Checking public methods...'
required_methods = %i[
  attachments_summary
  attach_files
  remove_attachment
  reorder_attachments
]

required_methods.each do |method_name|
  if MessageTemplate.instance_methods.include?(method_name)
    puts "  ✓ ##{method_name} exists"
  else
    puts "  ✗ ERROR: ##{method_name} not found"
    exit 1
  end
end
puts

# Check private methods
puts '✓ Checking private metadata management methods...'
private_methods = %i[
  initialize_attachment_metadata
  find_attachment_metadata
  update_attachment_metadata
  remove_attachment_metadata
  reindex_attachment_display_order
]

private_methods.each do |method_name|
  if MessageTemplate.private_instance_methods.include?(method_name)
    puts "  ✓ ##{method_name} exists"
  else
    puts "  ✗ ERROR: ##{method_name} not found"
    exit 1
  end
end
puts

# Check validation methods
puts '✓ Checking validation methods...'
validation_methods = %i[
  validate_attachments_count
  validate_attachments_size
  validate_attachments_content_type
]

validation_methods.each do |method_name|
  if MessageTemplate.private_instance_methods.include?(method_name)
    puts "  ✓ ##{method_name} exists"
  else
    puts "  ✗ ERROR: ##{method_name} not found"
    exit 1
  end
end
puts

puts '=' * 80
puts '✓ All Phase 1 checks passed!'
puts '=' * 80
puts
puts 'Next steps:'
puts '1. Run: bundle exec rspec spec/models/message_template_spec.rb (after writing specs)'
puts '2. Test in rails console:'
puts '   template = MessageTemplate.first'
puts '   template.attachments_summary'
puts '3. Ready to proceed with Phase 2 (API endpoints)'
puts
