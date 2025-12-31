#!/usr/bin/env ruby
# Test if Rails strong params sees modifications made in before_action
#
# This simulates what happens in our controller:
# 1. before_action modifies params[:content_attributes]
# 2. create action calls params.permit(...)
#
# The question: Does permit see the modified value?

require 'action_controller'

puts "\n" + ('=' * 80)
puts 'RAILS STRONG PARAMS MODIFICATION TEST'
puts ('=' * 80) + "\n"

# Simulate the original request params (what Rails receives from frontend)
class FakeController < ActionController::Base
  def test_strong_params
    # Simulate receiving params from frontend
    request_params = ActionController::Parameters.new({
                                                        content_type: 'apple_list_picker',
                                                        content_attributes: {
                                                          sections: [
                                                            {
                                                              title: 'Options',
                                                              multipleSelection: true  # camelCase from frontend
                                                            }
                                                          ]
                                                        }
                                                      })

    puts '1. ORIGINAL PARAMS (from request)'
    puts "   First section keys: #{request_params[:content_attributes][:sections].first.keys.inspect}"
    puts "   multipleSelection: #{request_params[:content_attributes][:sections].first[:multipleSelection]}"
    puts

    # Simulate before_action normalization
    puts '2. BEFORE_ACTION: Modifying params[:content_attributes]'
    normalized = {
      'sections' => [
        {
          'title' => 'Options',
          'multiple_selection' => true  # Normalized to snake_case
        }
      ]
    }
    request_params[:content_attributes] = normalized
    puts "   Set to normalized hash with keys: #{request_params[:content_attributes]['sections'].first.keys.inspect}"
    puts "   multiple_selection: #{request_params[:content_attributes]['sections'].first['multiple_selection']}"
    puts

    # Simulate create action calling strong params
    puts '3. CREATE ACTION: Calling params.permit(...)'
    permitted = request_params.permit(
      :content_type,
      content_attributes: [
        { sections: [:title, :multiple_selection, { items: [:title, :subtitle] }] }
      ]
    )
    puts "   Permitted class: #{permitted.class}"
    puts

    # Check what we got
    puts '4. PERMITTED PARAMS RESULT'
    if permitted[:content_attributes] && permitted[:content_attributes]['sections']
      first_section = permitted[:content_attributes]['sections'].first
      puts '   First section exists: ✅'
      puts "   First section class: #{first_section.class}"
      puts "   First section keys: #{first_section.keys.inspect}"
      puts "   multipleSelection: #{first_section['multipleSelection'].inspect}"
      puts "   multiple_selection: #{first_section['multiple_selection'].inspect}"
      puts

      if first_section['multiple_selection'] == true
        puts '   ✅ SUCCESS: Strong params saw our normalized value!'
      elsif first_section['multipleSelection'] == true
        puts '   ❌ FAILED: Strong params read from ORIGINAL request, ignored our modification!'
      else
        puts '   ❌ FAILED: Value was lost entirely!'
      end
    else
      puts '   ❌ FAILED: sections missing from permitted params!'
    end
    puts
  end
end

# Run the test
controller = FakeController.new
controller.test_strong_params

puts('=' * 80)
puts 'TEST COMPLETE'
puts ('=' * 80) + "\n"
