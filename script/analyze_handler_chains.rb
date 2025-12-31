#!/usr/bin/env ruby
# Analyze handler chaining in AcousticHouseBotService
# Find all cases where one handler calls another handler

puts '=== Analyzing Handler Call Chains ==='
puts

# Read the service file
service_file = File.read('app/services/apple_messages_for_business/acoustic_house_bot_service.rb')

# Extract all handler method definitions
handler_methods = service_file.scan(/^\s*def (handle_\w+)/).flatten

puts "Found #{handler_methods.length} handler methods"
puts

# For each handler, find what other handlers it calls
handler_calls = {}

handler_methods.each do |handler_name|
  # Find the method body
  method_start = service_file.index(/def #{handler_name}/)
  next unless method_start

  # Find the end of the method (next 'def' or end of class)
  rest_of_file = service_file[method_start..]
  next_method = rest_of_file.index(/\n\s*def /, 10) # Skip the current 'def' line
  method_end = next_method ? method_start + next_method : service_file.length

  method_body = service_file[method_start...method_end]

  # Find all handle_* method calls in this method
  called_handlers = method_body.scan(/\b(handle_\w+)(?:\(|\s|$)/).flatten.uniq
  # Remove the method definition itself
  called_handlers.delete(handler_name)

  handler_calls[handler_name] = called_handlers if called_handlers.any?
end

puts '=== Handler Call Chains ==='
puts

handler_calls.each do |handler, calls|
  puts "#{handler}:"
  calls.each do |called|
    puts "  → #{called}"
  end
  puts
end

puts '=== Critical Chains (handlers that call multiple handlers) ==='
puts

critical = handler_calls.select { |_k, v| v.length > 1 }
critical.each do |handler, calls|
  puts "#{handler} calls #{calls.length} handlers:"
  calls.each { |c| puts "  → #{c}" }
  puts
end

puts '=== State Flow Chains ==='
puts 'These handlers automatically continue to the next state:'
puts

# Specific known chains from the code
chains = [
  %w[handle_welcome handle_region_prompt],
  %w[handle_region_selection handle_form_or_name_prompt],
  %w[handle_form_response handle_guitar_list_prompt],
  %w[handle_guitar_selection handle_ar_introduction],
  %w[handle_ar_introduction handle_ar_first_question],
  %w[handle_apple_pay_prompt handle_apple_pay_catcher],
  %w[handle_apple_pay_response handle_lesson_introduction],
  %w[handle_skip_payment handle_lesson_introduction],
  %w[handle_lesson_introduction handle_location_request],
  %w[handle_time_picker_response handle_continue_prompt]
]

chains.each do |from, to|
  puts "✅ #{from} → #{to}" if handler_calls[from]&.include?(to)
end
