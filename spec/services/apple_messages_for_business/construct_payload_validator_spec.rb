# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AppleMessagesForBusiness::ConstructPayloadValidator do
  describe 'validations' do
    context 'with valid URL' do
      it 'accepts HTTPS URLs' do
        validator = described_class.new(
          url: 'https://www.example.com/app',
          store_region: 'US'
        )

        expect(validator).to be_valid
      end

      it 'accepts HTTPS URLs with query parameters' do
        validator = described_class.new(
          url: 'https://www.example.com/app?param=value&other=123',
          store_region: 'US'
        )

        expect(validator).to be_valid
      end

      it 'accepts HTTPS URLs with fragments' do
        validator = described_class.new(
          url: 'https://www.example.com/app#section',
          store_region: 'US'
        )

        expect(validator).to be_valid
      end

      it 'accepts HTTPS URLs with port' do
        validator = described_class.new(
          url: 'https://www.example.com:8443/app',
          store_region: 'US'
        )

        expect(validator).to be_valid
      end
    end

    context 'with invalid URL' do
      it 'rejects HTTP URLs (must be HTTPS)' do
        validator = described_class.new(
          url: 'http://www.example.com/app',
          store_region: 'US'
        )

        expect(validator).not_to be_valid
        expect(validator.errors[:url]).to include(match(/is invalid/))
      end

      it 'rejects malformed URLs' do
        validator = described_class.new(
          url: 'not a valid url',
          store_region: 'US'
        )

        expect(validator).not_to be_valid
        expect(validator.errors[:url]).to include(match(/is invalid/))
      end

      it 'rejects missing URL' do
        validator = described_class.new(
          url: nil,
          store_region: 'US'
        )

        expect(validator).not_to be_valid
        expect(validator.errors[:url]).to include("can't be blank")
      end

      it 'rejects empty URL' do
        validator = described_class.new(
          url: '',
          store_region: 'US'
        )

        expect(validator).not_to be_valid
        expect(validator.errors[:url]).to include("can't be blank")
      end

      it 'rejects FTP URLs' do
        validator = described_class.new(
          url: 'ftp://www.example.com/app',
          store_region: 'US'
        )

        expect(validator).not_to be_valid
        expect(validator.errors[:url]).to include(match(/is invalid/))
      end
    end

    context 'with valid store regions' do
      it 'accepts ISO 3166 alpha-2 country codes' do
        %w[US GB CA AU DE FR JP CN IN BR IT ES NL SE CH BE AT NO DK FI IE PT PL CZ HU GR RO SK BG HR LT LV EE SI CY MT LU].each do |region|
          validator = described_class.new(
            url: 'https://www.example.com/app',
            store_region: region
          )

          expect(validator).to be_valid,
                               "Expected #{region} to be valid, but got errors: #{validator.errors[:store_region]}"
        end
      end

      it 'accepts lowercase country codes by converting to uppercase' do
        validator = described_class.new(
          url: 'https://www.example.com/app',
          store_region: 'us'
        )

        expect(validator).to be_valid
        expect(validator.store_region).to eq('US')
      end

      it 'accepts mixed case country codes by converting to uppercase' do
        validator = described_class.new(
          url: 'https://www.example.com/app',
          store_region: 'Gb'
        )

        expect(validator).to be_valid
        expect(validator.store_region).to eq('GB')
      end
    end

    context 'with invalid store regions' do
      it 'rejects non-ISO country codes' do
        validator = described_class.new(
          url: 'https://www.example.com/app',
          store_region: 'XX'
        )

        expect(validator).not_to be_valid
        expect(validator.errors[:store_region]).to include(match(/is not included in the list/))
      end

      it 'rejects full country names' do
        validator = described_class.new(
          url: 'https://www.example.com/app',
          store_region: 'United States'
        )

        expect(validator).not_to be_valid
        expect(validator.errors[:store_region]).to include(match(/is not included in the list/))
      end

      it 'rejects missing store region' do
        validator = described_class.new(
          url: 'https://www.example.com/app',
          store_region: nil
        )

        expect(validator).not_to be_valid
        expect(validator.errors[:store_region]).to include("can't be blank")
      end

      it 'rejects empty store region' do
        validator = described_class.new(
          url: 'https://www.example.com/app',
          store_region: ''
        )

        expect(validator).not_to be_valid
        expect(validator.errors[:store_region]).to include("can't be blank")
      end

      it 'rejects three-letter country codes' do
        validator = described_class.new(
          url: 'https://www.example.com/app',
          store_region: 'USA'
        )

        expect(validator).not_to be_valid
        expect(validator.errors[:store_region]).to include(match(/is not included in the list/))
      end

      it 'rejects numeric values' do
        validator = described_class.new(
          url: 'https://www.example.com/app',
          store_region: '1'
        )

        expect(validator).not_to be_valid
        expect(validator.errors[:store_region]).to include(match(/is not included in the list/))
      end
    end

    context 'with multiple validation failures' do
      it 'collects all errors' do
        validator = described_class.new(
          url: 'http://invalid',
          store_region: 'INVALID'
        )

        expect(validator).not_to be_valid
        expect(validator.errors[:url]).to be_present
        expect(validator.errors[:store_region]).to be_present
      end
    end

    context 'with edge cases' do
      it 'accepts very long URLs' do
        long_url = "https://www.example.com/app?#{'param=' * 100}"
        validator = described_class.new(
          url: long_url,
          store_region: 'US'
        )

        expect(validator).to be_valid
      end

      it 'accepts URLs with special characters in query params' do
        validator = described_class.new(
          url: 'https://www.example.com/app?search=hello%20world&email=user@example.com',
          store_region: 'US'
        )

        expect(validator).to be_valid
      end

      it 'handles whitespace in URL by rejecting' do
        validator = described_class.new(
          url: 'https://www.example.com/app ',
          store_region: 'US'
        )

        expect(validator).not_to be_valid
        expect(validator.errors[:url]).to include(match(/is invalid/))
      end
    end

    context 'with full list of valid regions' do
      it 'contains exactly 30 valid regions' do
        expected_count = 30
        actual_count = described_class::VALID_STORE_REGIONS.length

        expect(actual_count).to eq(expected_count),
                                "Expected #{expected_count} regions but found #{actual_count}"
      end

      it 'includes all major markets' do
        major_markets = %w[US GB CA AU JP CN DE FR IN BR]

        major_markets.each do |market|
          expect(described_class::VALID_STORE_REGIONS).to include(market),
                                                          "Missing major market: #{market}"
        end
      end
    end
  end

  describe 'initialization' do
    it 'uppercases store_region during initialization' do
      validator = described_class.new(
        url: 'https://www.example.com/app',
        store_region: 'us'
      )

      expect(validator.store_region).to eq('US')
    end

    it 'handles nil store_region without raising error' do
      expect do
        described_class.new(
          url: 'https://www.example.com/app',
          store_region: nil
        )
      end.not_to raise_error
    end

    it 'stores url as provided' do
      url = 'https://www.example.com/app'
      validator = described_class.new(
        url: url,
        store_region: 'US'
      )

      expect(validator.url).to eq(url)
    end
  end

  describe 'errors.full_messages' do
    it 'provides human-readable error messages' do
      validator = described_class.new(
        url: nil,
        store_region: 'INVALID'
      )

      expect(validator).not_to be_valid
      messages = validator.errors.full_messages

      expect(messages).to include(match(/Url can't be blank/))
      expect(messages).to include(match(/Store region is not included in the list/))
    end
  end
end
