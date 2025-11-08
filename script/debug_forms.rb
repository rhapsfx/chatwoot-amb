#!/usr/bin/env ruby
# frozen_string_literal: true

require 'json'

# Read migration data
data = JSON.parse(File.read('tmp/bot_migration/acoustic_house/migration_data_FILTERED.json'))

# Find form templates
forms = data['payloads'].select do |p|
  ct = p['template']['content_type']
  ca = p['template']['content_attributes'] || {}
  ct == 'text' && ca.dig('dynamic', 'template') == 'formSelect'
end

puts "Found #{forms.size} form templates"
puts

forms.each do |form|
  puts "File: #{form['original_file']}"

  ca = form['template']['content_attributes']
  dynamic = ca['dynamic'] || {}
  page = dynamic['page'] || {}
  data_obj = dynamic['data'] || {}

  puts "  Has dynamic.page.title: #{!page['title'].to_s.empty?}"
  puts "  Has dynamic.page.sections: #{!page['sections'].to_s.empty?}"
  puts "  Has dynamic.page.fields: #{!page['fields'].to_s.empty?}"
  puts "  Has dynamic.data.pages: #{!data_obj['pages'].to_s.empty?}"

  if page['sections']
    puts "  Sections count: #{page['sections'].size}"
    page['sections'].each_with_index do |section, i|
      fields = section['fields'] || []
      puts "    Section #{i}: title='#{section['title']}', #{fields.size} fields"
      fields.each do |field|
        puts "      - #{field['type']}: #{field['label']}"
      end
    end
  end

  puts
end
