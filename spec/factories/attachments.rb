# frozen_string_literal: true

FactoryBot.define do
  factory :attachment do
    account
    message
    file_type { :file }

    after(:build) do |attachment|
      # Attach a test file
      attachment.file.attach(
        io: StringIO.new('test file content'),
        filename: 'test.pdf',
        content_type: 'application/pdf'
      )
    end
  end
end
