# frozen_string_literal: true

require 'rails_helper'

RSpec.describe LogSanitizerService do
  describe '.sanitize_for_log' do
    context 'with small strings' do
      it 'does not truncate strings under 1KB' do
        small_string = 'a' * 500
        result = described_class.sanitize_for_log(small_string)
        expect(result).to eq(small_string)
      end
    end

    context 'with large strings' do
      it 'truncates large strings over 1KB' do
        large_string = 'a' * 2000
        result = described_class.sanitize_for_log(large_string)
        expect(result).to include('KB')
        expect(result.length).to be < large_string.length
      end

      it 'identifies base64 data' do
        base64_string = Base64.strict_encode64('x' * 2000)
        result = described_class.sanitize_for_log(base64_string)
        expect(result).to include('[BASE64 DATA')
      end
    end

    context 'with hashes' do
      it 'sanitizes hash with large data fields' do
        hash = {
          name: 'test',
          image_data: Base64.strict_encode64('x' * 5000),
          description: 'normal text'
        }

        result = described_class.sanitize_for_log(hash)

        expect(result[:name]).to eq('test')
        expect(result[:description]).to eq('normal text')
        expect(result[:image_data]).to include('[BASE64 IMAGE DATA')
        expect(result[:image_data]).to include('KB')
      end

      it 'handles nested hashes' do
        hash = {
          user: {
            name: 'John',
            avatar_data: 'x' * 2000
          }
        }

        result = described_class.sanitize_for_log(hash)

        expect(result[:user][:name]).to eq('John')
        expect(result[:user][:avatar_data]).to include('KB')
        expect(result[:user][:avatar_data].length).to be < 200
      end

      it 'does not modify original hash' do
        original = {
          image_data: 'x' * 2000
        }
        original_copy = original.deep_dup

        described_class.sanitize_for_log(original)

        expect(original).to eq(original_copy)
      end
    end

    context 'with arrays' do
      it 'sanitizes arrays with large strings' do
        array = ['small', 'x' * 2000, 'another small']
        result = described_class.sanitize_for_log(array)

        expect(result[0]).to eq('small')
        expect(result[1]).to include('KB')
        expect(result[1].length).to be < 200
        expect(result[2]).to eq('another small')
      end

      it 'sanitizes arrays of hashes' do
        array = [
          { name: 'item1', data: 'x' * 2000 },
          { name: 'item2', data: 'small' }
        ]

        result = described_class.sanitize_for_log(array)

        expect(result[0][:name]).to eq('item1')
        expect(result[0][:data]).to include('KB')
        expect(result[0][:data].length).to be < 200
        expect(result[1][:data]).to eq('small')
      end
    end

    context 'with different data types' do
      it 'handles nil values' do
        expect(described_class.sanitize_for_log(nil)).to be_nil
      end

      it 'handles numbers' do
        expect(described_class.sanitize_for_log(123)).to eq(123)
      end

      it 'handles booleans' do
        expect(described_class.sanitize_for_log(true)).to be true
        expect(described_class.sanitize_for_log(false)).to be false
      end
    end

    context 'with real-world scenarios' do
      it 'sanitizes image upload params' do
        params = {
          identifier: '0',
          filename: 'test.jpg',
          image_data: Base64.strict_encode64('x' * 10_000),
          description: 'Test image'
        }

        result = described_class.sanitize_for_log(params)

        expect(result[:identifier]).to eq('0')
        expect(result[:filename]).to eq('test.jpg')
        expect(result[:description]).to eq('Test image')
        expect(result[:image_data]).to include('[BASE64 IMAGE DATA')
        expect(result[:image_data]).to include('KB')
      end

      it 'sanitizes bulk upload params' do
        params = {
          inbox_ids: [1, 2, 3],
          identifier: '0',
          image_data: Base64.strict_encode64('x' * 50_000),
          filename: 'bulk.jpg'
        }

        result = described_class.sanitize_for_log(params)

        expect(result[:inbox_ids]).to eq([1, 2, 3])
        expect(result[:identifier]).to eq('0')
        expect(result[:filename]).to eq('bulk.jpg')
        expect(result[:image_data]).to include('KB')
      end
    end

    context 'with size display' do
      it 'displays KB for sizes under 1MB' do
        data = 'x' * 10_000 # ~10KB
        result = described_class.sanitize_for_log(data)
        expect(result).to include('KB')
        expect(result).not_to include('MB')
      end

      it 'displays MB for sizes over 1MB' do
        data = 'x' * 2_000_000 # ~2MB
        result = described_class.sanitize_for_log(data)
        expect(result).to include('MB')
      end
    end
  end
end
