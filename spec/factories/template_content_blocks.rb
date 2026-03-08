# frozen_string_literal: true

FactoryBot.define do
  factory :template_content_block do
    association :message_template
    block_type { 'form' }
    properties { {} }
    order_index { 0 }
    conditions { {} }
  end
end
