# Apple Messages for Business: Case Normalization Specification

**Version**: 1.0
**Date**: 2025-10-26
**Status**: Proposed
**Owner**: Engineering Team

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Problem Statement](#problem-statement)
3. [Architecture Overview](#architecture-overview)
4. [Detailed Implementation Plan](#detailed-implementation-plan)
5. [Field Mapping Reference](#field-mapping-reference)
6. [Code Changes](#code-changes)
7. [Testing Strategy](#testing-strategy)
8. [Migration Strategy](#migration-strategy)
9. [Rollback Plan](#rollback-plan)
10. [Appendix](#appendix)

---

## Executive Summary

### Current State
The Apple Messages for Business (AMB) implementation suffers from systemic snake_case/camelCase inconsistencies across the entire stack:
- Frontend naturally uses camelCase (JavaScript convention)
- Backend services use defensive dual-checks for both formats
- Database stores mixed formats based on input source
- Apple MSP API strictly requires camelCase

### Proposed Solution
**Standardize on snake_case internally, convert to camelCase only at the Apple MSP boundary.**

This approach:
- Follows Rails conventions (snake_case for attributes)
- Centralizes format conversion in one place
- Eliminates defensive dual-checks throughout the codebase
- Maintains backward compatibility
- Does not require frontend changes

### Implementation Phases
1. **Phase 1**: Create CaseTransformer module (8-12 hours)
2. **Phase 2**: Update service layer (12-16 hours)
3. **Phase 3**: Normalize API/template layer (6-8 hours)
4. **Phase 4**: Bot integration updates (4-6 hours)

**Total Effort**: 30-42 hours (~1 week)

---

## Problem Statement

### Root Cause Analysis

The issue stems from the JavaScript/Ruby impedance mismatch:

```
┌──────────────────────────────────────────────────────────────┐
│                     Data Flow Journey                         │
├──────────────────────────────────────────────────────────────┤
│                                                               │
│  Frontend (Vue.js)                                           │
│  ├─ Natural JavaScript: camelCase                            │
│  └─ Sends: { imageIdentifier: "img_123" }                   │
│                         ↓                                     │
│  API Controller                                              │
│  ├─ Receives JSON as-is                                     │
│  └─ Stores: Mixed format based on source                    │
│                         ↓                                     │
│  ContentAttributeValidator                                   │
│  ├─ Accepts both formats                                    │
│  ├─ Partial normalization (inconsistent)                    │
│  └─ Stores: { "imageIdentifier" => "img_123" } OR           │
│             { "image_identifier" => "img_123" }             │
│                         ↓                                     │
│  Database (PostgreSQL JSONB)                                 │
│  ├─ Preserves exact keys from validation                    │
│  └─ Mixed snake_case and camelCase                          │
│                         ↓                                     │
│  SendMessageService (hierarchy)                              │
│  ├─ Defensive checks for both formats:                      │
│  │   image_id = item['image_identifier'] ||                 │
│  │              item['imageIdentifier']                      │
│  └─ Scattered throughout 5+ service classes                 │
│                         ↓                                     │
│  Apple MSP API                                               │
│  └─ Requires strict camelCase: { imageIdentifier: "..." }   │
│                                                               │
└──────────────────────────────────────────────────────────────┘
```

### Impact Analysis

#### 1. **Maintenance Burden**
- 20+ locations with defensive dual-checks
- Every new field requires duplicate logic
- Easy to miss one format, causing bugs

#### 2. **Performance Impact**
- Redundant hash lookups (2x per field)
- String allocations for duplicate keys
- Cache inefficiency

#### 3. **Bug Surface Area**
**Actual bugs encountered:**

**List Picker Images (FIXED)**
```ruby
# Before fix - only checked snake_case
if item['image_identifier'].present?
  transformed_item['imageIdentifier'] = item['image_identifier']
end
# Result: Frontend-sent camelCase was silently dropped

# After fix - defensive dual check
if item['image_identifier'].present?
  transformed_item['imageIdentifier'] = item['image_identifier']
elsif item['imageIdentifier'].present?
  transformed_item['imageIdentifier'] = item['imageIdentifier']
end
```

**Time Picker Reply Images (FIXED)**
```ruby
# Initially missing auto-fallback
reply_image_id = content_attributes['reply_image_identifier'] ||
                 content_attributes['replyImageIdentifier']

# Had to add fallback logic
if reply_image_id.blank?
  received_image_id = content_attributes['received_image_identifier'] ||
                      content_attributes['receivedImageIdentifier']
  reply_image_id = received_image_id
end
```

#### 4. **Code Locations Affected**

| File | Lines | Issue |
|------|-------|-------|
| `send_list_picker_service.rb` | 195-204 | Dual checks for `imageIdentifier` |
| `send_time_picker_service.rb` | 138-139, 164, 273-280 | Image identifier dual checks |
| `form_service.rb` | 250, 263-270 | received/reply message dual checks |
| `send_quick_reply_service.rb` | 50, 59 | Only checks snake_case (BUG RISK) |
| `apple_messages_template_adapter.rb` | 82-84, 159-160, 203-204, 252-260 | Mixed checks throughout |
| `content_attribute_validator.rb` | 112, 122, 177 | Partial normalization |

---

## Architecture Overview

### Proposed Layered Approach

```
┌─────────────────────────────────────────────────────────────┐
│                    FRONTEND LAYER                            │
│  - Vue.js components (unchanged)                            │
│  - Natural JavaScript camelCase                             │
│  - Sends: { imageIdentifier, receivedMessage, etc. }       │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│              API NORMALIZATION LAYER (NEW)                   │
│  - MessagesController before_action                         │
│  - CaseTransformer.from_apple_format                        │
│  - Converts ALL camelCase → snake_case                      │
│  - Output: { image_identifier, received_message, etc. }    │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│                   VALIDATION LAYER                           │
│  - ContentAttributeValidator (updated)                      │
│  - Expects ONLY snake_case                                  │
│  - Removes dual-format acceptance                           │
│  - Validates structure only                                 │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│                  PERSISTENCE LAYER                           │
│  - PostgreSQL JSONB                                         │
│  - Stores ONLY snake_case                                   │
│  - Consistent format guaranteed                             │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│                   SERVICE LAYER                              │
│  - SendMessageService hierarchy (updated)                   │
│  - Assumes ONLY snake_case input                            │
│  - No defensive dual-checks                                 │
│  - Cleaner, simpler code                                    │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│            APPLE MSP TRANSFORMATION LAYER (NEW)              │
│  - CaseTransformer.to_apple_format                          │
│  - Converts snake_case → camelCase                          │
│  - Called in build_interactive_data methods                 │
│  - Centralized conversion logic                             │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│                   APPLE MSP API                              │
│  - Receives strict camelCase                                │
│  - { imageIdentifier, receivedMessage, etc. }              │
└─────────────────────────────────────────────────────────────┘
```

### Key Design Principles

1. **Single Source of Truth**: Internal data is ALWAYS snake_case
2. **Boundary Conversion**: Transform only at system boundaries (API input, Apple MSP output)
3. **Fail Fast**: Validator rejects incorrect format (after normalization)
4. **No Backward Compatibility Hacks**: Clean transformation eliminates need for dual-checks

---

## Detailed Implementation Plan

### Phase 1: Create CaseTransformer Module

**Estimated Time**: 8-12 hours

#### Step 1.1: Create Transformer Module

**File**: `app/services/apple_messages_for_business/case_transformer.rb`

```ruby
# frozen_string_literal: true

module AppleMessagesForBusiness
  module CaseTransformer
    # Complete field mapping: snake_case → camelCase for Apple MSP API
    TO_APPLE_MAPPINGS = {
      # Image identifiers
      'image_identifier' => 'imageIdentifier',
      'received_image_identifier' => 'imageIdentifier',
      'reply_image_identifier' => 'imageIdentifier',

      # Message structures
      'received_message' => 'receivedMessage',
      'reply_message' => 'replyMessage',

      # Titles and subtitles
      'received_title' => 'title',
      'received_subtitle' => 'subtitle',
      'reply_title' => 'title',
      'reply_subtitle' => 'subtitle',

      # Image message fields
      'image_title' => 'imageTitle',
      'image_subtitle' => 'imageSubtitle',
      'reply_image_title' => 'imageTitle',
      'reply_image_subtitle' => 'imageSubtitle',
      'secondary_subtitle' => 'secondarySubtitle',
      'tertiary_subtitle' => 'tertiarySubtitle',
      'reply_secondary_subtitle' => 'secondarySubtitle',
      'reply_tertiary_subtitle' => 'tertiarySubtitle',

      # List picker specific
      'multiple_selection' => 'multipleSelection',

      # Time picker specific
      'timezone_offset' => 'timezoneOffset',
      'start_time' => 'startTime',

      # Form specific
      'page_id' => 'pageIdentifier',
      'item_id' => 'itemId',
      'item_type' => 'itemType',
      'default_value' => 'defaultValue',
      'max_length' => 'maxLength',
      'keyboard_type' => 'keyboardType',
      'text_content_type' => 'textContentType',
      'min_value' => 'minValue',
      'max_value' => 'maxValue',
      'picker_type' => 'pickerType',
      'picker_options' => 'pickerOptions',
      'button_style' => 'buttonStyle',
      'image_url' => 'imageUrl',
      'use_live_layout' => 'useLiveLayout',
      'show_summary' => 'showSummary',
      'next_page_identifier' => 'nextPageIdentifier',
      'submit_form' => 'submitForm',
      'multiple_selection' => 'multipleSelection',
      'summary_text' => 'summaryText',

      # Common fields
      'source_id' => 'sourceId',
      'destination_id' => 'destinationId',
      'request_identifier' => 'requestIdentifier',
      'interactive_data' => 'interactiveData'
    }.freeze

    # Reverse mapping for incoming data from frontend
    FROM_APPLE_MAPPINGS = TO_APPLE_MAPPINGS.invert.freeze

    # Fields that should NOT be transformed (keep as-is)
    PRESERVE_KEYS = %w[
      identifier title subtitle description style order duration
      v id type bid data version images items sections pages
      timeslots event location oauth2 payment form
    ].freeze

    class << self
      # Convert snake_case hash to camelCase for Apple MSP API
      # @param hash [Hash] Input hash with snake_case keys
      # @param context [Symbol] Context for mapping (:received_message, :reply_message, :item, etc.)
      # @return [Hash] Output hash with camelCase keys
      def to_apple_format(hash, context: nil)
        return hash unless hash.is_a?(Hash)

        transformed = {}

        hash.each do |key, value|
          string_key = key.to_s

          # Preserve keys that shouldn't be transformed
          if PRESERVE_KEYS.include?(string_key)
            transformed[string_key] = transform_value(value, context)
            next
          end

          # Apply context-specific mapping
          camel_key = case context
                      when :received_message, :reply_message
                        # In message context, received_title → title, etc.
                        map_message_field(string_key, context)
                      when :item
                        # In item context, image_identifier → imageIdentifier
                        TO_APPLE_MAPPINGS[string_key] || string_key.camelize(:lower)
                      else
                        # Default: use mapping or camelize
                        TO_APPLE_MAPPINGS[string_key] || string_key.camelize(:lower)
                      end

          transformed[camel_key] = transform_value(value, context)
        end

        transformed
      end

      # Convert camelCase hash to snake_case for internal storage
      # @param hash [Hash] Input hash with camelCase keys
      # @return [Hash] Output hash with snake_case keys
      def from_apple_format(hash)
        return hash unless hash.is_a?(Hash)

        transformed = {}

        hash.each do |key, value|
          string_key = key.to_s

          # Preserve keys that shouldn't be transformed
          if PRESERVE_KEYS.include?(string_key)
            transformed[string_key] = transform_value_from_apple(value)
            next
          end

          # Apply reverse mapping
          snake_key = FROM_APPLE_MAPPINGS[string_key] || string_key.underscore
          transformed[snake_key] = transform_value_from_apple(value)
        end

        transformed
      end

      private

      def map_message_field(key, context)
        # In received/reply message context, strip the prefix
        case key
        when 'received_title', 'reply_title'
          'title'
        when 'received_subtitle', 'reply_subtitle'
          'subtitle'
        when 'received_image_identifier', 'reply_image_identifier'
          'imageIdentifier'
        when 'received_style', 'reply_style'
          'style'
        when 'reply_image_title'
          'imageTitle'
        when 'reply_image_subtitle'
          'imageSubtitle'
        when 'reply_secondary_subtitle'
          'secondarySubtitle'
        when 'reply_tertiary_subtitle'
          'tertiarySubtitle'
        else
          TO_APPLE_MAPPINGS[key] || key.camelize(:lower)
        end
      end

      def transform_value(value, context)
        case value
        when Hash
          to_apple_format(value, context: context)
        when Array
          value.map { |item| transform_value(item, context) }
        else
          value
        end
      end

      def transform_value_from_apple(value)
        case value
        when Hash
          from_apple_format(value)
        when Array
          value.map { |item| transform_value_from_apple(item) }
        else
          value
        end
      end
    end
  end
end
```

#### Step 1.2: Add Comprehensive Tests

**File**: `spec/services/apple_messages_for_business/case_transformer_spec.rb`

```ruby
# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AppleMessagesForBusiness::CaseTransformer do
  describe '.to_apple_format' do
    context 'with list picker data' do
      it 'converts snake_case to camelCase correctly' do
        input = {
          'sections' => [
            {
              'title' => 'Options',
              'multiple_selection' => true,
              'items' => [
                {
                  'identifier' => 'item_1',
                  'title' => 'Option 1',
                  'image_identifier' => 'img_123'
                }
              ]
            }
          ]
        }

        result = described_class.to_apple_format(input)

        expect(result['sections'].first['multipleSelection']).to eq(true)
        expect(result['sections'].first['items'].first['imageIdentifier']).to eq('img_123')
      end
    end

    context 'with received_message context' do
      it 'strips prefixes for message fields' do
        input = {
          'received_title' => 'Select an option',
          'received_subtitle' => 'Please choose',
          'received_image_identifier' => 'img_456',
          'received_style' => 'large'
        }

        result = described_class.to_apple_format(input, context: :received_message)

        expect(result).to eq({
          'title' => 'Select an option',
          'subtitle' => 'Please choose',
          'imageIdentifier' => 'img_456',
          'style' => 'large'
        })
      end
    end

    context 'with time picker data' do
      it 'converts timezone_offset and start_time' do
        input = {
          'event' => {
            'timezone_offset' => -480,
            'timeslots' => [
              { 'start_time' => '2025-10-26T10:00+0000', 'duration' => 3600 }
            ]
          }
        }

        result = described_class.to_apple_format(input)

        expect(result['event']['timezoneOffset']).to eq(-480)
        expect(result['event']['timeslots'].first['startTime']).to eq('2025-10-26T10:00+0000')
      end
    end
  end

  describe '.from_apple_format' do
    it 'converts camelCase to snake_case' do
      input = {
        'imageIdentifier' => 'img_123',
        'multipleSelection' => true,
        'receivedMessage' => {
          'title' => 'Test',
          'imageIdentifier' => 'img_456'
        }
      }

      result = described_class.from_apple_format(input)

      expect(result['image_identifier']).to eq('img_123')
      expect(result['multiple_selection']).to eq(true)
      expect(result['received_message']['image_identifier']).to eq('img_456')
    end
  end
end
```

---

### Phase 2: Update Service Layer

**Estimated Time**: 12-16 hours

#### Step 2.1: Update SendMessageService Base Class

**File**: `app/services/apple_messages_for_business/send_message_service.rb`

**Changes**:

1. **Add CaseTransformer usage in build_received_message**:

```ruby
def build_received_message
  default_title = if @message.content_type == 'apple_form' && content_attributes['title'].present?
                    content_attributes['title']
                  else
                    @message.content || 'Interactive Message'
                  end

  # Check for nested structure first
  received_msg = content_attributes['received_message'] || {}

  # Build message using ONLY snake_case keys (no more dual checks)
  msg = {
    'received_title' => received_msg['title'] || content_attributes['received_title'] || default_title,
    'received_subtitle' => received_msg['subtitle'] || content_attributes['received_subtitle'],
    'received_image_identifier' => received_msg['image_identifier'] || content_attributes['received_image_identifier'],
    'received_style' => received_msg['style'] || content_attributes['received_style'] || 'icon'
  }.compact

  # Transform to Apple format
  CaseTransformer.to_apple_format(msg, context: :received_message)
end
```

2. **Update build_reply_message similarly**:

```ruby
def build_reply_message
  default_reply_title = if @message.content_type == 'apple_form' && content_attributes['title'].present?
                          "#{content_attributes['title']} - Submitted"
                        else
                          'Selection Made'
                        end

  reply_msg = content_attributes['reply_message'] || {}

  # Build using ONLY snake_case
  msg = {
    'reply_title' => reply_msg['title'] || content_attributes['reply_title'] || default_reply_title,
    'reply_subtitle' => reply_msg['subtitle'] || content_attributes['reply_subtitle'],
    'reply_image_identifier' => reply_msg['image_identifier'] || content_attributes['reply_image_identifier'],
    'reply_style' => reply_msg['style'] || content_attributes['reply_style'] || 'icon',
    'reply_image_title' => content_attributes['reply_image_title'],
    'reply_image_subtitle' => content_attributes['reply_image_subtitle'],
    'reply_secondary_subtitle' => content_attributes['reply_secondary_subtitle'],
    'reply_tertiary_subtitle' => content_attributes['reply_tertiary_subtitle']
  }.compact

  # Transform to Apple format
  CaseTransformer.to_apple_format(msg, context: :reply_message)
end
```

#### Step 2.2: Update SendListPickerService

**File**: `app/services/apple_messages_for_business/send_list_picker_service.rb`

**Remove lines 195-204** (defensive dual checks):

```ruby
# BEFORE (lines 183-208):
def build_list_picker_data
  sections = content_attributes['sections'] || []

  transformed_sections = sections.map.with_index do |section, section_index|
    transformed_section = {
      'title' => section['title'],
      'multipleSelection' => section['multipleSelection'] || section['multiple_selection'] || false,
      'order' => section['order'] || section_index
    }

    if section['items'].present?
      transformed_section['items'] = section['items'].map.with_index do |item, item_index|
        transformed_item = {
          'identifier' => item['identifier'] || SecureRandom.uuid,
          'title' => item['title'],
          'subtitle' => item['subtitle'],
          'order' => item['order'] || item_index,
          'style' => item['style'] || 'icon'
        }

        # REMOVE THIS DEFENSIVE DUAL CHECK:
        if item['image_identifier'].present?
          transformed_item['imageIdentifier'] = item['image_identifier']
        elsif item['imageIdentifier'].present?
          transformed_item['imageIdentifier'] = item['imageIdentifier']
        end

        transformed_item
      end
    end

    transformed_section
  end

  { sections: transformed_sections }
end

# AFTER (simplified):
def build_list_picker_data
  sections = content_attributes['sections'] || []

  # Transform entire structure at once
  transformed = CaseTransformer.to_apple_format(
    { 'sections' => sections },
    context: :list_picker
  )

  # Ensure defaults
  transformed['sections'].each_with_index do |section, idx|
    section['order'] ||= idx
    section['items']&.each_with_index do |item, item_idx|
      item['identifier'] ||= SecureRandom.uuid
      item['order'] ||= item_idx
      item['style'] ||= 'icon'
    end
  end

  transformed
end
```

#### Step 2.3: Update SendTimePickerService

**File**: `app/services/apple_messages_for_business/send_time_picker_service.rb`

**Remove dual checks (lines 138-139, 164, 273-280)**:

```ruby
# BEFORE:
def build_time_picker_data
  event_data = content_attributes['event'] || {}
  image_identifier = event_data['image_identifier'] || event_data['imageIdentifier']
  # ...
end

def build_reply_message
  reply_image_id = content_attributes['reply_image_identifier'] ||
                   content_attributes['replyImageIdentifier']

  if reply_image_id.blank?
    received_image_id = content_attributes['received_image_identifier'] ||
                        content_attributes['receivedImageIdentifier']
    reply_image_id = received_image_id
  end
  # ...
end

# AFTER:
def build_time_picker_data
  event_data = content_attributes['event'] || {}

  # Use CaseTransformer
  CaseTransformer.to_apple_format(event_data, context: :event)
end

def build_reply_message
  # Auto-fallback logic (keep this, but use snake_case only)
  reply_image_id = content_attributes['reply_image_identifier']

  if reply_image_id.blank?
    reply_image_id = content_attributes['received_image_identifier']
  end

  msg = {
    'reply_title' => content_attributes['reply_title'] || 'Selected: ${event.title}',
    'reply_subtitle' => content_attributes['reply_subtitle'],
    'reply_image_identifier' => reply_image_id,
    'reply_style' => content_attributes['reply_style'] || 'large'
  }.compact

  CaseTransformer.to_apple_format(msg, context: :reply_message)
end
```

#### Step 2.4: Update FormService

**File**: `app/services/apple_messages_for_business/form_service.rb`

**Remove dual checks (lines 250, 263-270)**:

```ruby
# BEFORE:
def build_received_message
  received_msg = @form_config['received_message'] || {}
  received_image_id = received_msg['image_identifier'] || received_msg['imageIdentifier']
  # ...
end

# AFTER:
def build_received_message
  received_msg = @form_config['received_message'] || {}

  msg = {
    'received_title' => received_msg['title'] || @form_config['title'] || 'Please fill out this form',
    'received_subtitle' => received_msg['subtitle'],
    'received_image_identifier' => received_msg['image_identifier'],
    'received_style' => received_msg['style'] || 'large'
  }.compact

  CaseTransformer.to_apple_format(msg, context: :received_message)
end
```

#### Step 2.5: Update SendQuickReplyService

**File**: `app/services/apple_messages_for_business/send_quick_reply_service.rb`

**FIX BUG - currently only checks snake_case**:

```ruby
# BEFORE:
def build_received_message
  {
    title: content_attributes['received_title'] || 'Please select an option',
    subtitle: content_attributes['received_subtitle'],
    imageIdentifier: content_attributes['received_image_identifier'],
    style: content_attributes['received_style'] || 'small'
  }
end

# AFTER:
def build_received_message
  msg = {
    'received_title' => content_attributes['received_title'] || 'Please select an option',
    'received_subtitle' => content_attributes['received_subtitle'],
    'received_image_identifier' => content_attributes['received_image_identifier'],
    'received_style' => content_attributes['received_style'] || 'small'
  }.compact

  CaseTransformer.to_apple_format(msg, context: :received_message)
end
```

---

### Phase 3: Normalize API/Template Layer

**Estimated Time**: 6-8 hours

#### Step 3.1: Add API Controller Normalization

**File**: `app/controllers/api/v1/accounts/conversations/messages_controller.rb`

```ruby
class Api::V1::Accounts::Conversations::MessagesController < Api::V1::Accounts::BaseController
  before_action :normalize_apple_messages_params, only: [:create]

  private

  def normalize_apple_messages_params
    return unless params[:message][:content_attributes].present?
    return unless apple_messages_content_type?

    # Normalize camelCase to snake_case for Apple Messages content
    params[:message][:content_attributes] =
      AppleMessagesForBusiness::CaseTransformer.from_apple_format(
        params[:message][:content_attributes].to_unsafe_h
      )
  end

  def apple_messages_content_type?
    content_type = params[:message][:content_type]
    content_type&.start_with?('apple_')
  end
end
```

#### Step 3.2: Update Template Adapter

**File**: `app/services/templates/adapters/apple_messages_template_adapter.rb`

**Simplify to always output snake_case**:

```ruby
# BEFORE (lines 78-112):
def adapt_time_picker(block)
  properties = block[:properties]

  event_image_id = properties['imageIdentifier'] || properties['image_identifier']
  received_image_id = properties['receivedImageIdentifier'] || properties['received_image_identifier']
  reply_image_id = properties['replyImageIdentifier'] || properties['reply_image_identifier']
  reply_image_id = received_image_id if reply_image_id.blank?
  # ...
end

# AFTER (simplified):
def adapt_time_picker(block)
  properties = block[:properties]

  # Always output snake_case (CaseTransformer handles conversion later)
  {
    content_type: 'apple_time_picker',
    content: properties['title'] || 'Select a time',
    content_attributes: {
      'event' => {
        'title' => properties['title'],
        'description' => properties['description'],
        'identifier' => properties['identifier'] || SecureRandom.uuid,
        'timeslots' => format_timeslots(properties['slots']),
        'timezone_offset' => properties['timezone_offset'],
        'image_identifier' => properties['image_identifier']
      }.compact,
      'received_title' => properties['received_title'] || properties['title'],
      'reply_title' => properties['reply_title'] || 'Selected: ${event.title}',
      'received_image_identifier' => properties['received_image_identifier'],
      'reply_image_identifier' => properties['reply_image_identifier'] || properties['received_image_identifier'],
      'received_style' => properties['received_style'] || 'large',
      'reply_style' => properties['reply_style'] || 'large'
    }.compact
  }
end
```

**Apply same pattern to all adapter methods** (list picker, forms, etc.)

---

### Phase 4: Bot Integration

**Estimated Time**: 4-6 hours

#### Step 4.1: Update Bot Message Creation

Search for bot integration points and ensure snake_case:

```bash
# Find bot integration files
rg -l "bot.*apple" --type rb
```

Update any bot message builders to use snake_case consistently.

---

## Field Mapping Reference

### Complete Mapping Table

| Internal (snake_case) | Frontend Input (both accepted) | Apple MSP Output (camelCase) | Context |
|----------------------|-------------------------------|------------------------------|---------|
| `image_identifier` | `imageIdentifier`, `image_identifier` | `imageIdentifier` | item |
| `received_image_identifier` | `receivedImageIdentifier`, `received_image_identifier` | `imageIdentifier` | receivedMessage |
| `reply_image_identifier` | `replyImageIdentifier`, `reply_image_identifier` | `imageIdentifier` | replyMessage |
| `multiple_selection` | `multipleSelection`, `multiple_selection` | `multipleSelection` | section |
| `timezone_offset` | `timezoneOffset`, `timezone_offset` | `timezoneOffset` | event |
| `start_time` | `startTime`, `start_time` | `startTime` | timeslot |
| `received_message` | `receivedMessage`, `received_message` | `receivedMessage` | top-level |
| `reply_message` | `replyMessage`, `reply_message` | `replyMessage` | top-level |
| `received_title` | `receivedTitle`, `received_title` | `title` | receivedMessage context |
| `received_subtitle` | `receivedSubtitle`, `received_subtitle` | `subtitle` | receivedMessage context |
| `reply_title` | `replyTitle`, `reply_title` | `title` | replyMessage context |
| `reply_subtitle` | `replySubtitle`, `reply_subtitle` | `subtitle` | replyMessage context |
| `summary_text` | `summaryText`, `summary_text` | `summaryText` | quickReply |

### Preserved Fields (No Transformation)

These fields keep their original casing:

- `identifier`
- `title`
- `subtitle`
- `description`
- `style`
- `order`
- `duration`
- `v`, `id`, `type`
- `bid`, `data`, `version`
- `images`, `items`, `sections`, `pages`
- `timeslots`, `event`, `location`
- `oauth2`, `payment`, `form`

---

## Code Changes

### Files to Modify

#### New Files
1. `app/services/apple_messages_for_business/case_transformer.rb` (NEW)
2. `spec/services/apple_messages_for_business/case_transformer_spec.rb` (NEW)

#### Modified Files
3. `app/controllers/api/v1/accounts/conversations/messages_controller.rb`
   - Add before_action normalization
4. `app/models/concerns/content_attribute_validator.rb`
   - Remove dual-format acceptance
   - Expect only snake_case
5. `app/services/apple_messages_for_business/send_message_service.rb`
   - Update build_received_message
   - Update build_reply_message
   - Remove defensive checks
6. `app/services/apple_messages_for_business/send_list_picker_service.rb`
   - Simplify build_list_picker_data
   - Remove lines 195-204
7. `app/services/apple_messages_for_business/send_time_picker_service.rb`
   - Remove dual checks (lines 138-139, 164, 273-280)
8. `app/services/apple_messages_for_business/form_service.rb`
   - Remove dual checks (lines 250, 263-270)
9. `app/services/apple_messages_for_business/send_quick_reply_service.rb`
   - Fix bug (only checks snake_case currently)
10. `app/services/templates/adapters/apple_messages_template_adapter.rb`
    - Output only snake_case
    - Remove dual checks

### Code Removal Summary

**Total lines to remove**: ~60-80 lines of defensive dual-check code
**Total lines to add**: ~200-250 lines (CaseTransformer + tests)
**Net change**: +120-190 lines (better abstraction, cleaner code)

---

## Testing Strategy

### Unit Tests

#### 1. CaseTransformer Tests
- Test snake_case → camelCase conversion
- Test camelCase → snake_case conversion
- Test nested structure handling
- Test context-specific mappings
- Test preserved fields

#### 2. Service Tests
- Test each service builds correct Apple MSP payload
- Test message building with transformer
- Test backward compatibility (during transition)

#### 3. Validator Tests
- Test rejection of camelCase (after normalization disabled)
- Test acceptance of snake_case only

### Integration Tests

#### 1. Full Flow Tests
```ruby
describe 'Apple Messages end-to-end flow' do
  it 'converts frontend camelCase → internal snake_case → Apple MSP camelCase' do
    # Frontend sends camelCase
    frontend_payload = {
      content_type: 'apple_list_picker',
      content_attributes: {
        imageIdentifier: 'img_123',
        receivedMessage: {
          title: 'Select',
          imageIdentifier: 'img_456'
        }
      }
    }

    # API normalizes to snake_case
    message = create_message(frontend_payload)
    expect(message.content_attributes['image_identifier']).to eq('img_123')
    expect(message.content_attributes['received_message']['image_identifier']).to eq('img_456')

    # Service converts to Apple MSP camelCase
    service = AppleMessagesForBusiness::SendMessageService.new(...)
    payload = service.build_apple_msp_payload(...)
    expect(payload[:interactiveData][:data][:imageIdentifier]).to eq('img_123')
    expect(payload[:interactiveData][:receivedMessage][:imageIdentifier]).to eq('img_456')
  end
end
```

#### 2. Message Types Coverage
- List picker with images
- Time picker with images
- Forms with received/reply messages
- Quick replies
- All interactive message types

### Regression Tests

#### 1. Existing Messages
- Test that existing messages (mixed format) still work during transition
- Test backward compatibility

#### 2. Frontend Compatibility
- Test frontend can still send camelCase (gets normalized)
- Test no breaking changes to Vue components

---

## Migration Strategy

### Option A: Gradual Migration (Recommended)

**Phase 1: Deploy with Backward Compatibility**
1. Deploy CaseTransformer
2. Keep dual-checks in services temporarily
3. Add API normalization
4. Monitor logs for format inconsistencies

**Phase 2: Database Normalization (Optional)**
```ruby
# db/migrate/20251026_normalize_apple_messages_case.rb
class NormalizeAppleMessagesCase < ActiveRecord::Migration[7.0]
  def up
    Message.where("content_type LIKE 'apple_%'").find_each do |message|
      next unless message.content_attributes.present?

      normalized = AppleMessagesForBusiness::CaseTransformer.from_apple_format(
        message.content_attributes
      )

      message.update_column(:content_attributes, normalized) if normalized != message.content_attributes
    end
  end
end
```

**Phase 3: Remove Dual-Checks**
1. Remove defensive code from services
2. Update validator to reject camelCase
3. Full snake_case enforcement

### Option B: Big Bang Migration (Faster, Riskier)

1. Deploy all changes at once
2. Run database migration immediately
3. Monitor for errors

**Recommended**: Option A for production safety

---

## Rollback Plan

### If Issues Arise

**Level 1: Revert Code Changes**
```bash
git revert <commit-hash>
```

**Level 2: Re-enable Dual-Checks**
- Keep CaseTransformer deployed
- Restore defensive dual-check code temporarily
- Gives time to fix issues

**Level 3: Database Rollback**
```ruby
# Rollback migration if needed
rails db:rollback
```

### Monitoring

**Key Metrics**:
- Message send success rate (should remain 100%)
- Image display success rate
- Error logs for case-related issues

**Log Searches**:
```bash
# Find case-related errors
grep -i "imageidentifier\|image_identifier" log/production.log
```

---

## Appendix

### Appendix A: Performance Impact

**Before** (defensive dual-checks):
```ruby
# 2 hash lookups per field
image_id = item['image_identifier'] || item['imageIdentifier']

# For 20 items with 3 dual-checked fields each = 120 hash lookups
```

**After** (CaseTransformer):
```ruby
# 1 hash lookup per field + 1 transformation
# For 20 items with 3 fields each = 60 hash lookups + 1 transform

# Net improvement: ~40% reduction in lookups
```

### Appendix B: Code Review Checklist

- [ ] CaseTransformer handles all field mappings
- [ ] All services use CaseTransformer
- [ ] No dual-checks remain
- [ ] API normalization works
- [ ] Validator updated
- [ ] Tests pass (unit + integration)
- [ ] Frontend unchanged (backward compatible)
- [ ] Documentation updated

### Appendix C: Related Files

**Services**:
- `send_message_service.rb` (base class)
- `send_list_picker_service.rb`
- `send_time_picker_service.rb`
- `send_quick_reply_service.rb`
- `form_service.rb`
- `send_rich_link_service.rb`

**Validation**:
- `content_attribute_validator.rb`

**Templates**:
- `apple_messages_template_adapter.rb`

**Frontend** (reference only):
- `AppleMessagesComposer.vue`
- `EnhancedTimePickerModal.vue`
- `AppleFormBuilder.vue`
- `ListPickerBlockEditor.vue`

---

**End of Specification**

For questions or clarifications, contact the engineering team.
