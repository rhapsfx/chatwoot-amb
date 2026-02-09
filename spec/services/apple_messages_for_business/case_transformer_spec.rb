# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AppleMessagesForBusiness::CaseTransformer do
  describe '.to_apple_format' do
    context 'with simple field mappings' do
      it 'converts snake_case to camelCase' do
        input = {
          'image_identifier' => 'img_123',
          'multiple_selection' => true,
          'timezone_offset' => -480,
          'start_time' => '2025-10-26T10:00+0000',
          'summary_text' => 'Quick Reply'
        }

        result = described_class.to_apple_format(input)

        expect(result).to eq({
                               imageIdentifier: 'img_123',
                               multipleSelection: true,
                               timezoneOffset: -480,
                               startTime: '2025-10-26T10:00+0000',
                               summaryText: 'Quick Reply'
                             })
      end

      it 'skips nil values' do
        input = {
          'image_identifier' => 'img_123',
          'multiple_selection' => nil,
          'timezone_offset' => -480
        }

        result = described_class.to_apple_format(input)

        expect(result).to eq({
                               imageIdentifier: 'img_123',
                               timezoneOffset: -480
                             })
      end

      it 'preserves standard Apple MSP keys' do
        input = {
          'identifier' => 'item_1',
          'title' => 'Option 1',
          'subtitle' => 'Description',
          'style' => 'icon',
          'order' => 0
        }

        result = described_class.to_apple_format(input)

        expect(result).to eq({
                               identifier: 'item_1',
                               title: 'Option 1',
                               subtitle: 'Description',
                               style: 'icon',
                               order: 0
                             })
      end
    end

    context 'with received_message context' do
      it 'strips received_ prefix and converts to camelCase' do
        input = {
          'received_title' => 'Select an option',
          'received_subtitle' => 'Please choose',
          'received_image_identifier' => 'img_456',
          'received_style' => 'large'
        }

        result = described_class.to_apple_format(input, context: :received_message)

        expect(result).to eq({
                               title: 'Select an option',
                               subtitle: 'Please choose',
                               imageIdentifier: 'img_456',
                               style: 'large'
                             })
      end

      it 'handles mixed context and standard fields' do
        input = {
          'received_title' => 'Title',
          'identifier' => 'msg_123',
          'version' => '1.0'
        }

        result = described_class.to_apple_format(input, context: :received_message)

        expect(result).to eq({
                               title: 'Title',
                               identifier: 'msg_123',
                               version: '1.0'
                             })
      end
    end

    context 'with reply_message context' do
      it 'strips reply_ prefix and converts to camelCase' do
        input = {
          'reply_title' => 'Selected',
          'reply_subtitle' => 'Your choice',
          'reply_image_identifier' => 'img_789',
          'reply_style' => 'icon',
          'reply_image_title' => 'Image Title',
          'reply_image_subtitle' => 'Image Subtitle',
          'reply_secondary_subtitle' => 'Secondary',
          'reply_tertiary_subtitle' => 'Tertiary'
        }

        result = described_class.to_apple_format(input, context: :reply_message)

        expect(result).to eq({
                               title: 'Selected',
                               subtitle: 'Your choice',
                               imageIdentifier: 'img_789',
                               style: 'icon',
                               imageTitle: 'Image Title',
                               imageSubtitle: 'Image Subtitle',
                               secondarySubtitle: 'Secondary',
                               tertiarySubtitle: 'Tertiary'
                             })
      end
    end

    context 'with nested structures' do
      it 'transforms nested hashes' do
        input = {
          'received_message' => {
            'title' => 'Select',
            'image_identifier' => 'img_123'
          },
          'reply_message' => {
            'title' => 'Selected',
            'image_identifier' => 'img_456'
          }
        }

        result = described_class.to_apple_format(input)

        expect(result).to eq({
                               receivedMessage: {
                                 title: 'Select',
                                 imageIdentifier: 'img_123'
                               },
                               replyMessage: {
                                 title: 'Selected',
                                 imageIdentifier: 'img_456'
                               }
                             })
      end

      it 'auto-detects nested context from key patterns' do
        input = {
          'received_title' => 'Main Title',
          'received_image_identifier' => 'main_img',
          'nested_data' => {
            'received_title' => 'Nested Title',
            'received_subtitle' => 'Nested Subtitle'
          }
        }

        result = described_class.to_apple_format(input, context: :received_message)

        # Main level uses received_message context
        expect(result[:title]).to eq('Main Title')
        expect(result[:imageIdentifier]).to eq('main_img')

        # Nested level auto-detects received_message context
        expect(result[:nestedData][:title]).to eq('Nested Title')
        expect(result[:nestedData][:subtitle]).to eq('Nested Subtitle')
      end
    end

    context 'with arrays' do
      it 'transforms array elements' do
        input = {
          'sections' => [
            {
              'title' => 'Section 1',
              'multiple_selection' => true,
              'items' => [
                {
                  'identifier' => 'item_1',
                  'title' => 'Option 1',
                  'image_identifier' => 'img_1'
                },
                {
                  'identifier' => 'item_2',
                  'title' => 'Option 2',
                  'image_identifier' => 'img_2'
                }
              ]
            }
          ]
        }

        result = described_class.to_apple_format(input)

        expect(result[:sections]).to be_an(Array)
        expect(result[:sections].first[:multipleSelection]).to eq(true)
        expect(result[:sections].first[:items].first[:imageIdentifier]).to eq('img_1')
        expect(result[:sections].first[:items].second[:imageIdentifier]).to eq('img_2')
      end
    end

    context 'with list picker data' do
      it 'transforms complete list picker structure' do
        input = {
          'sections' => [
            {
              'title' => 'Options',
              'multiple_selection' => false,
              'order' => 0,
              'items' => [
                {
                  'identifier' => 'item_1',
                  'title' => 'Option 1',
                  'subtitle' => 'Description 1',
                  'image_identifier' => 'img_123',
                  'order' => 0,
                  'style' => 'icon'
                }
              ]
            }
          ],
          'images' => [
            {
              'identifier' => 'img_123',
              'data' => 'base64data...',
              'description' => 'Test image'
            }
          ]
        }

        result = described_class.to_apple_format(input)

        # Check section
        section = result[:sections].first
        expect(section[:title]).to eq('Options')
        expect(section[:multipleSelection]).to eq(false)
        expect(section[:order]).to eq(0)

        # Check item
        item = section[:items].first
        expect(item[:identifier]).to eq('item_1')
        expect(item[:title]).to eq('Option 1')
        expect(item[:subtitle]).to eq('Description 1')
        expect(item[:imageIdentifier]).to eq('img_123')
        expect(item[:order]).to eq(0)
        expect(item[:style]).to eq('icon')

        # Check images
        image = result[:images].first
        expect(image[:identifier]).to eq('img_123')
        expect(image[:data]).to eq('base64data...')
        expect(image[:description]).to eq('Test image')
      end
    end

    context 'with time picker data' do
      it 'transforms complete time picker structure' do
        input = {
          'event' => {
            'identifier' => '1',
            'title' => 'Appointment',
            'timezone_offset' => -480,
            'timeslots' => [
              {
                'identifier' => 'slot_1',
                'start_time' => '2025-10-26T10:00+0000',
                'duration' => 3600
              },
              {
                'identifier' => 'slot_2',
                'start_time' => '2025-10-26T12:00+0000',
                'duration' => 3600
              }
            ]
          }
        }

        result = described_class.to_apple_format(input)

        # Check event
        event = result[:event]
        expect(event[:identifier]).to eq('1')
        expect(event[:title]).to eq('Appointment')
        expect(event[:timezoneOffset]).to eq(-480)

        # Check timeslots
        slot1 = event[:timeslots].first
        expect(slot1[:identifier]).to eq('slot_1')
        expect(slot1[:startTime]).to eq('2025-10-26T10:00+0000')
        expect(slot1[:duration]).to eq(3600)

        slot2 = event[:timeslots].second
        expect(slot2[:identifier]).to eq('slot_2')
        expect(slot2[:startTime]).to eq('2025-10-26T12:00+0000')
      end
    end

    context 'with form data' do
      it 'transforms form-specific fields' do
        input = {
          'pages' => [
            {
              'page_id' => 'page_1',
              'title' => 'Contact Info',
              'items' => [
                {
                  'item_id' => 'name',
                  'item_type' => 'text',
                  'title' => 'Name',
                  'required' => true,
                  'max_length' => 100
                }
              ]
            }
          ],
          'show_summary' => false,
          'use_live_layout' => true
        }

        result = described_class.to_apple_format(input)

        expect(result[:showSummary]).to eq(false)
        expect(result[:useLiveLayout]).to eq(true)

        page = result[:pages].first
        expect(page[:pageIdentifier]).to eq('page_1')

        item = page[:items].first
        expect(item[:itemId]).to eq('name')
        expect(item[:itemType]).to eq('text')
        expect(item[:maxLength]).to eq(100)
      end
    end
  end

  describe '.from_apple_format' do
    context 'with simple field mappings' do
      it 'converts camelCase to snake_case' do
        input = {
          'imageIdentifier' => 'img_123',
          'multipleSelection' => true,
          'timezoneOffset' => -480,
          'startTime' => '2025-10-26T10:00+0000',
          'summaryText' => 'Quick Reply'
        }

        result = described_class.from_apple_format(input)

        expect(result).to eq({
                               'image_identifier' => 'img_123',
                               'multiple_selection' => true,
                               'timezone_offset' => -480,
                               'start_time' => '2025-10-26T10:00+0000',
                               'summary_text' => 'Quick Reply'
                             })
      end

      it 'skips nil values' do
        input = {
          'imageIdentifier' => 'img_123',
          'multipleSelection' => nil,
          'timezoneOffset' => -480
        }

        result = described_class.from_apple_format(input)

        expect(result).to eq({
                               'image_identifier' => 'img_123',
                               'timezone_offset' => -480
                             })
      end

      it 'preserves standard Apple MSP keys' do
        input = {
          'identifier' => 'item_1',
          'title' => 'Option 1',
          'subtitle' => 'Description',
          'style' => 'icon',
          'order' => 0
        }

        result = described_class.from_apple_format(input)

        expect(result).to eq({
                               'identifier' => 'item_1',
                               'title' => 'Option 1',
                               'subtitle' => 'Description',
                               'style' => 'icon',
                               'order' => 0
                             })
      end
    end

    context 'with nested structures' do
      it 'transforms nested hashes' do
        input = {
          'receivedMessage' => {
            'title' => 'Select',
            'imageIdentifier' => 'img_123'
          },
          'replyMessage' => {
            'title' => 'Selected',
            'imageIdentifier' => 'img_456'
          }
        }

        result = described_class.from_apple_format(input)

        expect(result).to eq({
                               'received_message' => {
                                 'title' => 'Select',
                                 'image_identifier' => 'img_123'
                               },
                               'reply_message' => {
                                 'title' => 'Selected',
                                 'image_identifier' => 'img_456'
                               }
                             })
      end

      it 'transforms deeply nested structures' do
        input = {
          'sections' => [
            {
              'multipleSelection' => true,
              'items' => [
                { 'imageIdentifier' => 'img_1' },
                { 'imageIdentifier' => 'img_2' }
              ]
            }
          ]
        }

        result = described_class.from_apple_format(input)

        expect(result['sections'].first['multiple_selection']).to eq(true)
        expect(result['sections'].first['items'].first['image_identifier']).to eq('img_1')
        expect(result['sections'].first['items'].second['image_identifier']).to eq('img_2')
      end
    end

    context 'with frontend input (mixed camelCase)' do
      it 'normalizes frontend list picker data' do
        frontend_input = {
          'imageIdentifier' => 'img_main',
          'receivedImageIdentifier' => 'img_received',
          'replyImageIdentifier' => 'img_reply',
          'sections' => [
            {
              'title' => 'Options',
              'multipleSelection' => false,
              'items' => [
                {
                  'identifier' => 'item_1',
                  'title' => 'Option 1',
                  'imageIdentifier' => 'img_item'
                }
              ]
            }
          ]
        }

        result = described_class.from_apple_format(frontend_input)

        # All converted to snake_case
        expect(result['image_identifier']).to eq('img_main')
        expect(result['received_image_identifier']).to eq('img_received')
        expect(result['reply_image_identifier']).to eq('img_reply')
        expect(result['sections'].first['multiple_selection']).to eq(false)
        expect(result['sections'].first['items'].first['image_identifier']).to eq('img_item')
      end

      it 'normalizes frontend time picker data' do
        frontend_input = {
          'event' => {
            'timezoneOffset' => -480,
            'timeslots' => [
              {
                'startTime' => '2025-10-26T10:00+0000'
              }
            ]
          },
          'receivedTitle' => 'Select a time',
          'replyTitle' => 'Time selected'
        }

        result = described_class.from_apple_format(frontend_input)

        expect(result['event']['timezone_offset']).to eq(-480)
        expect(result['event']['timeslots'].first['start_time']).to eq('2025-10-26T10:00+0000')
        expect(result['received_title']).to eq('Select a time')
        expect(result['reply_title']).to eq('Time selected')
      end
    end
  end

  describe '.normalize_content_attributes' do
    it 'is an alias for from_apple_format' do
      input = {
        'imageIdentifier' => 'img_123',
        'multipleSelection' => true
      }

      result = described_class.normalize_content_attributes(input)

      expect(result).to eq({
                             'image_identifier' => 'img_123',
                             'multiple_selection' => true
                           })
    end
  end

  describe 'round-trip transformation' do
    it 'maintains data integrity through to_apple_format → from_apple_format' do
      original = {
        'image_identifier' => 'img_123',
        'multiple_selection' => true,
        'timezone_offset' => -480,
        'sections' => [
          {
            'title' => 'Section 1',
            'items' => [
              { 'identifier' => 'item_1', 'image_identifier' => 'img_item' }
            ]
          }
        ]
      }

      # Convert to Apple format
      apple_format = described_class.to_apple_format(original)

      # Convert back to internal format
      back_to_internal = described_class.from_apple_format(
        apple_format.transform_keys(&:to_s)
      )

      # Should match original (structure preserved)
      expect(back_to_internal['image_identifier']).to eq(original['image_identifier'])
      expect(back_to_internal['multiple_selection']).to eq(original['multiple_selection'])
      expect(back_to_internal['timezone_offset']).to eq(original['timezone_offset'])
      expect(back_to_internal['sections'].first['title']).to eq(
        original['sections'].first['title']
      )
      expect(back_to_internal['sections'].first['items'].first['image_identifier']).to eq(
        original['sections'].first['items'].first['image_identifier']
      )
    end
  end

  describe 'edge cases' do
    it 'handles empty hashes' do
      expect(described_class.to_apple_format({})).to eq({})
      expect(described_class.from_apple_format({})).to eq({})
    end

    it 'handles nil input gracefully' do
      expect(described_class.to_apple_format(nil)).to be_nil
      expect(described_class.from_apple_format(nil)).to be_nil
    end

    it 'handles non-hash input gracefully' do
      expect(described_class.to_apple_format('string')).to eq('string')
      expect(described_class.from_apple_format(123)).to eq(123)
    end

    it 'handles arrays with mixed types' do
      input = {
        'items' => ['string', 123, { 'image_identifier' => 'img' }, nil]
      }

      result = described_class.to_apple_format(input)

      expect(result[:items]).to eq(['string', 123, { imageIdentifier: 'img' }, nil])
    end

    it 'handles deeply nested structures' do
      input = {
        'level1' => {
          'level2' => {
            'level3' => {
              'image_identifier' => 'deep_img',
              'multiple_selection' => true
            }
          }
        }
      }

      result = described_class.to_apple_format(input)

      expect(
        result[:level1][:level2][:level3][:imageIdentifier]
      ).to eq('deep_img')
      expect(
        result[:level1][:level2][:level3][:multipleSelection]
      ).to eq(true)
    end
  end
end
