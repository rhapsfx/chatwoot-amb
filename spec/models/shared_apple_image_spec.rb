# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SharedAppleImage, type: :model do
  describe 'associations' do
    it { is_expected.to belong_to(:account) }
    it { is_expected.to have_one_attached(:image) }
  end

  describe 'validations' do
    let(:account) { create(:account) }

    describe 'account_id presence' do
      it 'validates presence of account_id' do
        shared_image = described_class.new(identifier: 'test_id', image_type: 'system')
        expect(shared_image.valid?).to be false
        expect(shared_image.errors[:account_id]).to include("can't be blank")
      end

      it 'is valid with account_id' do
        shared_image = build(:shared_apple_image, account: account)
        expect(shared_image.valid?).to be true
      end
    end

    describe 'identifier presence and uniqueness' do
      before do
        create(:shared_apple_image, account: account, identifier: 'unique_img_1')
      end

      it 'validates presence of identifier' do
        shared_image = described_class.new(account: account, image_type: 'system')
        expect(shared_image.valid?).to be false
        expect(shared_image.errors[:identifier]).to include("can't be blank")
      end

      it 'validates uniqueness scoped to account_id' do
        shared_image = described_class.new(account: account, identifier: 'unique_img_1', image_type: 'system')
        expect(shared_image.valid?).to be false
        expect(shared_image.errors[:identifier]).to include('has already been taken')
      end

      it 'allows same identifier in different account' do
        other_account = create(:account)
        shared_image = build(:shared_apple_image, account: other_account, identifier: 'unique_img_1')
        expect(shared_image.valid?).to be true
      end
    end

    describe 'image_type presence and inclusion' do
      it 'validates presence of image_type' do
        shared_image = described_class.new(account: account, identifier: 'test_id')
        expect(shared_image.valid?).to be false
        expect(shared_image.errors[:image_type]).to include("can't be blank")
      end

      it 'validates inclusion of image_type in allowed values' do
        shared_image = described_class.new(
          account: account,
          identifier: 'test_id',
          image_type: 'invalid_type'
        )
        expect(shared_image.valid?).to be false
        expect(shared_image.errors[:image_type]).to include('is not included in the list')
      end

      %w[system branding template].each do |valid_type|
        it "allows image_type '#{valid_type}'" do
          shared_image = build(:shared_apple_image, account: account, image_type: valid_type)
          expect(shared_image.valid?).to be true
        end
      end
    end
  end

  describe 'scopes' do
    let(:account) { create(:account) }

    before do
      create(:shared_apple_image, account: account, identifier: 'system_1', image_type: 'system')
      create(:shared_apple_image, account: account, identifier: 'system_2', image_type: 'system')
      create(:shared_apple_image, account: account, identifier: 'branding_1', image_type: 'branding')
      create(:shared_apple_image, account: account, identifier: 'template_1', image_type: 'template')
      create(:shared_apple_image, account: account, identifier: 'template_2', image_type: 'template')
    end

    describe '.system_images' do
      it 'returns only system images' do
        system_images = described_class.system_images
        expect(system_images.count).to eq(2)
        expect(system_images.pluck(:image_type).uniq).to eq(['system'])
        expect(system_images.pluck(:identifier)).to contain_exactly('system_1', 'system_2')
      end
    end

    describe '.branding_images' do
      it 'returns only branding images' do
        branding_images = described_class.branding_images
        expect(branding_images.count).to eq(1)
        expect(branding_images.pluck(:image_type).uniq).to eq(['branding'])
        expect(branding_images.first.identifier).to eq('branding_1')
      end
    end

    describe '.template_images' do
      it 'returns only template images' do
        template_images = described_class.template_images
        expect(template_images.count).to eq(2)
        expect(template_images.pluck(:image_type).uniq).to eq(['template'])
        expect(template_images.pluck(:identifier)).to contain_exactly('template_1', 'template_2')
      end
    end

    it 'scopes can be chained' do
      expect(described_class.system_images.where(account_id: account.id).count).to eq(2)
    end
  end

  describe 'image attachment' do
    let(:account) { create(:account) }

    it 'can attach an image' do
      shared_image = create(:shared_apple_image, account: account)
      expect(shared_image.image.attached?).to be true
    end

    it 'can be created without an image attachment' do
      shared_image = create(:shared_apple_image, :without_attachment, account: account)
      expect(shared_image.image.attached?).to be false
    end

    it 'allows reattaching images' do
      shared_image = create(:shared_apple_image, account: account)
      first_blob_id = shared_image.image.blob.id

      shared_image.image.attach(
        io: Rails.root.join('spec/assets/avatar.png').open,
        filename: 'new_avatar.png',
        content_type: 'image/png'
      )

      expect(shared_image.image.blob.id).not_to eq(first_blob_id)
    end
  end

  describe 'metadata' do
    let(:account) { create(:account) }

    it 'stores metadata as jsonb' do
      metadata = { width: 800, height: 600, format: 'png', size: 1024 }
      shared_image = create(:shared_apple_image, account: account, metadata: metadata)

      expect(shared_image.metadata).to eq(metadata)
    end

    it 'allows nil metadata' do
      shared_image = create(:shared_apple_image, account: account, metadata: nil)
      expect(shared_image.metadata).to be_nil
    end

    it 'allows updating metadata' do
      shared_image = create(:shared_apple_image, account: account, metadata: { width: 400 })
      shared_image.update(metadata: { width: 800, height: 800 })
      expect(shared_image.metadata).to eq({ 'width' => 800, 'height' => 800 })
    end
  end

  describe 'factory traits' do
    let(:account) { create(:account) }

    it 'creates branding image with trait' do
      shared_image = create(:shared_apple_image, :branding, account: account)
      expect(shared_image.image_type).to eq('branding')
      expect(shared_image.description).to eq('Branding image')
    end

    it 'creates template image with trait' do
      shared_image = create(:shared_apple_image, :template, account: account)
      expect(shared_image.image_type).to eq('template')
      expect(shared_image.description).to eq('Template image')
    end

    it 'creates image without attachment trait' do
      shared_image = create(:shared_apple_image, :without_attachment, account: account)
      expect(shared_image.image.attached?).to be false
    end
  end
end
