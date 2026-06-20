# Phase 3: Visual Flow Diagram

```
┌──────────────────────────────────────────────────────────────────────────┐
│                         PHASE 3 FLOW DIAGRAM                              │
│                  Lesson Booking, Time Picker, Rich Links                  │
└──────────────────────────────────────────────────────────────────────────┘

┌─────────────┐
│   Phase 2   │
│  (AHE2/AHF1)│
│  Apple Pay  │
└──────┬──────┘
       │
       ▼
┌──────────────────────────────────────────────────────────────────────┐
│ AHF2: Lesson Introduction                                            │
│ "However, let's schedule a lesson with your new [guitar]."           │
└──────┬───────────────────────────────────────────────────────────────┘
       │
       ▼
┌──────────────────────────────────────────────────────────────────────┐
│ AHF3: Location Request                                               │
│ • If Traveling: "...provide us with the zipcode"                     │
│ • If Local: "...message us your zipcode. Where are you?"             │
└──────┬───────────────────────────────────────────────────────────────┘
       │
       ▼
┌──────────────────────────────────────────────────────────────────────┐
│ AHG1: Location Response (User Input)                                 │
│                                                                       │
│ Input Type 1: Zipcode (e.g., "95014")                                │
│   → Lookup in LOCATION_DATABASE                                      │
│   → Default to Apple Park if not found                               │
│                                                                       │
│ Input Type 2: Apple Maps Link                                        │
│   → Extract lat/long from "maps.apple.com/?ll=LAT,LONG"              │
│   → Use extracted coordinates                                        │
└──────┬───────────────────────────────────────────────────────────────┘
       │
       ▼
┌──────────────────────────────────────────────────────────────────────┐
│ Send Time Picker                                                     │
│ • Location: Apple Park (or geocoded location)                        │
│ • 6 timeslots: 7-8 days from now                                     │
│ • Times: 3:30pm, 5:00pm, 7:30pm (Day 1)                              │
│          3:00pm, 5:30pm, 7:00pm (Day 2)                              │
│ • Duration: 1 hour each                                              │
└──────┬───────────────────────────────────────────────────────────────┘
       │
       ▼
┌──────────────────────────────────────────────────────────────────────┐
│ AHH1: Time Picker Catcher (Retry Logic)                              │
│                                                                       │
│ User sends text instead of selecting time:                           │
│                                                                       │
│ Retry 1: "Looks like we're waiting for you to select a time..."      │
│ Retry 2: "You may set up a lesson at Apple Park"                     │
│          → Re-send time picker                                       │
│ Retry 3: "If you find yourself stuck, type 'Menu'"                   │
│ Retry 4: "You must be a shredding pro, we can skip..."               │
│          → Skip to AHH2                                              │
└──────┬───────────────────────────────────────────────────────────────┘
       │
       │ (User selects timeslot OR after 4 retries)
       │
       ▼
┌──────────────────────────────────────────────────────────────────────┐
│ AHH2: Confirmation & Continue Prompt                                 │
│ "Thank you for your co-operation, you're all set to shred. 🤘"       │
│ "Shall we continue?"                                                 │
│                                                                       │
│ ┌──────────────────────────────────────────────────────────────┐    │
│ │ Quick Reply: qr_continue                                      │    │
│ │ [ Yes ]  [ No ]                                               │    │
│ └──────────────────────────────────────────────────────────────┘    │
└──────┬────────────────────────────────────┬──────────────────────────┘
       │                                    │
       │ Yes                                │ No
       ▼                                    ▼
┌──────────────────────────┐       ┌───────────────────────────┐
│ AHI1: Continue           │       │ Skip to AHK1              │
│ Route to AHI2            │       │ (Learn More - Phase 4)    │
└──────┬───────────────────┘       └───────────────────────────┘
       │
       ▼
┌──────────────────────────────────────────────────────────────────────┐
│ AHI2: Rich Link Display                                              │
│ "There's so much more you can do like sharing beautiful links..."    │
│                                                                       │
│ ┌──────────────────────────────────────────────────────────────┐    │
│ │ Rich Link                                                     │    │
│ │ ┌────────────┐                                                │    │
│ │ │ Hero Image │  Apple Messages for Business                  │    │
│ │ └────────────┘  https://register.apple.com/...               │    │
│ └──────────────────────────────────────────────────────────────┘    │
└──────┬───────────────────────────────────────────────────────────────┘
       │
       ▼
┌──────────────────────────────────────────────────────────────────────┐
│ AHI3: Photo Introduction                                             │
│ "Earlier we sent you a photo."                                       │
└──────┬───────────────────────────────────────────────────────────────┘
       │
       ▼
┌──────────────────────────────────────────────────────────────────────┐
│ AHI4: Photo Request                                                  │
│ "You can send us one too!!! [name] will you share a picture of       │
│  your favorite food or place to eat?"                                │
│                                                                       │
│ ┌──────────────────────────────────────────────────────────────┐    │
│ │ Quick Reply: qr_photo                                         │    │
│ │ [ Yes ]  [ No ]                                               │    │
│ └──────────────────────────────────────────────────────────────┘    │
└──────┬────────────────────────────────┬──────────────────────────────┘
       │                                │
       │ Yes                            │ No
       ▼                                ▼
┌──────────────────────────┐   ┌──────────────────────────────┐
│ AHJ1: Await Photo        │   │ "Or... send a photo anytime" │
│ "Awesome! We will hang   │   │ Move to AHK1 (Phase 4)       │
│  tight while you send    │   └──────────────────────────────┘
│  us your fav."           │
│ State: AHJ1-wait         │
└──────────────────────────┘

┌─────────────┐
│   Phase 4   │
│   (AHJ1+)   │
│  Documents  │
│   Summary   │
└─────────────┘
```

