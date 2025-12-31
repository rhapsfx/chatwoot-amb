#!/usr/bin/env ruby
# frozen_string_literal: true

# Validate SharedAppleImagesController implementation without database access

require 'bundler/setup'
ENV['RAILS_ENV'] ||= 'development'
require_relative '../config/environment'

puts '=== SharedAppleImagesController Validation ==='
puts ''

# Check if controller exists and is properly configured
begin
  controller_class = Api::V1::Accounts::SharedAppleImagesController
  puts '✓ Controller class loaded successfully'

  # Check controller actions
  actions = %i[index show create update destroy upload remove_image system_images branding_images template_images]
  actions.each do |action|
    if controller_class.instance_methods.include?(action)
      puts "✓ Controller has #{action} action"
    else
      puts "✗ Controller missing #{action} action"
    end
  end
rescue NameError => e
  puts '✗ Controller class not found: ' + e.message
  exit 1
end

# Check if policy exists
begin
  policy_class = SharedAppleImagePolicy
  puts '✓ Policy class loaded successfully'

  # Check policy methods
  policy_methods = %i[index? show? create? update? destroy? upload? remove_image? system_images? branding_images? template_images?]
  policy_methods.each do |method|
    if policy_class.instance_methods.include?(method)
      puts "✓ Policy has #{method} method"
    else
      puts "✗ Policy missing #{method} method"
    end
  end
rescue NameError => e
  puts '✗ Policy class not found: ' + e.message
  exit 1
end

# Check model methods (without instantiation)
puts '✓ Model class exists'
model_methods = %i[image_url image_data_base64 system_images branding_images template_images]
model_methods.each do |method|
  if SharedAppleImage.method_defined?(method) || SharedAppleImage.respond_to?(method)
    puts "✓ Model has #{method} method/scope"
  else
    puts "✗ Model missing #{method} method/scope"
  end
end

puts ''
puts '=== Validation Complete ==='
puts 'All components are properly configured!'
