# Fix region_quick_reply template structure for Apple Messages validation
# This script updates template ID 53 to use the correct structure

template = BotActionTemplate.find(53)

puts "Template type: #{template.template_type}"
puts 'Current parameters:'
puts template.parameters.inspect
puts "\n"

# Get current data
data = template.parameters.deep_symbolize_keys

# Fix items - rename 'value' to 'identifier'
if data[:items].is_a?(Array)
  data[:items].each_with_index do |item, idx|
    next unless item[:value] && !item[:identifier]

    puts "✏️  Item #{idx}: Renaming 'value' (#{item[:value]}) to 'identifier'"
    item[:identifier] = item[:value]
    item.delete(:value)
  end
end

# Rename request_id to request_identifier (if present)
if data[:request_id] && !data[:request_identifier]
  puts "✏️  Renaming 'request_id' to 'request_identifier'"
  data[:request_identifier] = data[:request_id]
  data.delete(:request_id)
end

# Add summary_text if missing (required for quick replies)
if !data[:summary_text] && data[:message]
  puts "✏️  Adding 'summary_text' from 'message'"
  data[:summary_text] = data[:message]
end

puts "\nUpdated parameters:"
puts data.inspect
puts "\n"

# Update the template
template.parameters = data
if template.save
  puts '✅ Template updated successfully'
else
  puts '❌ Failed to save template:'
  puts template.errors.full_messages.join("\n")
end