---

## State Persistence

Throughout Phase 3, the following data is persisted in `conversation.custom_attributes`:

```ruby
{
  'bot_state' => 'AHI4',                          # Current state
  'bot_state_updated_at' => '2025-11-12T...',     # Timestamp
  'retry_count' => 0,                             # Retry counter

  # From Phase 1-2:
  'region' => 'Americas',                         # Selected region
  'customer_name' => 'John',                      # User's name
  'selected_guitar' => 'Martin DC28E Dreadnought', # Chosen guitar

  # New in Phase 3:
  'selected_timeslot' => {                        # Chosen lesson time
    'identifier' => '2',
    'startTime' => '2025-11-19T19:30-0800',
    'duration' => 3600
  }
}
```

---

## Service Call Flow

```
User Input (Zipcode: "95014")
        │
        ▼
┌────────────────────────┐
│ handle_location_response │
│ - Call geocode_zipcode() │
│ - Get location data      │
└────────┬────────────────┘
         │
         ▼
┌─────────────────────────────┐
│ send_lesson_time_picker()    │
│ - Generate 6 timeslots       │
│ - Build content_attributes   │
│   (snake_case)               │
└────────┬─────────────────────┘
         │
         ▼
┌──────────────────────────────┐
│ Messages::MessageBuilder     │
│ - Create message record      │
│ - Store content_attributes   │
└────────┬──────────────────────┘
         │
         ▼
┌───────────────────────────────────┐
│ SendTimePickerService             │
│ - Read content_attributes         │
│ - Format timeslots (ISO-8601)     │
│ - CaseTransformer (snake→camel)   │
│ - Build Apple MSP payload         │
└────────┬──────────────────────────┘
         │
         ▼
┌──────────────────────────────┐
│ Apple MSP Gateway             │
│ POST /v1/message              │
│ {                             │
│   type: "interactive",        │
│   interactiveData: {          │
│     event: {                  │
│       timeslots: [            │
│         {                     │
│           startTime: "...",   │ ← camelCase
│           duration: 3600      │
│         }                     │
│       ]                       │
│     }                         │
│   }                           │
│ }                             │
└───────────────────────────────┘
```

---

## Error Handling

Phase 3 includes robust error handling at each critical point:

### 1. Geocoding
```ruby
location = geocode_zipcode(user_message)
# Always returns valid location (defaults to Apple Park)
```

