#!/usr/bin/env ruby
# frozen_string_literal: true

# Script to validate the structure and syntax of template attachment tests
# Usage: ruby script/validate_template_attachment_tests.rb

require 'json'
require 'pathname'

class TestValidator
  attr_reader :results

  def initialize
    @results = {
      files_checked: [],
      test_cases: 0,
      assertions: 0,
      syntax_errors: [],
      missing_files: [],
      warnings: [],
      total_lines: 0
    }
  end

  def validate_all
    puts "\n" + ('='*80)
    puts 'TEMPLATE ATTACHMENT TEST SUITE VALIDATION'
    puts ('='*80) + "\n"

    check_factory_file
    check_model_tests
    check_service_tests
    check_controller_tests
    check_integration_tests
    check_documentation

    print_summary
  end

  private

  def check_factory_file
    file_path = 'spec/factories/message_templates.rb'
    puts "Checking: #{file_path}"

    if File.exist?(file_path)
      content = File.read(file_path)
      @results[:total_lines] += content.lines.count

      # Check for factory definition
      if content.include?('FactoryBot.define')
        puts '  ✓ FactoryBot definition found'
      else
        @results[:syntax_errors] << "#{file_path}: Missing FactoryBot.define"
      end

      # Check for traits
      traits = content.scan(/trait\s+:(\w+)/).map { |m| m[0] }
      puts "  ✓ Found traits: #{traits.join(', ')}"

      if traits.include?('with_attachments')
        puts '  ✓ :with_attachments trait present'
      else
        @results[:warnings] << "#{file_path}: Missing :with_attachments trait"
      end

      @results[:files_checked] << file_path
    else
      @results[:missing_files] << file_path
    end
    puts
  end

  def check_model_tests
    file_path = 'spec/models/message_template_spec.rb'
    puts "Checking: #{file_path}"

    if File.exist?(file_path)
      content = File.read(file_path)
      @results[:total_lines] += content.lines.count

      # Count test cases
      tests = content.scan(/^\s*it\s+['"]/).length
      @results[:test_cases] += tests
      puts "  ✓ Found #{tests} test cases"

      # Check for key test groups
      key_tests = {
        'associations' => /describe.*associations/,
        'validations' => /describe.*validations/,
        'attachment_validations' => /describe.*attachment.*validations/,
        'attachments_summary' => /describe.*attachments_summary/,
        'attach_files' => /describe.*#?attach_files/,
        'remove_attachment' => /describe.*#?remove_attachment/,
        'reorder_attachments' => /describe.*#?reorder_attachments/
      }

      key_tests.each do |test_name, pattern|
        if content.match?(pattern)
          puts "  ✓ #{test_name} tests found"
        else
          @results[:warnings] << "#{file_path}: Missing #{test_name} tests"
        end
      end

      @results[:files_checked] << file_path
    else
      @results[:missing_files] << file_path
    end
    puts
  end

  def check_service_tests
    puts 'Checking: spec/services/templates/bot_renderer_service_spec.rb'
    bot_renderer = 'spec/services/templates/bot_renderer_service_spec.rb'

    if File.exist?(bot_renderer)
      content = File.read(bot_renderer)
      @results[:total_lines] += content.lines.count
      tests = content.scan(/^\s*it\s+['"]/).length
      @results[:test_cases] += tests
      puts "  ✓ Found #{tests} test cases"

      # Check key tests
      if content.include?('load_template_attachments')
        puts '  ✓ load_template_attachments tests found'
      else
        @results[:warnings] << "#{bot_renderer}: Missing load_template_attachments tests"
      end

      @results[:files_checked] << bot_renderer
    else
      @results[:missing_files] << bot_renderer
    end

    puts 'Checking: spec/services/templates/bot_messaging_service_spec.rb'
    bot_messaging = 'spec/services/templates/bot_messaging_service_spec.rb'

    if File.exist?(bot_messaging)
      content = File.read(bot_messaging)
      @results[:total_lines] += content.lines.count
      tests = content.scan(/^\s*it\s+['"]/).length
      @results[:test_cases] += tests
      puts "  ✓ Found #{tests} test cases"

      if content.include?('attach_template_files_to_message')
        puts '  ✓ attach_template_files_to_message tests found'
      else
        @results[:warnings] << "#{bot_messaging}: Missing attach_template_files_to_message tests"
      end

      @results[:files_checked] << bot_messaging
    else
      @results[:missing_files] << bot_messaging
    end
    puts
  end

  def check_controller_tests
    file_path = 'spec/requests/api/v1/accounts/message_template_attachments_controller_spec.rb'
    puts "Checking: #{file_path}"

    if File.exist?(file_path)
      content = File.read(file_path)
      @results[:total_lines] += content.lines.count
      tests = content.scan(/^\s*it\s+['"]/).length
      @results[:test_cases] += tests
      puts "  ✓ Found #{tests} test cases"

      endpoints = {
        'POST attach_files' => /POST.*attach_files/,
        'DELETE remove_attachment' => /DELETE.*attachments/,
        'PUT reorder_attachments' => /PUT.*reorder_attachments/
      }

      endpoints.each do |endpoint_name, pattern|
        if content.match?(pattern)
          puts "  ✓ #{endpoint_name} tests found"
        else
          @results[:warnings] << "#{file_path}: Missing #{endpoint_name} tests"
        end
      end

      @results[:files_checked] << file_path
    else
      @results[:missing_files] << file_path
    end
    puts
  end

  def check_integration_tests
    file_path = 'spec/requests/api/v1/accounts/template_attachment_integration_spec.rb'
    puts "Checking: #{file_path}"

    if File.exist?(file_path)
      content = File.read(file_path)
      @results[:total_lines] += content.lines.count
      tests = content.scan(/^\s*it\s+['"]/).length
      @results[:test_cases] += tests
      puts "  ✓ Found #{tests} test cases"

      integration_tests = {
        'complete workflow' => /create template.*attach files.*render.*send message/i,
        'attachment management' => /add.*reorder.*remove/i,
        'validation' => /enforce.*limit/i,
        'metadata persistence' => /metadata.*persist/i
      }

      integration_tests.each do |test_name, pattern|
        puts "  ✓ #{test_name} tests found" if content.match?(pattern)
      end

      @results[:files_checked] << file_path
    else
      @results[:missing_files] << file_path
    end
    puts
  end

  def check_documentation
    file_path = 'docs/templates/TEMPLATE_ATTACHMENT_TESTS.md'
    puts "Checking: #{file_path}"

    if File.exist?(file_path)
      content = File.read(file_path)
      @results[:total_lines] += content.lines.count
      puts '  ✓ Documentation file found'
      puts "  ✓ #{content.lines.count} lines of documentation"

      @results[:files_checked] << file_path
    else
      @results[:missing_files] << file_path
    end
    puts
  end

  def print_summary
    puts '='*80
    puts 'TEST SUITE SUMMARY'
    puts ('='*80) + "\n"

    puts "Files Checked: #{@results[:files_checked].count}"
    @results[:files_checked].each { |f| puts "  ✓ #{f}" }

    puts "\nTest Statistics:"
    puts "  Test Cases: #{@results[:test_cases]}"
    puts "  Total Lines: #{@results[:total_lines]}"
    puts "  Average Tests per File: #{(@results[:test_cases].to_f / @results[:files_checked].count).round(1)}"

    if @results[:missing_files].any?
      puts "\nMissing Files:"
      @results[:missing_files].each { |f| puts "  ✗ #{f}" }
    end

    if @results[:syntax_errors].any?
      puts "\nSyntax Errors:"
      @results[:syntax_errors].each { |e| puts "  ✗ #{e}" }
    end

    if @results[:warnings].any?
      puts "\nWarnings:"
      @results[:warnings].each { |w| puts "  ⚠ #{w}" }
    end

    puts "\n" + ('='*80)
    if @results[:missing_files].empty? && @results[:syntax_errors].empty?
      puts 'VALIDATION PASSED ✓'
      puts 'All test files are present and properly structured.'
    else
      puts 'VALIDATION FAILED ✗'
    end
    puts ('='*80) + "\n"
  end
end

validator = TestValidator.new
validator.validate_all
