#!/usr/bin/env ruby
# Script to check and configure Captain OpenAI settings

def print_status
  puts '=== Captain OpenAI Configuration Status ==='
  puts

  captain_configs = %w[
    CAPTAIN_OPEN_AI_API_KEY
    CAPTAIN_OPEN_AI_ENDPOINT
    CAPTAIN_OPEN_AI_MODEL
  ]

  captain_configs.each do |config_name|
    config = InstallationConfig.find_by(name: config_name)
    if config
      value_status = if config.value.present?
                       if config_name.include?('API_KEY')
                         "[SET - #{config.value[0..6]}...#{config.value[-4..-1]} (length: #{config.value.length})]"
                       else
                         "[SET - #{config.value}]"
                       end
                     else
                       '[BLANK]'
                     end
      puts "✓ #{config_name}: #{value_status}"
    else
      puts "✗ #{config_name}: [MISSING]"
    end
  end
  puts
end

def check_api_key_status
  api_key_config = InstallationConfig.find_by(name: 'CAPTAIN_OPEN_AI_API_KEY')

  if api_key_config.nil?
    return :missing
  elsif api_key_config.value.blank?
    return :blank
  elsif api_key_config.value.length < 20
    return :too_short
  else
    return :ok
  end
end

# Parse command line arguments
command = ARGV[0]
api_key = ARGV[1]
model = ARGV[2]

case command
when 'set'
  if api_key.nil? || api_key.empty?
    puts '❌ Error: API key is required!'
    puts
    puts 'Usage: rails runner script/check_captain_config.rb set YOUR_API_KEY [optional_model]'
    puts
    puts 'Example:'
    puts '  rails runner script/check_captain_config.rb set sk-proj-abc123... gpt-4o-mini'
    exit 1
  end

  puts '=== Setting Captain OpenAI Configuration ==='
  puts

  # Set API key
  api_key_config = InstallationConfig.find_or_create_by(name: 'CAPTAIN_OPEN_AI_API_KEY')
  api_key_config.update!(value: api_key)
  puts '✓ CAPTAIN_OPEN_AI_API_KEY set successfully'

  # Set model if provided, otherwise use default
  model_to_use = model.presence || 'gpt-4o-mini'
  model_config = InstallationConfig.find_or_create_by(name: 'CAPTAIN_OPEN_AI_MODEL')
  model_config.update!(value: model_to_use)
  puts "✓ CAPTAIN_OPEN_AI_MODEL set to: #{model_to_use}"

  # Keep endpoint as default (blank = https://api.openai.com/)
  endpoint_config = InstallationConfig.find_or_create_by(name: 'CAPTAIN_OPEN_AI_ENDPOINT')
  if endpoint_config.value.blank?
    puts '✓ CAPTAIN_OPEN_AI_ENDPOINT using default (https://api.openai.com/)'
  else
    puts "✓ CAPTAIN_OPEN_AI_ENDPOINT: #{endpoint_config.value}"
  end

  puts
  puts '=== Configuration Complete! ==='
  puts
  print_status

when 'clear'
  puts '=== Clearing Captain OpenAI Configuration ==='
  puts

  InstallationConfig.find_by(name: 'CAPTAIN_OPEN_AI_API_KEY')&.update!(value: '')
  InstallationConfig.find_by(name: 'CAPTAIN_OPEN_AI_MODEL')&.update!(value: '')
  puts '✓ Configuration cleared'
  puts
  print_status

when 'test'
  print_status

  puts '=== Testing OpenAI Connection ==='
  puts

  api_key_status = check_api_key_status

  if api_key_status != :ok
    puts '❌ Cannot test: API key is not properly configured'
    puts '   Run: rails runner script/check_captain_config.rb set YOUR_API_KEY'
    exit 1
  end

  begin
    require 'openai'

    api_key = InstallationConfig.find_by(name: 'CAPTAIN_OPEN_AI_API_KEY').value
    endpoint = InstallationConfig.find_by(name: 'CAPTAIN_OPEN_AI_ENDPOINT')&.value
    endpoint = endpoint.presence || 'https://api.openai.com/'

    client = OpenAI::Client.new(
      access_token: api_key,
      uri_base: endpoint
    )

    puts 'Testing connection with a simple API call...'
    response = client.models.list

    puts '✓ Connection successful!'
    puts "✓ Available models: #{response['data'].map { |m| m['id'] }.first(5).join(', ')}..."

  rescue StandardError => e
    puts "❌ Connection failed: #{e.message}"
    puts
    puts 'Common issues:'
    puts '  - Invalid API key'
    puts '  - Expired API key'
    puts '  - Network connectivity issues'
    puts '  - Verify your key at: https://platform.openai.com/api-keys'
  end

else
  # Default: just show status
  print_status

  puts '=== Recommendations ==='
  puts

  status = check_api_key_status

  case status
  when :missing
    puts '❌ CAPTAIN_OPEN_AI_API_KEY is missing!'
  when :blank
    puts '❌ CAPTAIN_OPEN_AI_API_KEY exists but is blank!'
  when :too_short
    api_key_config = InstallationConfig.find_by(name: 'CAPTAIN_OPEN_AI_API_KEY')
    puts "⚠️  CAPTAIN_OPEN_AI_API_KEY seems too short (#{api_key_config.value.length} chars)"
    puts '   OpenAI API keys are typically 51+ characters'
  when :ok
    puts '✓ CAPTAIN_OPEN_AI_API_KEY appears to be set correctly'
    puts "  If you're still getting 401 errors, the key may be invalid"
    puts '  Run: rails runner script/check_captain_config.rb test'
  end

  if status != :ok
    puts
    puts 'To set your API key, run:'
    puts '  rails runner script/check_captain_config.rb set YOUR_API_KEY'
    puts
    puts 'Example:'
    puts '  rails runner script/check_captain_config.rb set sk-proj-abc123xyz...'
  end

  puts
  puts 'Available commands:'
  puts '  rails runner script/check_captain_config.rb                    # Show status'
  puts '  rails runner script/check_captain_config.rb set API_KEY        # Set API key'
  puts '  rails runner script/check_captain_config.rb test               # Test connection'
  puts '  rails runner script/check_captain_config.rb clear              # Clear configuration'
  puts
  puts 'Get your API key at: https://platform.openai.com/api-keys'
end