### 2. Time Picker Send
```ruby
rescue StandardError => e
  Rails.logger.error "[Bot] Failed to send time picker: #{e.message}"
  # User sees error, but bot continues (doesn't crash)
end
```

### 3. Rich Link Send
```ruby
rescue StandardError => e
  Rails.logger.error "[Bot] Failed to send rich link: #{e.message}"
  # Continues to next state (AHI3)
end
```

### 4. Quick Reply Send
```ruby
rescue StandardError => e
  Rails.logger.error "[Bot] Failed to send quick reply: #{e.message}"
  # Bot state still updated, can recover
end
```

---

## Testing Scenarios

### Happy Path
1. User completes Phase 2 (Apple Pay) → Receives AHF2 lesson intro
2. User enters zipcode "95014" → Receives time picker for Apple Park
3. User selects 5:00pm slot → Receives confirmation + continue QR
4. User selects "Yes" → Receives rich link
5. User sees photo intro → Receives photo request QR
6. User selects "Yes" or "No" → Moves to Phase 4

### Edge Cases

#### Location Not Found
```
User: "99999"
Bot: "We were unable to locate your nearest Apple Store,
     so here are the available times at Apple Park."
     [Time Picker for Apple Park]
```

#### Time Picker Ignored (Retry Flow)
```
User: "I'm not sure about this"
Bot: (Retry 1) "Looks like we're waiting for you to select a time..."

User: "Can I skip this?"
Bot: (Retry 2) "You may set up a lesson at Apple Park"
     [Time Picker re-sent]

User: "Menu"
Bot: [Shows menu]

User: (Returns to flow, sends text again)
Bot: (Retry 3) "If you find yourself stuck, type 'Menu'"

User: (Sends text again)
Bot: (Retry 4) "You must be a shredding pro, we can skip..."
     → Moves to AHH2 (confirmation)
```

#### Apple Maps Link
```
User: "https://maps.apple.com/?ll=37.332863,-122.0053739"
Bot: "Great! Here are available times at Selected Location."
     [Time Picker with extracted lat/long]
```

#### Timeout (30+ minutes idle)
```
Bot State: AHI2 (waiting for user)
Time: 35 minutes pass
User: "Hello"
Bot: (Resets to AHA1) "Thank you for contacting Acoustic Bot Prod."
                      "Let's help you find your next guitar 🎸."
```

---

## Performance Characteristics

### Time Complexity
- **geocode_zipcode()**: O(1) - Hash lookup
- **send_lesson_time_picker()**: O(1) - Fixed 6 timeslots
- **send_apple_messages_rich_link()**: O(1) - Single HTTP request
- **State transitions**: O(1) - Direct method calls

### Space Complexity
- **LOCATION_DATABASE**: 6 locations × ~200 bytes = ~1.2 KB
- **Timeslots array**: 6 slots × ~100 bytes = ~600 bytes
- **custom_attributes**: ~1-2 KB per conversation

### Network Calls
- **Time Picker**: 1 API call to Apple MSP
- **Rich Link**: 1 image download + 1 API call to Apple MSP
- **Quick Replies**: 1 API call each (qr_continue, qr_photo)

**Total Phase 3**: ~5 API calls per user flow

---

## Maintenance & Future Enhancements

### Easy Wins
1. **Add more zipcodes**: Expand `LOCATION_DATABASE` hash
2. **Adjust timeslots**: Modify `send_lesson_time_picker()` timeslot generation
3. **Change retry messages**: Update case statement in `handle_time_picker_catcher()`
4. **Customize rich link**: Change URL/title in `send_apple_messages_rich_link()`

### Future Enhancements
1. **Real Geocoding**: Replace `geocode_zipcode()` with Google Geocoding API
2. **Dynamic Timezones**: Use `timezone` gem instead of static offsets
3. **Business Hours**: Generate timeslots based on store opening hours
4. **Image Caching**: Store `heroImage.png` in ActiveStorage
5. **Message Pacing**: Add ActiveJob delays between messages
6. **Analytics**: Track completion rates for each Phase 3 state

---

**End of Visual Flow Diagram**
