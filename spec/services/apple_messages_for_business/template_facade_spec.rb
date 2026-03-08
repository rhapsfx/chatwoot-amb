# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AppleMessagesForBusiness::TemplateFacade do
  let(:account) { create(:account) }
  let(:template) { create(:message_template, account: account) }
  let(:facade) { described_class.new(template) }

  describe '#initialize' do
    it 'initializes with a template' do
      expect(facade.instance_variable_get(:@template)).to eq(template)
    end
  end

  describe '#load_data' do
    context 'with metadata storage strategy' do
      before do
        template.metadata = {
          'storage_strategy' => 'metadata',
          'list_picker' => {
            'sections' => [
              {
                'title' => 'Section 1',
                'items' => [
                  { 'identifier' => '1', 'title' => 'Item 1' }
                ]
              }
            ]
          }
        }
        template.save!
      end

      it 'loads data from metadata storage' do
        data = facade.load_data('list_picker')

        expect(data).to eq({
                             'sections' => [
                               {
                                 'title' => 'Section 1',
                                 'items' => [
                                   { 'identifier' => '1', 'title' => 'Item 1' }
                                 ]
                               }
                             ]
                           })
      end

      it 'returns empty hash for non-existent block type' do
        data = facade.load_data('nonexistent')

        expect(data).to eq({})
      end

      it 'returns snake_case data without images' do
        template.metadata['list_picker']['image_identifier'] = 'img_123'
        template.metadata['list_picker']['images'] = [{ 'identifier' => 'img_123', 'data' => 'base64' }]
        template.save!

        data = facade.load_data('list_picker')

        expect(data['image_identifier']).to eq('img_123')
        expect(data).not_to have_key('images')
      end
    end

    context 'with content_blocks storage strategy' do
      let(:content_block) do
        create(:template_content_block,
               message_template: template,
               block_type: 'time_picker',
               properties: {
                 'event' => {
                   'timeslots' => [
                     { 'identifier' => '1', 'start_time' => '2024-01-15T14:30+0000', 'duration' => 3600 }
                   ]
                 },
                 'timezone_offset' => 3600
               })
      end

      before do
        template.metadata = { 'storage_strategy' => 'content_blocks' }
        template.save!
        content_block
      end

      it 'loads data from content blocks storage' do
        data = facade.load_data('time_picker')

        expect(data).to eq({
                             'event' => {
                               'timeslots' => [
                                 { 'identifier' => '1', 'start_time' => '2024-01-15T14:30+0000', 'duration' => 3600 }
                               ]
                             },
                             'timezone_offset' => 3600
                           })
      end

      it 'returns empty hash when block does not exist' do
        data = facade.load_data('nonexistent')

        expect(data).to eq({})
      end
    end

    context 'with auto-detection of storage strategy' do
      it 'uses metadata when data exists there' do
        template.metadata = {
          'list_picker' => { 'sections' => [] }
        }
        template.save!

        data = facade.load_data('list_picker')

        expect(data).to eq({ 'sections' => [] })
      end

      it 'uses content_blocks when data exists there' do
        create(:template_content_block,
               message_template: template,
               block_type: 'form',
               properties: { 'title' => 'Contact Form' })

        data = facade.load_data('form')

        expect(data).to eq({ 'title' => 'Contact Form' })
      end

      it 'defaults to metadata for new templates' do
        # No data in either storage
        data = facade.load_data('new_block')

        expect(data).to eq({})
      end
    end
  end

  describe '#load_data_with_images' do
    before do
      template.metadata = {
        'list_picker' => {
          'sections' => [
            {
              'items' => [
                { 'identifier' => '1', 'title' => 'Item 1', 'image_identifier' => 'img_1' }
              ]
            }
          ],
          'images' => [
            { 'identifier' => 'img_1', 'description' => 'Embedded image' }
          ]
        }
      }
      template.save!
    end

    it 'loads data and enriches with image data' do
      # Mock ImageFetchService
      image_service = instance_double(AppleMessagesForBusiness::ImageFetchService)
      allow(AppleMessagesForBusiness::ImageFetchService).to receive(:new).with(
        account_id: template.account_id,
        inbox_id: nil,
        embedded_images: []
      ).and_return(image_service)

      allow(image_service).to receive(:fetch_and_encode).with(['img_1']).and_return([
                                                                                      { identifier: 'img_1', data: 'base64data',
                                                                                        description: 'Fetched image' }
                                                                                    ])

      data = facade.load_data_with_images('list_picker')

      expect(data['sections']).to be_present
      expect(data['images']).to eq([
                                     { 'identifier' => 'img_1', 'data' => 'base64data', 'description' => 'Fetched image' }
                                   ])
    end

    it 'works without embedded images' do
      template.metadata['list_picker'].delete('images')
      template.save!

      # Mock ImageFetchService
      image_service = instance_double(AppleMessagesForBusiness::ImageFetchService)
      allow(AppleMessagesForBusiness::ImageFetchService).to receive(:new).with(
        account_id: template.account_id,
        inbox_id: nil,
        embedded_images: []
      ).and_return(image_service)

      allow(image_service).to receive(:fetch_and_encode).with(['img_1']).and_return([
                                                                                      { identifier: 'img_1', data: 'shared_data',
                                                                                        description: 'Shared image' }
                                                                                    ])

      data = facade.load_data_with_images('list_picker')

      expect(data['images']).to eq([
                                     { 'identifier' => 'img_1', 'data' => 'shared_data', 'description' => 'Shared image' }
                                   ])
    end

    it 'returns empty images array when no identifiers found' do
      template.metadata = {
        'list_picker' => {
          'sections' => [
            {
              'items' => [
                { 'identifier' => '1', 'title' => 'No image item' }
              ]
            }
          ]
        }
      }
      template.save!

      data = facade.load_data_with_images('list_picker')

      expect(data['sections']).to be_present
      expect(data['images'] || []).to eq([])
    end

    it 'loads images for complex templates with bot sends' do
      # Setup template with received/reply images
      template.metadata = {
        'list_picker' => {
          'received_image_identifier' => 'received_img',
          'reply_image_identifier' => 'reply_img',
          'sections' => []
        }
      }
      template.save!

      # Mock ImageFetchService
      image_service = instance_double(AppleMessagesForBusiness::ImageFetchService)
      allow(AppleMessagesForBusiness::ImageFetchService).to receive(:new).and_return(image_service)
      allow(image_service).to receive(:fetch_and_encode).with(%w[received_img reply_img]).and_return([
                                                                                                       { identifier: 'received_img', data: 'data1' },
                                                                                                       { identifier: 'reply_img', data: 'data2' }
                                                                                                     ])

      data = facade.load_data_with_images('list_picker')

      expect(data['images'].size).to eq(2)
    end
  end

  describe '#save_data' do
    context 'with metadata storage strategy' do
      before do
        template.metadata = { 'storage_strategy' => 'metadata' }
        template.save!
      end

      it 'saves data to metadata' do
        properties = {
          'sections' => [
            { 'title' => 'New Section' }
          ]
        }

        facade.save_data('list_picker', properties)

        template.reload
        expect(template.metadata['list_picker']).to eq(properties)
      end

      it 'merges with existing metadata' do
        template.metadata['existing_key'] = 'existing_value'
        template.save!

        facade.save_data('new_block', { 'data' => 'new' })

        template.reload
        expect(template.metadata['existing_key']).to eq('existing_value')
        expect(template.metadata['new_block']).to eq({ 'data' => 'new' })
      end
    end

    context 'with content_blocks storage strategy' do
      before do
        template.metadata = { 'storage_strategy' => 'content_blocks' }
        template.save!
      end

      it 'creates new content block when none exists' do
        properties = { 'title' => 'New Form' }

        expect do
          facade.save_data('form', properties)
        end.to change(TemplateContentBlock, :count).by(1)

        block = TemplateContentBlock.find_by(message_template: template, block_type: 'form')
        expect(block.properties).to eq(properties)
      end

      it 'updates existing content block' do
        existing_block = create(:template_content_block,
                                message_template: template,
                                block_type: 'form',
                                properties: { 'title' => 'Old Form' })

        facade.save_data('form', { 'title' => 'Updated Form' })

        existing_block.reload
        expect(existing_block.properties).to eq({ 'title' => 'Updated Form' })
      end

      it 'does not create duplicate blocks' do
        create(:template_content_block, message_template: template, block_type: 'list_picker')

        expect do
          facade.save_data('list_picker', { 'sections' => [] })
        end.not_to change(TemplateContentBlock, :count)
      end
    end

    context 'with auto-detection based on existing data' do
      it 'saves to metadata when data already exists there' do
        template.metadata = { 'list_picker' => { 'old' => 'data' } }
        template.save!

        facade.save_data('list_picker', { 'new' => 'data' })

        template.reload
        expect(template.metadata['list_picker']).to eq({ 'new' => 'data' })
      end

      it 'saves to content_blocks when data already exists there' do
        create(:template_content_block,
               message_template: template,
               block_type: 'form',
               properties: { 'old' => 'data' })

        facade.save_data('form', { 'new' => 'data' })

        block = TemplateContentBlock.find_by(message_template: template, block_type: 'form')
        expect(block.properties).to eq({ 'new' => 'data' })
      end

      it 'defaults to metadata for new data' do
        facade.save_data('new_type', { 'data' => 'value' })

        template.reload
        expect(template.metadata['new_type']).to eq({ 'data' => 'value' })
      end
    end
  end

  describe '#all_blocks' do
    context 'with metadata storage' do
      before do
        template.metadata = {
          'storage_strategy' => 'metadata',
          'list_picker' => { 'sections' => [] },
          'time_picker' => { 'event' => {} },
          'non_block_key' => 'value'
        }
        template.save!
      end

      it 'returns all block types from metadata' do
        blocks = facade.all_blocks

        expect(blocks).to eq({
                               'list_picker' => { 'sections' => [] },
                               'time_picker' => { 'event' => {} }
                             })
      end

      it 'excludes non-block keys' do
        blocks = facade.all_blocks

        expect(blocks).not_to have_key('storage_strategy')
        expect(blocks).not_to have_key('non_block_key')
      end
    end

    context 'with content_blocks storage' do
      before do
        template.metadata = { 'storage_strategy' => 'content_blocks' }
        template.save!
        create(:template_content_block, message_template: template, block_type: 'form', properties: { 'title' => 'Form' })
        create(:template_content_block, message_template: template, block_type: 'list_picker', properties: { 'sections' => [] })
      end

      it 'returns all blocks from content_blocks' do
        blocks = facade.all_blocks

        expect(blocks.keys).to contain_exactly('form', 'list_picker')
        expect(blocks['form']).to eq({ 'title' => 'Form' })
        expect(blocks['list_picker']).to eq({ 'sections' => [] })
      end
    end

    context 'with mixed storage' do
      before do
        # Some data in metadata
        template.metadata = {
          'list_picker' => { 'sections' => [] }
        }
        template.save!
        # Some data in content_blocks
        create(:template_content_block, message_template: template, block_type: 'form', properties: { 'title' => 'Form' })
      end

      it 'returns combined blocks from both storages' do
        blocks = facade.all_blocks

        expect(blocks.keys).to contain_exactly('list_picker', 'form')
        expect(blocks['list_picker']).to eq({ 'sections' => [] })
        expect(blocks['form']).to eq({ 'title' => 'Form' })
      end

      it 'prefers content_blocks over metadata for duplicates' do
        # Add duplicate in content_blocks
        create(:template_content_block,
               message_template: template,
               block_type: 'list_picker',
               properties: { 'sections' => [{ 'title' => 'From blocks' }] })

        blocks = facade.all_blocks

        expect(blocks['list_picker']).to eq({ 'sections' => [{ 'title' => 'From blocks' }] })
      end
    end
  end

  describe '#image_identifiers' do
    before do
      template.metadata = {
        'list_picker' => {
          'received_image_identifier' => 'received_1',
          'reply_image_identifier' => 'reply_1',
          'sections' => [
            {
              'items' => [
                { 'image_identifier' => 'item_1' },
                { 'image_identifier' => 'item_2' },
                { 'title' => 'No image' }
              ]
            }
          ],
          'images' => [
            { 'identifier' => 'embedded_1' },
            { 'identifier' => 'embedded_2' }
          ]
        },
        'time_picker' => {
          'received_image_identifier' => 'time_received',
          'reply_image_identifier' => 'time_reply'
        }
      }
      template.save!
    end

    it 'collects all image identifiers from all blocks' do
      identifiers = facade.image_identifiers

      expect(identifiers).to contain_exactly(
        'received_1', 'reply_1', 'item_1', 'item_2',
        'embedded_1', 'embedded_2', 'time_received', 'time_reply'
      )
    end

    it 'returns unique identifiers only' do
      # Add duplicate identifier
      template.metadata['form'] = {
        'received_image_identifier' => 'received_1' # Duplicate
      }
      template.save!

      identifiers = facade.image_identifiers

      expect(identifiers.count('received_1')).to eq(1)
    end

    it 'handles missing or nil identifiers' do
      template.metadata = {
        'list_picker' => {
          'received_image_identifier' => nil,
          'sections' => [
            {
              'items' => [
                { 'image_identifier' => '' },
                { 'image_identifier' => 'valid_id' }
              ]
            }
          ]
        }
      }
      template.save!

      identifiers = facade.image_identifiers

      expect(identifiers).to eq(['valid_id'])
    end

    it 'returns empty array when no images exist' do
      template.metadata = {
        'list_picker' => { 'sections' => [] }
      }
      template.save!

      identifiers = facade.image_identifiers

      expect(identifiers).to eq([])
    end
  end

  describe '#extract_image_identifiers' do
    it 'extracts identifiers from top-level received/reply fields' do
      data = {
        'received_image_identifier' => 'r1',
        'reply_image_identifier' => 'r2',
        'other_field' => 'value'
      }

      identifiers = facade.send(:extract_image_identifiers, data)

      expect(identifiers).to contain_exactly('r1', 'r2')
    end

    it 'extracts identifiers from nested sections and items' do
      data = {
        'sections' => [
          {
            'items' => [
              { 'image_identifier' => 'i1' },
              { 'image_identifier' => 'i2' }
            ]
          },
          {
            'items' => [
              { 'image_identifier' => 'i3' }
            ]
          }
        ]
      }

      identifiers = facade.send(:extract_image_identifiers, data)

      expect(identifiers).to contain_exactly('i1', 'i2', 'i3')
    end

    it 'extracts identifiers from embedded images array' do
      data = {
        'images' => [
          { 'identifier' => 'e1' },
          { 'identifier' => 'e2' },
          { 'data' => 'base64' } # No identifier
        ]
      }

      identifiers = facade.send(:extract_image_identifiers, data)

      expect(identifiers).to contain_exactly('e1', 'e2')
    end

    it 'extracts identifiers from form pages and options' do
      data = {
        'pages' => [
          {
            'items' => [
              {
                'options' => [
                  { 'image_identifier' => 'o1' },
                  { 'image_identifier' => 'o2' }
                ]
              }
            ]
          }
        ]
      }

      identifiers = facade.send(:extract_image_identifiers, data)

      expect(identifiers).to contain_exactly('o1', 'o2')
    end

    it 'handles deeply nested structures' do
      data = {
        'level1' => {
          'level2' => {
            'sections' => [
              {
                'items' => [
                  { 'image_identifier' => 'deep1' }
                ]
              }
            ]
          }
        }
      }

      identifiers = facade.send(:extract_image_identifiers, data)

      expect(identifiers).to contain_exactly('deep1')
    end
  end

  describe '#detect_storage_strategy' do
    it 'returns explicit storage strategy from metadata' do
      template.metadata = { 'storage_strategy' => 'content_blocks' }
      template.save!

      strategy = facade.send(:detect_storage_strategy, 'any_type')

      expect(strategy).to eq('content_blocks')
    end

    it 'returns metadata when block exists in metadata' do
      template.metadata = { 'list_picker' => {} }
      template.save!

      strategy = facade.send(:detect_storage_strategy, 'list_picker')

      expect(strategy).to eq('metadata')
    end

    it 'returns content_blocks when block exists there' do
      create(:template_content_block, message_template: template, block_type: 'form')

      strategy = facade.send(:detect_storage_strategy, 'form')

      expect(strategy).to eq('content_blocks')
    end

    it 'defaults to metadata for new blocks' do
      strategy = facade.send(:detect_storage_strategy, 'new_type')

      expect(strategy).to eq('metadata')
    end
  end

  describe 'edge cases' do
    it 'handles template without metadata' do
      template.metadata = nil
      template.save!

      expect { facade.load_data('any') }.not_to raise_error
      expect(facade.load_data('any')).to eq({})
    end

    it 'handles malformed metadata gracefully' do
      template.metadata = 'not a hash'
      template.save!

      expect { facade.load_data('any') }.not_to raise_error
      expect(facade.load_data('any')).to eq({})
    end

    it 'handles concurrent access to same block type' do
      # Simulate concurrent saves
      facade1 = described_class.new(template)
      facade2 = described_class.new(template)

      facade1.save_data('list_picker', { 'v1' => 'data' })
      facade2.save_data('list_picker', { 'v2' => 'data' })

      # Last write wins
      data = facade.load_data('list_picker')
      expect(data).to eq({ 'v2' => 'data' })
    end
  end
end
