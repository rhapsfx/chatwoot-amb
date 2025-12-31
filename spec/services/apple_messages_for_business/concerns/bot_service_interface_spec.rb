# frozen_string_literal: true

require 'rails_helper'

# rubocop:disable RSpec/SpecFilePathFormat, Metrics/MethodLength
RSpec.describe AppleMessagesForBusiness::BotServiceInterface do
  # Create a test bot service class that includes the interface
  let(:test_service_class) do
    Class.new do
      include AppleMessagesForBusiness::BotServiceInterface

      def self.name
        'TestBotService'
      end

      def self.handler_methods_metadata
        {
          handle_welcome: {
            handler_type: :state,
            display_name: 'Welcome Handler',
            description: 'Sends initial welcome message and prompts for region',
            category: 'onboarding',
            status: :stable,
            parameters: {
              required: [],
              optional: ['custom_greeting']
            },
            triggers: {
              state_ids: %w[AHA1 AH-restart],
              keywords: [],
              interactive_ids: []
            },
            dependencies: {
              templates: ['ah_welcome_message'],
              attributes: ['customer_name']
            },
            tags: %w[welcome onboarding region]
          },
          handle_menu: {
            handler_type: :keyword,
            display_name: 'Main Menu',
            description: 'Displays the main menu options',
            category: 'navigation',
            status: :stable,
            triggers: {
              keywords: %w[menu start]
            }
          },
          handle_undocumented: {
            # Missing required fields intentionally
            handler_type: :state
          }
        }
      end

      # Define actual methods
      def handle_welcome; end

      def handle_menu; end

      private

      def handle_undocumented; end
    end
  end

  # Create a test service class without metadata implementation
  let(:unimplemented_service_class) do
    Class.new do
      include AppleMessagesForBusiness::BotServiceInterface

      def self.name
        'UnimplementedService'
      end
    end
  end

  describe '.handler_methods_metadata' do
    context 'when not implemented' do
      it 'raises HandlerMethodNotImplementedError' do
        expect do
          unimplemented_service_class.handler_methods_metadata
        end.to raise_error(
          AppleMessagesForBusiness::BotServiceInterface::HandlerMethodNotImplementedError,
          /UnimplementedService must implement handler_methods_metadata/
        )
      end
    end

    context 'when implemented' do
      it 'returns handler metadata hash' do
        metadata = test_service_class.handler_methods_metadata
        expect(metadata).to be_a(Hash)
        expect(metadata).to have_key(:handle_welcome)
        expect(metadata).to have_key(:handle_menu)
      end

      it 'includes required metadata fields' do
        metadata = test_service_class.handler_methods_metadata[:handle_welcome]
        expect(metadata[:handler_type]).to eq(:state)
        expect(metadata[:display_name]).to eq('Welcome Handler')
        expect(metadata[:description]).to be_present
        expect(metadata[:category]).to eq('onboarding')
        expect(metadata[:status]).to eq(:stable)
      end
    end
  end

  describe '.handler_method_exists?' do
    it 'returns true for public methods' do
      expect(test_service_class.handler_method_exists?(:handle_welcome)).to be true
      expect(test_service_class.handler_method_exists?('handle_welcome')).to be true
    end

    it 'returns true for private methods' do
      expect(test_service_class.handler_method_exists?(:handle_undocumented)).to be true
    end

    it 'returns false for non-existent methods' do
      expect(test_service_class.handler_method_exists?(:nonexistent_method)).to be false
    end
  end

  describe '.handler_method_signature' do
    context 'when method exists' do
      it 'returns signature details' do
        signature = test_service_class.handler_method_signature(:handle_welcome)
        expect(signature).to be_a(Hash)
        expect(signature).to have_key(:arity)
        expect(signature).to have_key(:parameters)
        expect(signature).to have_key(:source_location)
      end

      it 'includes correct arity' do
        signature = test_service_class.handler_method_signature(:handle_welcome)
        expect(signature[:arity]).to eq(0)
      end
    end

    context 'when method does not exist' do
      it 'returns nil' do
        signature = test_service_class.handler_method_signature(:nonexistent_method)
        expect(signature).to be_nil
      end
    end
  end

  describe '.handler_methods_by_type' do
    it 'returns methods of specified type' do
      state_methods = test_service_class.handler_methods_by_type(:state)
      expect(state_methods).to include(:handle_welcome, :handle_undocumented)
      expect(state_methods).not_to include(:handle_menu)
    end

    it 'returns keyword handler methods' do
      keyword_methods = test_service_class.handler_methods_by_type(:keyword)
      expect(keyword_methods).to include(:handle_menu)
      expect(keyword_methods).not_to include(:handle_welcome)
    end

    it 'accepts string handler type' do
      methods = test_service_class.handler_methods_by_type('state')
      expect(methods).to include(:handle_welcome)
    end

    it 'raises error for invalid handler type' do
      expect do
        test_service_class.handler_methods_by_type(:invalid_type)
      end.to raise_error(
        AppleMessagesForBusiness::BotServiceInterface::InvalidHandlerTypeError,
        /Invalid handler type: invalid_type/
      )
    end
  end

  describe '.validate_handler_method' do
    context 'when method exists and has complete metadata' do
      it 'returns valid result' do
        result = test_service_class.validate_handler_method(:handle_welcome)
        expect(result[:valid]).to be true
        expect(result[:errors]).to be_empty
      end
    end

    context 'when method exists but metadata is incomplete' do
      it 'returns valid with warnings' do
        result = test_service_class.validate_handler_method(:handle_undocumented)
        expect(result[:valid]).to be true
        expect(result[:warnings]).not_to be_empty
      end

      it 'includes warnings for missing fields' do
        result = test_service_class.validate_handler_method(:handle_undocumented)
        warning_types = result[:warnings].map { |w| w[:type] }
        expect(warning_types).to include('missing_required_field')
      end
    end

    context 'when method does not exist' do
      it 'returns invalid result with errors' do
        result = test_service_class.validate_handler_method(:nonexistent_method)
        expect(result[:valid]).to be false
        expect(result[:errors]).not_to be_empty
      end

      it 'includes method_not_found error' do
        result = test_service_class.validate_handler_method(:nonexistent_method)
        error = result[:errors].first
        expect(error[:type]).to eq('method_not_found')
        expect(error[:message]).to include('nonexistent_method')
        expect(error[:message]).to include('TestBotService')
      end

      it 'provides suggestion for similar method' do
        result = test_service_class.validate_handler_method(:handle_welc)
        error = result[:errors].first
        expect(error[:suggestion]).to be_present
        expect(error[:suggestion]).to include('handle_welcome')
      end
    end

    context 'when metadata has invalid handler_type' do
      let(:invalid_type_service) do
        Class.new do
          include AppleMessagesForBusiness::BotServiceInterface

          def self.name
            'InvalidTypeService'
          end

          def self.handler_methods_metadata
            {
              handle_test: {
                handler_type: :invalid_type,
                display_name: 'Test',
                description: 'Test handler',
                category: 'test',
                status: :stable
              }
            }
          end

          def handle_test; end
        end
      end

      it 'includes warning about invalid handler type' do
        result = invalid_type_service.validate_handler_method(:handle_test)
        warning = result[:warnings].find { |w| w[:type] == 'invalid_handler_type' }
        expect(warning).to be_present
        expect(warning[:message]).to include('invalid_type')
      end
    end

    context 'when description is too short' do
      let(:short_desc_service) do
        Class.new do
          include AppleMessagesForBusiness::BotServiceInterface

          def self.name
            'ShortDescService'
          end

          def self.handler_methods_metadata
            {
              handle_test: {
                handler_type: :state,
                display_name: 'Test',
                description: 'Short',
                category: 'test',
                status: :stable
              }
            }
          end

          def handle_test; end
        end
      end

      it 'includes warning about short description' do
        result = short_desc_service.validate_handler_method(:handle_test)
        warning = result[:warnings].find { |w| w[:type] == 'short_description' }
        expect(warning).to be_present
      end
    end
  end

  describe 'HANDLER_TYPES constant' do
    it 'defines valid handler types' do
      expect(described_class::HANDLER_TYPES).to eq(%i[state keyword interactive action])
    end
  end

  describe 'error classes' do
    it 'defines HandlerMethodNotImplementedError' do
      expect(described_class::HandlerMethodNotImplementedError).to be < StandardError
    end

    it 'defines HandlerMethodNotFoundError' do
      expect(described_class::HandlerMethodNotFoundError).to be < StandardError
    end

    it 'defines InvalidHandlerTypeError' do
      expect(described_class::InvalidHandlerTypeError).to be < StandardError
    end
  end
end
# rubocop:enable RSpec/SpecFilePathFormat, Metrics/MethodLength
