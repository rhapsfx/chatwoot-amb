# Acoustic House Bot - Phase 3 Implementation Plan

## Overview

**Phase**: 3 - Lesson Booking, Time Picker, Rich Links & Photo Request
**States**: AHF2-AHF3, AHG1, AHH1-AHH2, AHI1-AHI4
**Python Lines**: 1111-1238
**Date**: November 12, 2025

This document provides a complete implementation plan for Phase 3 of the Acoustic House Bot, covering lesson booking flow with location-based time picker, rich link sharing, and photo request functionality.

---

## Phase 3 State Flow

### State Sequence

```
AHF2 → AHF3 → AHG1 → AHH1 → AHH2 → AHI1 → AHI2 → AHI3 → AHI4
```

### State Descriptions

| State | Description | Input | Output |
|-------|-------------|-------|--------|
| **AHF2** | Lesson introduction | Previous state | Text message about scheduling |
| **AHF3** | Location request | - | Text asking for zipcode |
| **AHG1** | Location processor | Zipcode or Apple Maps link | Time picker at location |
| **AHH1** | Time picker catcher | Text (non-selection) | Retry prompts, eventually skip |
| **AHH2** | Confirmation & continue | Time selection | Confirmation + continue QR |
| **AHI1** | Continue decision router | QR selection | Skip or continue to rich links |
| **AHI2** | Rich link display | - | Rich link to Apple docs |
| **AHI3** | Photo intro | - | Text about photos |
| **AHI4** | Photo request | - | QR asking to share photo |

---

## Implementation Tasks

### 1. Message Strings

Create message template records in database or use inline strings:

```ruby
# Message strings for Phase 3
PHASE_3_MESSAGES = {
  'applepay_3' => 'However, let\'s schedule a lesson with your new {{guitarText}}.',
  'apple_retail_2' => 'We can find the closest location for you, just message us your zipcode. Where are you?',
  'apple_retail_3' => 'We can find a few locations near your travel destination, just provide us with the zipcode.',
  'timepicker_0' => 'We were unable to locate your nearest Apple Store, so here are the available times at Apple Park.',
  'timepicker_stuck_1' => 'Looks like we\'re waiting for you to select a time from the menu above.',
  'timepicker_stuck_2' => 'You may set up a lesson at Apple Park',
  'timepicker_stuck_3' => 'If you find yourself stuck, you may have an overview with the keyword "Menu".',
  'timepicker_stuck_4' => 'You must be a shredding pro, we can skip scheduling a lesson.',
  'timepicker_2' => 'Shall we continue?',
  'richlinks_1' => 'There\'s so much more you can do like sharing beautiful links to your website:',
  'richlinks_2' => 'Earlier we sent you a photo.',
  'richlinks_3' => 'You can send us one too!!! {{firstName}} will you share a picture of your favorite food or place to eat?',
  'documents_3' => '{{firstName}}, would you like to learn more about Messages for Business?'
}.freeze
```

### 2. Quick Reply Templates

#### Template: Continue (qr_continue)

**File**: Create as MessageTemplate or inline in bot service

```ruby
{
  'summary_text' => 'Shall we continue?',
  'received_title' => 'Shall we continue?',
  'reply_title' => 'Selected: ${item.title}',
  'items' => [
    { 'title' => 'Yes', 'identifier' => 'qr_continue' },
    { 'title' => 'No', 'identifier' => 'qr_continue' }
  ]
}
```

**Response Handling**:
- **Yes** (selection 0): Continue to AHI2 (rich links)
- **No** (selection 1): Skip to AHK1 (learn more)

#### Template: Photo Request (qr_photo)

```ruby
{
  'summary_text' => 'Will you share a picture of your favorite food or place to eat?',
  'received_title' => 'Will you share a picture of your favorite food or place to eat?',
  'reply_title' => 'Selected: ${item.title}',
  'items' => [
    { 'title' => 'Yes', 'identifier' => 'qr_photo' },
    { 'title' => 'No', 'identifier' => 'qr_photo' }
  ]
}
```

