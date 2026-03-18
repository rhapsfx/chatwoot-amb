# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AppleMessagesForBusiness::SendTimePickerService do
  let(:account) { create(:account) }
  let(:channel) do
    allow_any_instance_of(Channel::AppleMessagesForBusiness).to receive(:validate_jwt_credentials).and_return(nil)
    create(:channel_apple_messages_for_business, account: account)
  end
  let(:inbox) { channel.inbox }
  let(:conversation) { create(:conversation, inbox: inbox, account: account) }
  let(:destination_id) { 'urn:mbid:AQAAY1234567890' }

  let(:base_content_attributes) do
    {
      'request_identifier' => 'time_0319',
      'received_title' => 'Schedule a lesson',
      'received_subtitle' => 'Apple Park',
      'received_image_identifier' => 'time_picker_lesson',
      'reply_title' => 'Thank you!',
      'reply_image_identifier' => 'time_picker_lesson',
      'received_style' => 'icon',
      'reply_style' => 'icon',
      'event' => {
        'identifier' => 'evt-001',
        'title' => 'Guitar Lesson',
        'location' => {
          'latitude' => 37.332863,
          'longitude' => -122.005374,
          'radius' => 100,
          'title' => 'Apple Park'
        },
        'timeslots' => [
          { 'identifier' => '0', 'start_time' => '2026-03-16T20:30:00Z', 'duration' => 3600 },
          { 'identifier' => '1', 'start_time' => '2026-03-16T22:00:00Z', 'duration' => 3600 }
        ]
      }
    }
  end

  let(:message) do
    create(:message,
           conversation: conversation,
           account: account,
           message_type: :outgoing,
           content_type: 'apple_time_picker',
           content_attributes: base_content_attributes)
  end

  let(:service) { described_class.new(channel: channel, destination_id: destination_id, message: message) }

  before do
    allow(channel).to receive(:generate_jwt_token).and_return('mock-jwt-token')
    allow(Redis::Alfred).to receive(:get).and_return(nil)
    allow(Redis::Alfred).to receive(:set).and_return(true)
    allow(Redis::Alfred).to receive(:setex).and_return(true)
    allow(Redis::Alfred).to receive(:delete).and_return(true)
    # No images by default — override per context when needed
    allow_any_instance_of(AppleMessagesForBusiness::ImageFetchService)
      .to receive(:fetch_and_encode).and_return([])
    # Stub content_attributes to bypass Rails store DB round-trip quirks
    allow(service).to receive(:content_attributes).and_return(base_content_attributes)
  end

  describe '#build_interactive_data' do
    # CaseTransformer.to_apple_format returns symbol keys throughout
    subject(:interactive_data) { service.send(:build_interactive_data) }

    it 'includes bid' do
      expect(interactive_data[:bid]).to include('com.apple.messages')
    end

    it 'does not include useLiveLayout (not in Apple MSP time picker spec)' do
      expect(interactive_data).not_to have_key(:useLiveLayout)
    end

    it 'uses mspVersion (not version) inside data per Apple MSP reference' do
      expect(interactive_data[:data]).to have_key(:mspVersion)
      expect(interactive_data[:data][:mspVersion]).to eq('1.0')
      expect(interactive_data[:data]).not_to have_key(:version)
    end

    it 'includes requestIdentifier inside data' do
      expect(interactive_data[:data][:requestIdentifier]).to eq('time_0319')
    end

    it 'includes event inside data with camelCase keys' do
      event = interactive_data[:data][:event]
      expect(event[:title]).to eq('Guitar Lesson')
      expect(event[:identifier]).to eq('evt-001')
    end

    it 'includes timeslots with camelCase startTime' do
      timeslots = interactive_data[:data][:event][:timeslots]
      expect(timeslots).to be_an(Array)
      expect(timeslots.first).to have_key(:startTime)
      expect(timeslots.first).not_to have_key(:start_time)
    end

    it 'includes receivedMessage with camelCase imageIdentifier and icon style' do
      received = interactive_data[:receivedMessage]
      expect(received[:title]).to eq('Schedule a lesson')
      expect(received[:imageIdentifier]).to eq('time_picker_lesson')
      expect(received[:style]).to eq('icon')
    end

    it 'includes replyMessage with camelCase imageIdentifier' do
      reply = interactive_data[:replyMessage]
      expect(reply[:title]).to eq('Thank you!')
      expect(reply[:imageIdentifier]).to eq('time_picker_lesson')
    end

    context 'default styles when none specified' do
      before do
        allow(service).to receive(:content_attributes)
          .and_return(base_content_attributes.except('received_style', 'reply_style'))
      end

      it 'defaults received_style to icon (matches Apple MSP reference implementation)' do
        expect(interactive_data[:receivedMessage][:style]).to eq('icon')
      end

      it 'defaults reply_style to icon' do
        expect(interactive_data[:replyMessage][:style]).to eq('icon')
      end
    end

    context 'images placement' do
      let(:encoded_image) do
        { identifier: 'time_picker_lesson', data: 'base64encodeddata==', description: 'Lesson icon' }
      end

      before do
        allow_any_instance_of(AppleMessagesForBusiness::ImageFetchService)
          .to receive(:fetch_and_encode).and_return([encoded_image])
      end

      it 'places images inside data (interactiveData.data.images) per Apple MSP spec' do
        expect(interactive_data[:data][:images]).to be_present
        expect(interactive_data).not_to have_key(:images)
      end

      it 'includes the correct image identifier in the images array' do
        image = interactive_data[:data][:images].find { |img| img[:identifier] == 'time_picker_lesson' }
        expect(image).to be_present
        expect(image[:data]).to eq('base64encodeddata==')
      end

      it 'returns only Apple-spec fields for each image (identifier, data, description)' do
        image = interactive_data[:data][:images].first
        expect(image.keys).to match_array(%i[identifier data description])
      end
    end

    context 'when no images are found' do
      it 'omits the images key from both interactiveData and data' do
        expect(interactive_data).not_to have_key(:images)
        expect(interactive_data[:data]).not_to have_key(:images)
      end
    end
  end

  describe '#build_reply_message' do
    context 'when reply_image_identifier is blank' do
      before do
        allow(service).to receive(:content_attributes)
          .and_return(base_content_attributes.except('reply_image_identifier'))
      end

      it 'falls back to received_image_identifier' do
        reply = service.send(:build_reply_message)
        expect(reply[:imageIdentifier]).to eq('time_picker_lesson')
      end
    end

    context 'when reply_image_identifier is explicitly set' do
      before do
        allow(service).to receive(:content_attributes)
          .and_return(base_content_attributes.merge('reply_image_identifier' => 'reply_icon'))
      end

      it 'uses reply_image_identifier' do
        reply = service.send(:build_reply_message)
        expect(reply[:imageIdentifier]).to eq('reply_icon')
      end
    end
  end

  describe '#build_timeslots' do
    let(:raw_slots) do
      [{ 'identifier' => '0', 'start_time' => '2026-03-16T20:30:00Z', 'duration' => 3600 }]
    end

    it 'converts start_time to ISO-8601 format without seconds' do
      timeslots = service.send(:build_timeslots, raw_slots)
      # Format must be YYYY-MM-DDTHH:MM+0000 — no seconds component
      expect(timeslots.first['start_time']).to match(/\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}\+0000\z/)
    end

    it 'does not include seconds in the time format' do
      timeslots = service.send(:build_timeslots, raw_slots)
      expect(timeslots.first['start_time']).not_to match(/T\d{2}:\d{2}:\d{2}/)
    end

    it 'defaults duration to 3600 when missing' do
      slots = [{ 'identifier' => '0', 'start_time' => '2026-03-16T20:30:00Z' }]
      timeslots = service.send(:build_timeslots, slots)
      expect(timeslots.first['duration']).to eq(3600)
    end

    it 'preserves explicit duration values' do
      slots = [{ 'identifier' => '0', 'start_time' => '2026-03-16T20:30:00Z', 'duration' => 7200 }]
      timeslots = service.send(:build_timeslots, slots)
      expect(timeslots.first['duration']).to eq(7200)
    end
  end
end
