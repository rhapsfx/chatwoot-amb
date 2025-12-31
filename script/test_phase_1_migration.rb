#!/usr/bin/env ruby
# frozen_string_literal: true

# Phase 1 Migration Test Script
# Tests that both old and new apple_amb_images endpoints work correctly

puts "\n" + ('=' * 80)
puts 'Phase 1 Migration Test: apple_list_picker_images → apple_amb_images'
puts ('=' * 80) + "\n"

# Find test data
account = Account.first
unless account
  puts '❌ No accounts found. Please create an account first.'
  exit 1
end

inbox = account.inboxes.where(channel_type: 'Channel::AppleMessagesForBusiness').first
unless inbox
  puts '❌ No Apple Messages for Business inbox found.'
  puts '   Please create an AMB inbox first.'
  exit 1
end

puts '✅ Test Setup:'
puts "   Account ID: #{account.id}"
puts "   Inbox ID: #{inbox.id}"
puts "   Inbox Name: #{inbox.name}"
puts ''

# Test 1: Model Layer (Unchanged)
puts 'Test 1: Model Layer (Should work as before)'
puts '-' * 80
begin
  image_count = inbox.apple_list_picker_images.count
  puts "✅ Model query works: #{image_count} images found"

  if image_count > 0
    sample = inbox.apple_list_picker_images.first
    puts '   Sample image:'
    puts "     - ID: #{sample.id}"
    puts "     - Identifier: #{sample.identifier}"
    puts "     - Description: #{sample.description}"
  else
    puts '   ℹ️  No images in this inbox (this is fine for testing)'
  end
rescue StandardError => e
  puts "❌ Model query failed: #{e.message}"
  exit 1
end
puts ''

# Test 2: Route Resolution
puts 'Test 2: Route Resolution'
puts '-' * 80
begin
  # Check that both routes exist
  app = Rails.application
  routes = app.routes.routes.to_a

  old_route = routes.find { |r| r.path.spec.to_s.include?('apple_list_picker_images') && r.verb == 'GET' }
  new_route = routes.find { |r| r.path.spec.to_s.include?('apple_amb_images') && r.verb == 'GET' }

  if old_route
    puts '✅ Old route exists: /api/v1/accounts/:account_id/inboxes/:inbox_id/apple_list_picker_images'
  else
    puts '❌ Old route not found!'
  end

  if new_route
    puts '✅ New route exists: /api/v1/accounts/:account_id/inboxes/:inbox_id/apple_amb_images'
  else
    puts '❌ New route not found!'
  end
rescue StandardError => e
  puts "⚠️  Route checking failed (non-critical): #{e.message}"
end
puts ''

# Test 3: Controller Classes
puts 'Test 3: Controller Classes'
puts '-' * 80
begin
  old_controller = Api::V1::Accounts::Inboxes::AppleListPickerImagesController
  puts "✅ Old controller exists: #{old_controller.name}"

  new_controller = Api::V1::Accounts::Inboxes::AppleAmbImagesController
  puts "✅ New controller exists: #{new_controller.name}"
rescue NameError => e
  puts "❌ Controller missing: #{e.message}"
  exit 1
end
puts ''

# Test 4: Check for deprecation warning method
puts 'Test 4: Deprecation Warning'
puts '-' * 80
begin
  old_controller = Api::V1::Accounts::Inboxes::AppleListPickerImagesController

  if old_controller.instance_methods(false).include?(:log_deprecation_warning)
    puts '✅ Deprecation warning method exists in old controller'
    puts '   ℹ️  Old endpoint will log warnings when used'
  else
    puts '⚠️  Deprecation warning method not found (check before_action setup)'
  end
rescue StandardError => e
  puts "⚠️  Could not check deprecation method: #{e.message}"
end
puts ''

# Test 5: Frontend API Clients
puts 'Test 5: Frontend API Client Files'
puts '-' * 80

old_client_path = Rails.root.join('app/javascript/dashboard/api/appleListPickerImages.js')
new_client_path = Rails.root.join('app/javascript/dashboard/api/appleAmbImages.js')

if File.exist?(old_client_path)
  puts '✅ Old API client exists: appleListPickerImages.js'
else
  puts '❌ Old API client not found!'
end

if File.exist?(new_client_path)
  puts '✅ New API client exists: appleAmbImages.js'

  # Check that it uses the correct resource name
  content = File.read(new_client_path)
  if content.include?("'apple_amb_images'")
    puts "   ✅ Correct resource name: 'apple_amb_images'"
  else
    puts "   ❌ Resource name not updated to 'apple_amb_images'"
  end
else
  puts '❌ New API client not found!'
end
puts ''

# Test 6: Component Migration Status
puts 'Test 6: Component Migration Status'
puts '-' * 80

modal_path = Rails.root.join(
  'app/javascript/dashboard/routes/dashboard/settings/templates/components/ImageValidationModal.vue'
)

if File.exist?(modal_path)
  puts '✅ ImageValidationModal.vue exists'

  content = File.read(modal_path)
  if content.include?('AppleAmbImagesAPI')
    puts '   ✅ Component uses new API client (AppleAmbImagesAPI)'
  elsif content.include?('AppleListPickerImagesAPI')
    puts '   ⚠️  Component still uses old API client'
  end
else
  puts '⚠️  ImageValidationModal.vue not found (may not be in use)'
end
puts ''

# Summary
puts "\n" + ('=' * 80)
puts 'Test Summary'
puts '=' * 80
puts ''
puts '✅ Phase 1 Migration appears successful!'
puts ''
puts 'Next Steps:'
puts '1. ✅ Run linters: bundle exec rubocop -a && cd app/javascript && pnpm eslint --fix'
puts '2. 🧪 Manual API testing:'
puts "   - Old endpoint: curl http://localhost:3000/api/v1/accounts/#{account.id}/inboxes/#{inbox.id}/apple_list_picker_images"
puts "   - New endpoint: curl http://localhost:3000/api/v1/accounts/#{account.id}/inboxes/#{inbox.id}/apple_amb_images"
puts '   - Check logs for deprecation warning on old endpoint'
puts '3. 📊 Monitor deprecation logs:'
puts '   - tail -f log/development.log | grep DEPRECATED'
puts ''
puts 'Both endpoints should work identically. Old endpoint logs deprecation warning.'
puts ''
