#!/usr/bin/env ruby
# frozen_string_literal: true

# Check what the unknown templates actually contain

templates = MessageTemplate.where("metadata -> 'apple_message_content' IS NOT NULL")

unknown_samples = []
templates.each do |t|
  attrs = t.metadata.dig('apple_message_content', 'content_attributes')
  next unless attrs

  # Check if it's unknown
  is_unknown = !attrs['dynamic'].present? &&
               !attrs['sections'].present? &&
               !attrs['event'].present? &&
               !attrs['form'].present? &&
               !attrs['quick_reply'].present? &&
               !attrs['replies'].present? &&
               !(attrs['url'].present? && attrs['title'].present?) &&
               !attrs['payment'].present? &&
               !attrs['oauth2'].present?

  next unless is_unknown && unknown_samples.size < 5

  unknown_samples << {
    id: t.id,
    name: t.name,
    keys: attrs.keys.sort,
    sample_content: attrs.to_json[0..200]
  }
end

puts "Found #{unknown_samples.size} sample unknown templates:"
unknown_samples.each do |sample|
  puts "\nTemplate #{sample[:id]}: #{sample[:name]}"
  puts "  Keys: #{sample[:keys].join(', ')}"
  puts "  Sample: #{sample[:sample_content]}..."
end
