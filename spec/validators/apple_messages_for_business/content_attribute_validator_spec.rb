# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ContentAttributeValidator do
  let(:account) { create(:account) }
  let(:channel) do
    allow_any_instance_of(Channel::AppleMessagesForBusiness).to receive(:validate_jwt_credentials).and_return(nil)
    create(:channel_apple_messages_for_business, account: account)
  end
  let(:inbox) { create(:inbox, channel: channel, account: account) }
  let(:conversation) { create(:conversation, inbox: inbox, account: account) }
  let(:message) { build(:message, conversation: conversation, account: account) }

  describe 'Apple List Picker validation' do
    before do
      message.content_type = 'apple_list_picker'
    end

    context 'with valid content_attributes' do
      before do
        message.content_attributes = {
          'sections' => [
            {
              'title' => 'Guitars',
              'items' => [
                { 'title' => 'Gibson Les Paul', 'subtitle' => 'Classic rock tone' },
                { 'title' => 'Fender Stratocaster', 'subtitle' => 'Versatile sound' }
              ]
            }
          ],
          'received_title' => 'Select a Guitar',
          'reply_title' => 'Guitar Selected'
        }
      end

      it 'passes validation' do
        expect(message).to be_valid
      end

      it 'auto-generates identifiers for items' do
        message.valid?
        items = message.content_attributes['sections'][0]['items']
        expect(items[0]['identifier']).to match(/^item_[a-f0-9]{16}$/)
        expect(items[1]['identifier']).to match(/^item_[a-f0-9]{16}$/)
      end

      it 'sets default style for items' do
        message.valid?
        items = message.content_attributes['sections'][0]['items']
        expect(items[0]['style']).to eq('icon')
        expect(items[1]['style']).to eq('icon')
      end

      it 'normalizes received and reply message styles' do
        message.valid?
        expect(message.content_attributes['received_style']).to eq('icon')
        expect(message.content_attributes['reply_style']).to eq('icon')
      end
    end

    context 'with legacy camelCase data' do
      before do
        message.content_attributes = {
          'sections' => [
            {
              'multipleSelection' => true, # Old camelCase
              'items' => [
                { 'title' => 'Option 1', 'imageIdentifier' => 'img_123' } # Old camelCase
              ]
            }
          ]
        }
      end

      it 'converts camelCase to snake_case' do
        message.valid?
        section = message.content_attributes['sections'][0]
        expect(section['multiple_selection']).to be true
        expect(section).not_to have_key('multipleSelection')

        item = section['items'][0]
        expect(item['image_identifier']).to eq('img_123')
        expect(item).not_to have_key('imageIdentifier')
      end
    end

    context 'with images' do
      before do
        message.content_attributes = {
          'sections' => [{
            'items' => [
              { 'title' => 'Guitar', 'image_identifier' => 'guitar_img' }
            ]
          }],
          'images' => [
            { 'data' => 'base64data', 'description' => 'Guitar image' }
          ]
        }
      end

      it 'auto-generates image identifiers' do
        message.valid?
        image = message.content_attributes['images'][0]
        expect(image['identifier']).to match(/^img_[a-f0-9]{16}$/)
      end
    end

    context 'with invalid content_attributes' do
      it 'fails when sections are missing' do
        message.content_attributes = { 'title' => 'No sections' }
        expect(message).not_to be_valid
        expect(message.errors[:content_attributes]).to include('sections is required for apple_list_picker')
      end

      it 'fails with invalid style values' do
        message.content_attributes = {
          'sections' => [{ 'items' => [{ 'title' => 'Item', 'style' => 'invalid_style' }] }],
          'received_style' => 'wrong_style'
        }
        expect(message).not_to be_valid
        expect(message.errors[:content_attributes][0]).to include('invalid style value: invalid_style')
        expect(message.errors[:content_attributes][1]).to include('received_style has invalid value: wrong_style')
      end

      it 'fails with invalid keys' do
        message.content_attributes = {
          'sections' => [],
          'invalid_key' => 'value'
        }
        expect(message).not_to be_valid
        expect(message.errors[:content_attributes][0]).to include('invalid keys for apple_list_picker: [:invalid_key]')
      end
    end

    context 'with incoming interactive response' do
      before do
        message.content_attributes = {
          'interactive_data' => { 'data' => { 'requestIdentifier' => 'lp_123' } }
        }
      end

      it 'skips validation for interactive_data' do
        expect(message).to be_valid
      end
    end
  end

  describe 'Apple Time Picker validation' do
    before do
      message.content_type = 'apple_time_picker'
    end

    context 'with valid content_attributes' do
      before do
        message.content_attributes = {
          'event' => {
            'title' => 'Schedule Lesson',
            'timeslots' => [
              { 'startTime' => '2024-01-15T14:30+0000', 'duration' => 3600 },
              { 'startTime' => '2024-01-15T15:30+0000', 'duration' => 3600 }
            ]
          },
          'received_title' => 'Select a time'
        }
      end

      it 'passes validation' do
        expect(message).to be_valid
      end

      it 'auto-generates identifiers for timeslots' do
        message.valid?
        timeslots = message.content_attributes['event']['timeslots']
        expect(timeslots[0]['identifier']).to be_present
        expect(timeslots[1]['identifier']).to be_present
      end

      it 'normalizes event structure' do
        message.valid?
        event = message.content_attributes['event']
        expect(event['identifier']).to eq('1')
        expect(event['title']).to eq('')
      end
    end

    context 'with top-level timeslots' do
      before do
        message.content_attributes = {
          'event' => {},
          'timeslots' => [
            { 'startTime' => '2024-01-15T14:30+0000', 'duration' => 3600 }
          ],
          'timezone_offset' => 3600
        }
      end

      it 'moves timeslots and timezone into event structure' do
        message.valid?
        event = message.content_attributes['event']
        expect(event['timeslots']).to be_present
        expect(event['timezoneOffset']).to eq(3600)
        expect(message.content_attributes).not_to have_key('timeslots')
        expect(message.content_attributes).not_to have_key('timezone_offset')
      end
    end

    context 'with invalid content_attributes' do
      it 'fails when event is missing' do
        message.content_attributes = { 'title' => 'No event' }
        expect(message).not_to be_valid
        expect(message.errors[:content_attributes]).to include('event is required for apple_time_picker')
      end

      it 'fails when timeslot data is incomplete' do
        message.content_attributes = {
          'event' => {},
          'timeslots' => [{ 'duration' => 3600 }] # Missing startTime
        }
        message.valid?
        expect(message).not_to be_valid
        expect(message.errors[:content_attributes]).to include('timeslot 0 missing startTime')
      end
    end
  end

  describe 'Apple Quick Reply validation' do
    before do
      message.content_type = 'apple_quick_reply'
    end

    context 'with valid content_attributes' do
      before do
        message.content_attributes = {
          'summary_text' => 'Choose an option',
          'items' => [
            { 'title' => 'Yes' },
            { 'title' => 'No' }
          ]
        }
      end

      it 'passes validation' do
        expect(message).to be_valid
      end

      it 'auto-generates identifiers for items' do
        message.valid?
        items = message.content_attributes['items']
        expect(items[0]['identifier']).to match(/^reply_[a-f0-9]{16}$/)
        expect(items[1]['identifier']).to match(/^reply_[a-f0-9]{16}$/)
      end

      it 'uses message content as fallback for summary_text' do
        message.content = 'Select one'
        message.content_attributes = { 'items' => [{ 'title' => 'A' }, { 'title' => 'B' }] }
        message.valid?
        expect(message.content_attributes['summary_text']).to eq('Select one')
      end
    end

    context 'with invalid content_attributes' do
      it 'fails with too few items' do
        message.content_attributes = {
          'items' => [{ 'title' => 'Only one' }]
        }
        expect(message).not_to be_valid
        expect(message.errors[:content_attributes]).to include('apple_quick_reply must have between 2-5 items')
      end

      it 'fails with too many items' do
        message.content_attributes = {
          'items' => (1..6).map { |i| { 'title' => "Item #{i}" } }
        }
        expect(message).not_to be_valid
        expect(message.errors[:content_attributes]).to include('apple_quick_reply must have between 2-5 items')
      end

      it 'fails when items are missing' do
        message.content_attributes = { 'summary_text' => 'No items' }
        expect(message).not_to be_valid
        expect(message.errors[:content_attributes]).to include('items is required for apple_quick_reply')
      end
    end
  end

  describe 'Apple Rich Link validation' do
    before do
      message.content_type = 'apple_rich_link'
    end

    context 'with valid content_attributes' do
      before do
        message.content_attributes = {
          'url' => 'https://www.apple.com',
          'title' => 'Apple',
          'description' => 'Apple homepage',
          'image_data' => 'base64data',
          'image_mime_type' => 'image/png'
        }
      end

      it 'passes validation' do
        expect(message).to be_valid
      end
    end

    context 'with invalid content_attributes' do
      it 'fails without required fields' do
        message.content_attributes = {}
        expect(message).not_to be_valid
        expect(message.errors[:content_attributes]).to include('url is required for apple_rich_link')
        expect(message.errors[:content_attributes]).to include('title is required for apple_rich_link')
      end

      it 'fails with invalid URL' do
        message.content_attributes = {
          'url' => 'not-a-url',
          'title' => 'Invalid'
        }
        expect(message).not_to be_valid
        expect(message.errors[:content_attributes]).to include('url must be a valid URL')
      end

      it 'fails with image data but no mime type' do
        message.content_attributes = {
          'url' => 'https://example.com',
          'title' => 'Example',
          'image_data' => 'base64data'
        }
        expect(message).not_to be_valid
        expect(message.errors[:content_attributes]).to include('image_mime_type is required when image_data is provided')
      end

      it 'fails with invalid image mime type' do
        message.content_attributes = {
          'url' => 'https://example.com',
          'title' => 'Example',
          'image_data' => 'base64data',
          'image_mime_type' => 'image/webp'
        }
        expect(message).not_to be_valid
        expect(message.errors[:content_attributes]).to include('image_mime_type must be image/jpeg, image/png, or image/gif')
      end
    end
  end

  describe 'Apple Pay validation' do
    before do
      message.content_type = 'apple_pay'
    end

    context 'with flat format' do
      before do
        message.content_attributes = {
          'merchant_name' => 'Acoustic House',
          'currency_code' => 'USD',
          'country_code' => 'US',
          'line_items' => [
            { 'label' => 'Guitar', 'amount' => '999.99' }
          ],
          'total' => { 'label' => 'Total', 'amount' => '999.99' }
        }
      end

      it 'passes validation' do
        expect(message).to be_valid
      end
    end

    context 'with nested payment_request format' do
      before do
        message.content_attributes = {
          'payment_request' => {
            'country_code' => 'US',
            'currency_code' => 'USD',
            'supported_networks' => %w[visa masterCard],
            'merchant_capabilities' => ['3DS'],
            'total' => { 'label' => 'Total', 'amount' => '999.99' }
          }
        }
      end

      it 'passes validation' do
        expect(message).to be_valid
      end
    end

    context 'with invalid content_attributes' do
      it 'fails without required flat fields' do
        message.content_attributes = { 'merchant_name' => 'Test' }
        expect(message).not_to be_valid
        expect(message.errors[:content_attributes]).to include('currency_code is required for apple_pay')
        expect(message.errors[:content_attributes]).to include('country_code is required for apple_pay')
      end

      it 'fails with invalid line_items structure' do
        message.content_attributes = {
          'merchant_name' => 'Test',
          'currency_code' => 'USD',
          'country_code' => 'US',
          'line_items' => 'not an array',
          'total' => { 'label' => 'Total', 'amount' => '10' }
        }
        expect(message).not_to be_valid
        expect(message.errors[:content_attributes]).to include('line_items must be an array')
      end

      it 'fails with invalid total structure' do
        message.content_attributes = {
          'merchant_name' => 'Test',
          'currency_code' => 'USD',
          'country_code' => 'US',
          'line_items' => [],
          'total' => { 'label' => 'Total' } # Missing amount
        }
        expect(message).not_to be_valid
        expect(message.errors[:content_attributes]).to include('total must have label and amount')
      end
    end
  end

  describe 'Apple Authentication validation' do
    before do
      message.content_type = 'apple_authentication'
    end

    context 'with valid content_attributes' do
      before do
        message.content_attributes = {
          'oauth2' => {
            'provider' => 'google',
            'client_id' => 'abc123',
            'redirect_uri' => 'https://example.com/callback'
          },
          'response_encryption_key' => 'encryption_key_here'
        }
      end

      it 'passes validation' do
        expect(message).to be_valid
      end
    end

    context 'with invalid content_attributes' do
      it 'fails without oauth2' do
        message.content_attributes = { 'response_encryption_key' => 'key' }
        expect(message).not_to be_valid
        expect(message.errors[:content_attributes]).to include('oauth2 is required for apple_authentication')
      end

      it 'fails without response_encryption_key' do
        message.content_attributes = {
          'oauth2' => { 'provider' => 'google', 'client_id' => 'abc', 'redirect_uri' => 'https://example.com' }
        }
        expect(message).not_to be_valid
        expect(message.errors[:content_attributes]).to include('response_encryption_key is required for apple_authentication')
      end

      it 'fails with incomplete oauth2 config' do
        message.content_attributes = {
          'oauth2' => { 'provider' => 'google' }, # Missing client_id and redirect_uri
          'response_encryption_key' => 'key'
        }
        expect(message).not_to be_valid
        expect(message.errors[:content_attributes]).to include('oauth2 missing required field: client_id')
        expect(message.errors[:content_attributes]).to include('oauth2 missing required field: redirect_uri')
      end
    end

    context 'with incoming interactive response' do
      before do
        message.content_attributes = {
          'interactive_data' => { 'data' => { 'authenticate' => { 'code' => 'auth_code' } } }
        }
      end

      it 'skips validation for interactive_data' do
        expect(message).to be_valid
      end
    end
  end

  describe 'Apple Form validation' do
    before do
      message.content_type = 'apple_form'
    end

    context 'with pages-based format' do
      before do
        message.content_attributes = {
          'title' => 'Contact Form',
          'pages' => [
            {
              'page_id' => 'page1',
              'type' => 'module',
              'items' => [
                { 'item_type' => 'text', 'title' => 'Name' }
              ]
            }
          ]
        }
      end

      it 'passes validation' do
        expect(message).to be_valid
      end
    end

    context 'with legacy fields format' do
      before do
        message.content_attributes = {
          'fields' => [
            { 'type' => 'text', 'label' => 'Name' }
          ],
          'submit_url' => 'https://example.com/submit'
        }
      end

      it 'passes validation' do
        expect(message).to be_valid
      end
    end

    context 'with invalid content_attributes' do
      it 'fails without pages or fields' do
        message.content_attributes = { 'title' => 'Empty form' }
        expect(message).not_to be_valid
        expect(message.errors[:content_attributes]).to include('either pages or fields is required for apple_form')
      end

      it 'fails when pages is not an array' do
        message.content_attributes = {
          'title' => 'Form',
          'pages' => 'not an array'
        }
        expect(message).not_to be_valid
        expect(message.errors[:content_attributes]).to include('pages must be an array')
      end

      it 'fails when legacy format missing submit_url' do
        message.content_attributes = {
          'fields' => [{ 'type' => 'text' }]
        }
        expect(message).not_to be_valid
        expect(message.errors[:content_attributes]).to include('submit_url is required for apple_form')
      end
    end
  end

  describe 'Apple Custom App validation' do
    before do
      message.content_type = 'apple_custom_app'
    end

    context 'with valid content_attributes' do
      before do
        message.content_attributes = {
          'app_id' => '123456789',
          'bid' => 'com.example.app',
          'app_name' => 'Example App',
          'url' => 'https://example.com/app'
        }
      end

      it 'passes validation' do
        expect(message).to be_valid
      end

      it 'allows missing URL (optional for third-party apps)' do
        message.content_attributes.delete('url')
        expect(message).to be_valid
      end
    end

    context 'with invalid content_attributes' do
      it 'fails without app_id' do
        message.content_attributes = { 'bid' => 'com.example.app' }
        expect(message).not_to be_valid
        expect(message.errors[:content_attributes]).to include('app_id is required for apple_custom_app')
      end

      it 'fails without bid' do
        message.content_attributes = { 'app_id' => '123' }
        expect(message).not_to be_valid
        expect(message.errors[:content_attributes]).to include('bid is required for apple_custom_app')
      end

      it 'fails with invalid keys' do
        message.content_attributes = {
          'app_id' => '123',
          'bid' => 'com.example',
          'invalid_key' => 'value'
        }
        expect(message).not_to be_valid
        expect(message.errors[:content_attributes][0]).to include('invalid keys for apple_custom_app: [:invalid_key]')
      end
    end
  end

  describe 'Standard content types' do
    context 'input_select' do
      before do
        message.content_type = 'input_select'
        message.content_attributes = {
          'items' => [
            { 'title' => 'Option 1', 'value' => '1' },
            { 'title' => 'Option 2', 'value' => '2' }
          ]
        }
      end

      it 'passes validation' do
        expect(message).to be_valid
      end

      it 'fails with invalid keys' do
        message.content_attributes['items'][0]['invalid_key'] = 'value'
        expect(message).not_to be_valid
        expect(message.errors[:content_attributes][0]).to include('invalid keys for items : [:invalid_key]')
      end
    end

    context 'cards' do
      before do
        message.content_type = 'cards'
        message.content_attributes = {
          'items' => [
            {
              'title' => 'Card 1',
              'description' => 'Description',
              'actions' => [
                { 'text' => 'Click', 'type' => 'link', 'uri' => 'https://example.com' }
              ]
            }
          ]
        }
      end

      it 'passes validation' do
        expect(message).to be_valid
      end

      it 'fails without actions' do
        message.content_attributes['items'][0].delete('actions')
        expect(message).not_to be_valid
        expect(message.errors[:content_attributes]).to include('contains items missing actions')
      end
    end
  end
end