**Response Handling**:
- **Yes** (selection 0): Move to AHJ1 (await photo)
- **No** (selection 1): Skip to next phase

### 3. MVP Location Hardcoded Mapping

For Phase 3 MVP, use hardcoded zipcode-to-location mapping:

```ruby
# MVP: Hardcoded location data (6 locations)
LOCATION_DATABASE = {
  # California
  '95014' => {
    name: 'Apple Park Visitor Center',
    latitude: 37.332863,
    longitude: -122.0053739,
    timezone_offset: '-0800'
  },
  '94102' => {
    name: 'Apple Union Square',
    latitude: 37.788493,
    longitude: -122.407074,
    timezone_offset: '-0800'
  },

  # New York
  '10019' => {
    name: 'Apple Fifth Avenue',
    latitude: 40.763829,
    longitude: -73.972699,
    timezone_offset: '-0500'
  },
  '10001' => {
    name: 'Apple World Trade Center',
    latitude: 40.711622,
    longitude: -74.011765,
    timezone_offset: '-0500'
  },

  # Texas
  '78701' => {
    name: 'Apple Domain Northside',
    latitude: 30.398798,
    longitude: -97.720589,
    timezone_offset: '-0600'
  },

  # Illinois
  '60611' => {
    name: 'Apple Michigan Avenue',
    latitude: 41.892639,
    longitude: -87.623734,
    timezone_offset: '-0600'
  }
}.freeze

def geocode_zipcode(zipcode)
  location = LOCATION_DATABASE[zipcode]

  if location.nil?
    # Default fallback: Apple Park
    LOCATION_DATABASE['95014']
  else
    location
  end
end
```

**Note**: This replaces the Python bot's full geocoding service with a simple MVP implementation. Future enhancement can integrate real geocoding API.

### 4. Time Picker Integration

Use existing `SendTimePickerService` with proper data structure:

```ruby
def send_lesson_time_picker(location)
  guitar = get_conversation_attribute('selected_guitar') || 'guitar'

  # Generate timeslots 7-8 days from now
  day1 = 7.days.from_now.to_date
  day2 = 8.days.from_now.to_date

  timeslots = [
    { 'identifier' => '0', 'start_time' => "#{day1}T15:30#{location[:timezone_offset]}", 'duration' => 3600 },
    { 'identifier' => '1', 'start_time' => "#{day1}T17:00#{location[:timezone_offset]}", 'duration' => 3600 },
    { 'identifier' => '2', 'start_time' => "#{day1}T19:30#{location[:timezone_offset]}", 'duration' => 3600 },
    { 'identifier' => '3', 'start_time' => "#{day2}T15:00#{location[:timezone_offset]}", 'duration' => 3600 },
    { 'identifier' => '4', 'start_time' => "#{day2}T17:30#{location[:timezone_offset]}", 'duration' => 3600 },
    { 'identifier' => '5', 'start_time' => "#{day2}T19:00#{location[:timezone_offset]}", 'duration' => 3600 }
  ]

  # Create message with time picker content
  message = Messages::MessageBuilder.new(
    bot_user,
    @conversation,
    {
      message_type: :outgoing,
      content: "Schedule a lesson with your #{guitar}",
      content_type: 'apple_time_picker',
      content_attributes: {
        'received_title' => "Schedule a lesson with your #{guitar}",
        'received_subtitle' => location[:name],
        'reply_title' => 'Thank you!',
        'event' => {
          'identifier' => SecureRandom.uuid,
          'title' => "Guitar Lesson - #{guitar}",
          'location' => {
            'latitude' => location[:latitude],
            'longitude' => location[:longitude],
            'radius' => 300.0,
            'title' => location[:name]
          },
          'timeslots' => timeslots
        }
      }
    }
  ).perform

  # Send via existing service
  channel = @conversation.inbox.channel
  contact_inbox = @conversation.contact_inbox
  destination_id = contact_inbox.source_id

  AppleMessagesForBusiness::SendTimePickerService.new(
    channel: channel,
    destination_id: destination_id,
    message: message
  ).perform
end
```

