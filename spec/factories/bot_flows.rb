# frozen_string_literal: true

FactoryBot.define do
  factory :bot_flow do
    association :agent_bot
    name { Faker::Lorem.words(number: 3).join(' ') }
    description { Faker::Lorem.sentence }
    version { 1 }
    is_active { true }
    is_published { false }
    flow_data do
      {
        'nodes' => [
          {
            'id' => 'start_node',
            'type' => 'state',
            'position' => { 'x' => 100, 'y' => 100 },
            'data' => {
              'label' => 'Start',
              'state_id' => 'START',
              'handler' => 'handle_start'
            }
          }
        ],
        'edges' => []
      }
    end
    metadata { {} }

    trait :with_version_tag do
      sequence(:version_tag) { |n| "v1.#{n}" }
    end

    trait :published do
      is_published { true }
      published_at { Time.current }
    end

    trait :inactive do
      is_active { false }
    end

    trait :with_changelog do
      changelog { Faker::Lorem.paragraph }
    end

    trait :with_parent do
      association :parent_flow, factory: :bot_flow
    end

    trait :complex_flow do
      flow_data do
        {
          'nodes' => [
            {
              'id' => 'start',
              'type' => 'state',
              'position' => { 'x' => 100, 'y' => 100 },
              'data' => { 'label' => 'Start', 'state_id' => 'START' }
            },
            {
              'id' => 'menu',
              'type' => 'template',
              'position' => { 'x' => 200, 'y' => 200 },
              'data' => { 'label' => 'Main Menu', 'template_name' => 'main_menu' }
            },
            {
              'id' => 'help',
              'type' => 'intent',
              'position' => { 'x' => 300, 'y' => 300 },
              'data' => { 'label' => 'Help', 'keywords' => %w[help support] }
            }
          ],
          'edges' => [
            {
              'id' => 'edge1',
              'source' => 'start',
              'target' => 'menu',
              'sourceHandle' => 'a',
              'targetHandle' => 'b'
            },
            {
              'id' => 'edge2',
              'source' => 'menu',
              'target' => 'help',
              'sourceHandle' => 'c',
              'targetHandle' => 'd'
            }
          ]
        }
      end
    end
  end
end