**Important**: The `SendTimePickerService` already handles:
- CaseTransformer for snake_case → camelCase conversion
- Image handling (if provided)
- Timeslot formatting (converts to Apple's required format)

### 5. Rich Link Implementation

Use existing `SendRichLinkService`:

```ruby
def send_apple_messages_rich_link
  # Create message with rich link
  message = Messages::MessageBuilder.new(
    bot_user,
    @conversation,
    {
      message_type: :outgoing,
      content: 'https://register.apple.com/resources/messages/messaging-documentation/',
      content_type: 'rich_link',
      content_attributes: {
        'url' => 'https://register.apple.com/resources/messages/messaging-documentation/',
        'title' => 'Apple Messages for Business',
        'image_url' => 'https://register.apple.com/resources/messages/images/hero.png'
        # Alternative: Use base64 image from Python bot's heroImage.png
      }
    }
  ).perform

  # Send via service
  channel = @conversation.inbox.channel
  contact_inbox = @conversation.contact_inbox
  destination_id = contact_inbox.source_id

  AppleMessagesForBusiness::SendRichLinkService.new(
    channel: channel,
    destination_id: destination_id,
    message: message
  ).perform
end
```

**Note**: `SendRichLinkService` handles:
- Image download and base64 encoding
- Favicon fallback
- Asset building for Apple MSP

---

## Ruby Bot Service Implementation

### State Handlers

#### AHF2: Lesson Introduction

```ruby
def handle_lesson_introduction
  guitar = get_conversation_attribute('selected_guitar') || 'your guitar'
  send_text_message("However, let's schedule a lesson with your new #{guitar}.")

  update_bot_state('AHF3')
  handle_location_request
end
```

#### AHF3: Location Request

```ruby
def handle_location_request
  intent = get_conversation_attribute('region')

  if intent == 'Traveling'
    send_text_message('We can find a few locations near your travel destination, just provide us with the zipcode.')
  else
    send_text_message('We can find the closest location for you, just message us your zipcode. Where are you?')
  end

  update_bot_state('AHG1')
end
```

#### AHG1: Location Response Processor

```ruby
def handle_location_response
  user_message = @message.content.strip

  # Check if Apple Maps link
  if user_message.include?('maps.apple.com')
    # Extract lat/long from Apple Maps link
    # Format: https://maps.apple.com/?ll=37.332863,-122.0053739
    match = user_message.match(/ll=([-\d.]+),([-\d.]+)/)

    if match
      location = {
        name: 'Selected Location',
        latitude: match[1].to_f,
        longitude: match[2].to_f,
        timezone_offset: '-0800' # Default PST, can be enhanced
      }

      send_text_message("Great! Here are available times at #{location[:name]}.")
      send_lesson_time_picker(location)
      update_bot_state('AHH1')
      reset_retry_count
      return
    end
  end

  # Try geocoding zipcode (MVP: hardcoded lookup)
  location = geocode_zipcode(user_message)

  if location
    send_text_message('We were unable to locate your nearest Apple Store, so here are the available times at Apple Park.')
    send_lesson_time_picker(location)
    update_bot_state('AHH1')
    reset_retry_count
  else
    # Retry location request
    increment_retry_count
    send_text_message('Sorry, I couldn\'t find that location. Please try another zipcode.')
  end
end
```

#### AHH1: Time Picker Catcher

```ruby
def handle_time_picker_catcher
  retry_count = increment_retry_count

  case retry_count
  when 1
    send_text_message('Looks like we\'re waiting for you to select a time from the menu above.')
  when 2
    send_text_message('You may set up a lesson at Apple Park')
    # Re-send time picker
    location = LOCATION_DATABASE['95014'] # Apple Park default
    send_lesson_time_picker(location)
  when 3
    send_text_message('If you find yourself stuck, you may have an overview with the keyword "Menu".')
  when 4
    send_text_message('You must be a shredding pro, we can skip scheduling a lesson.')
    reset_retry_count
    update_bot_state('AHH2')
    handle_continue_prompt
  else
    # After 4+ retries, repeat message every time
    send_text_message('Still waiting for your time selection, or type "Menu" for help.')
  end
end
```

#### AHH2: Continue Prompt

```ruby
def handle_continue_prompt
  send_text_message('Thank you for your co-operation, you\'re all set to learn to shred. 🤘')
  send_text_message('Shall we continue?')

  # Send continue quick reply
  send_quick_reply(
    title: 'Shall we continue?',
    request_id: 'qr_continue',
    items: [
      { title: 'Yes', value: 'Yes' },
      { title: 'No', value: 'No' }
    ]
  )

  update_bot_state('AHI1')
end
```

#### AHI1: Continue Response Router

```ruby
def handle_continue_response(interactive_data)
  selection_title = interactive_data.dig('data', 'reply', 'title')

  if selection_title == 'No'
    # Skip to learn more (AHK1 - Phase 4)
    update_bot_state('AHK1')
    handle_learn_more_prompt
  else
    # Continue to rich links
    update_bot_state('AHI1-wait')

    send_text_message('There\'s so much more you can do like sharing beautiful links to your website:')

    update_bot_state('AHI2')
    handle_rich_link_display
  end
end
```

#### AHI2: Rich Link Display

```ruby
def handle_rich_link_display
  send_apple_messages_rich_link

  # Wait 4 seconds (awkStop equivalent)
  # Note: In async Ruby, use ActiveJob or immediate state update

  update_bot_state('AHI3')
  handle_photo_intro
end
```

#### AHI3: Photo Introduction

```ruby
def handle_photo_intro
  send_text_message('Earlier we sent you a photo.')

  # Wait 2 seconds

  update_bot_state('AHI4')
  handle_photo_request
end
```

#### AHI4: Photo Request

```ruby
def handle_photo_request
  first_name = get_conversation_attribute('customer_name') || 'there'

  send_text_message("You can send us one too!!! #{first_name} will you share a picture of your favorite food or place to eat?")

  # Send photo request quick reply
  send_quick_reply(
    title: 'Will you share a picture?',
    request_id: 'qr_photo',
    items: [
      { title: 'Yes', value: 'Yes' },
      { title: 'No', value: 'No' }
    ]
  )

  update_bot_state('AHJ1')
end
```

### Interactive Handler Updates

Add to `INTERACTIVE_HANDLERS` constant:

```ruby
INTERACTIVE_HANDLERS = {
  # ... existing handlers ...
  'time_0319' => :handle_time_picker_response,
  'qr_continue' => :handle_continue_response,
  'qr_photo' => :handle_photo_response
}.freeze
```

Add handler methods:

```ruby
def handle_time_picker_response(interactive_data)
  # Extract selected timeslot
  selected_timeslot = interactive_data.dig('data', 'timeslot')

  if selected_timeslot
    # Store selection
    update_conversation_attribute('selected_timeslot', selected_timeslot)
    reset_retry_count

    # Move to confirmation
    update_bot_state('AHH2')
    handle_continue_prompt
  else
    # Invalid response, stay in catcher
    handle_time_picker_catcher
  end
end

def handle_photo_response(interactive_data)
  selection_title = interactive_data.dig('data', 'reply', 'title')

  if selection_title == 'Yes'
    send_text_message('Awesome! We will hang tight while you send us your fav.')
    update_bot_state('AHJ1-wait') # Await photo upload
  else
    send_text_message('Or... just send a photo anytime')
    update_bot_state('AHJ2') # Move to next phase
  end
end
```

---

## Testing Plan

### 1. Manual Testing Flow

**Happy Path**:
1. Start bot → Complete Phase 1-2 (guitar selection, AR, Apple Pay)
2. Receive lesson introduction (AHF2)
3. Enter zipcode "95014"
4. Receive time picker with Apple Park location
5. Select a timeslot
6. Receive confirmation and "Shall we continue?" QR
7. Select "Yes"
8. Receive rich link to Apple documentation
9. Receive photo request QR
10. Select "Yes" or "No"

**Edge Cases**:
- Invalid zipcode → Default to Apple Park
- No timeslot selection → Retry prompts (1-4 times)
- Apple Maps link input → Extract lat/long
- "No" on continue → Skip to learn more

### 2. State Persistence Testing

Verify conversation custom_attributes store:
- `bot_state`: Current state
- `bot_state_updated_at`: Timestamp
- `selected_guitar`: Guitar choice from Phase 1
- `customer_name`: Name from Phase 1
- `region`: Region from Phase 1
- `selected_timeslot`: Chosen lesson time
- `retry_count`: Catcher retry counter

### 3. Service Integration Testing

- **SendTimePickerService**: Verify time picker payload with images
- **SendRichLinkService**: Verify rich link with image asset
- **SendQuickReplyService**: Verify continue and photo QRs

---

## Migration & Deployment

### 1. Code Changes

**Files to modify**:
- `/Users/rhaps/LocalGit/chatwoot/app/services/apple_messages_for_business/acoustic_house_bot_service.rb`

**Add**:
- Phase 3 message strings
- Location database constant
- State handlers (AHF2-AHI4)
- Interactive response handlers
- Helper methods (geocode_zipcode, send_lesson_time_picker, send_apple_messages_rich_link)

### 2. Database Changes

**None required** - Uses existing conversation custom_attributes JSON storage

### 3. Template Creation (Optional)

If using MessageTemplate model instead of inline:
- Create "Continue Quick Reply" template
- Create "Photo Request Quick Reply" template

### 4. Deployment Steps

1. **Test locally**:
   ```bash
   ./script//dev-server.sh start
   ```

2. **Verify services**:
   - Check SendTimePickerService works with new data structure
   - Check SendRichLinkService fetches image from URL
   - Check SendQuickReplyService handles new QR templates

3. **Deploy to production**:
   ```bash
   ./script/deploy-backend-changes-safe.sh
   ```

4. **Monitor logs**:
   ```bash
   tail -f log/production.log | grep -i "bot"
   ```

---

## Known Limitations & Future Enhancements

### MVP Limitations

1. **Geocoding**: Hardcoded 6 locations only
   - **Future**: Integrate Google Geocoding API or Apple Maps API

2. **Timezone Detection**: Static timezone offsets
   - **Future**: Use timezone gem to detect timezone from lat/long

3. **Image Handling**: Rich link fetches image from URL
   - **Future**: Store heroImage.png in ActiveStorage for faster loading

4. **Wait Times**: No real delays (awkStop equivalent)
   - **Future**: Use ActiveJob with delayed execution

### Enhancement Opportunities

1. **Dynamic Timeslots**: Generate timeslots based on location's business hours
2. **Real Store Lookup**: Integrate with Apple Store location API
3. **Photo Upload Handling**: Process and store user-uploaded photos
4. **Multi-language Support**: Add i18n for all messages
5. **Analytics**: Track conversion rates at each phase

---

## Appendix: Python to Ruby Mapping

### Message String Mapping

| Python Message ID | Ruby String | Variables |
|-------------------|-------------|-----------|
| `applepay_3` | "However, let's schedule a lesson with your new {{guitarText}}." | guitar |
| `apple_retail_2` | "We can find the closest location for you..." | - |
| `apple_retail_3` | "We can find a few locations near your travel destination..." | - |
| `timepicker_0` | "We were unable to locate your nearest Apple Store..." | - |
| `timepicker_stuck_1` | "Looks like we're waiting for you to select a time..." | - |
| `timepicker_stuck_2` | "You may set up a lesson at Apple Park" | - |
| `timepicker_stuck_3` | "If you find yourself stuck, you may have an overview..." | - |
| `timepicker_stuck_4` | "You must be a shredding pro, we can skip..." | - |
| `timepicker_2` | "Shall we continue?" | - |
| `richlinks_1` | "There's so much more you can do like sharing beautiful links..." | - |
| `richlinks_2` | "Earlier we sent you a photo." | - |
| `richlinks_3` | "You can send us one too!!! {{firstName}} will you share..." | first_name |
| `documents_3` | "{{firstName}}, would you like to learn more about Messages for Business?" | first_name |

### State Mapping

| Python State | Ruby State | Handler Method |
|--------------|------------|----------------|
| `AHF2` | `AHF2` | `handle_lesson_introduction` |
| `AHF3` | `AHF3` | `handle_location_request` |
| `AHG1` | `AHG1` | `handle_location_response` |
| `AHH1` | `AHH1` | `handle_time_picker_catcher` |
| `AHH2` | `AHH2` | `handle_continue_prompt` |
| `AHI1` | `AHI1` | `handle_continue_response` |
| `AHI2` | `AHI2` | `handle_rich_link_display` |
| `AHI3` | `AHI3` | `handle_photo_intro` |
| `AHI4` | `AHI4` | `handle_photo_request` |

### Function Mapping

| Python Function | Ruby Method | Service Used |
|-----------------|-------------|--------------|
| `sendLocalTimePicker()` | `send_lesson_time_picker()` | `SendTimePickerService` |
| `sendRichlink()` | `send_apple_messages_rich_link()` | `SendRichLinkService` |
| `sendInteractive()` (QR) | `send_quick_reply()` | `SendQuickReplyService` |
| `findGeocode()` | `geocode_zipcode()` | MVP hardcoded mapping |
| `awkStop()` | N/A (immediate state change) | Could use ActiveJob delay |

---

## Implementation Checklist

- [ ] Add Phase 3 message strings to bot service
- [ ] Add LOCATION_DATABASE constant with 6 hardcoded locations
- [ ] Implement geocode_zipcode() helper method
- [ ] Implement send_lesson_time_picker() helper method
- [ ] Implement send_apple_messages_rich_link() helper method
- [ ] Add state handlers: AHF2, AHF3, AHG1, AHH1, AHH2
- [ ] Add state handlers: AHI1, AHI2, AHI3, AHI4
- [ ] Add interactive handlers: time_0319, qr_continue, qr_photo
- [ ] Update INTERACTIVE_HANDLERS constant
- [ ] Update process_state case statement
- [ ] Test zipcode geocoding (valid + invalid)
- [ ] Test Apple Maps link parsing
- [ ] Test time picker display and response
- [ ] Test continue QR (Yes/No paths)
- [ ] Test rich link display with image
- [ ] Test photo request QR
- [ ] Test retry logic in time picker catcher (1-4 retries)
- [ ] Verify state persistence across messages
- [ ] Load test with multiple concurrent users
- [ ] Deploy to production
- [ ] Monitor Phase 3 completion rates

---

## Support & Troubleshooting

### Common Issues

**Issue**: Time picker not displaying
**Solution**: Check content_attributes format, ensure timeslots have proper start_time format

**Issue**: Rich link image not loading
**Solution**: Verify URL is accessible, check SendRichLinkService logs for download errors

**Issue**: Location not found
**Solution**: Add more zipcodes to LOCATION_DATABASE or default to Apple Park

**Issue**: State stuck in AHH1 catcher
**Solution**: Check retry_count, ensure handle_time_picker_response is called on selection

### Debug Commands

```ruby
# Rails console
conversation = Conversation.find(ID)
conversation.custom_attributes['bot_state']
conversation.custom_attributes['retry_count']
conversation.custom_attributes['selected_guitar']

# Check last outgoing message
conversation.messages.outgoing.last.content_attributes

# Reset bot state
conversation.custom_attributes['bot_state'] = 'AHF2'
conversation.save!
```

---

**End of Phase 3 Implementation Plan**
