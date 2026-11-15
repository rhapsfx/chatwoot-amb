# Acoustic House Bot - Keywords Reference

## Overview

The Acoustic House Bot responds to specific keywords at any point in the conversation to control the flow, replay sections, or access demos.

## Flow Control Keywords

### Schedule/Lesson Keywords

| Keyword | Action |
|---------|--------|
| `schedule` | Replay from location sharing request |
| `schedule lesson` | Replay from location sharing request |
| `lesson` | Replay from location sharing request |

**Use Case**: When you want to schedule a lesson from any point in the conversation.

**Example Flow**:
```
User: "schedule"
Bot: "Let's schedule a lesson with your guitar!"
Bot: "We can find the closest location for you, just message us your zipcode. Where are you?"
→ User provides zipcode or Apple Maps URL
→ Bot shows store selection
→ User picks store
→ Bot shows time picker
```

### Navigation Keywords

| Keyword | Action |
|---------|--------|
| `menu` | Show main menu with options |
| `startover` | Restart conversation from beginning |
| `start over` | Restart conversation from beginning |
| `restart` | Restart conversation from beginning |
| `begin` | Restart conversation from beginning |
| `reset` | Restart conversation from beginning |
| `stop` | Stop the bot (type 'startover' to resume) |
| `summary` | Show conversation summary |
| `skip` | Skip payment (only during payment flow) |

### Demo Keywords

These keywords show isolated demos without continuing the full flow:

| Keyword | Demo |
|---------|------|
| `list picker` | Guitar selection list picker demo |
| `listpicker` | Guitar selection list picker demo |
| `guitar` | Guitar selection list picker demo |
| `guitars` | Guitar selection list picker demo |
| `time picker` | Time picker demo |
| `timepicker` | Time picker demo |
| `appointment` | Time picker demo |
| `time` | Time picker demo |
| `apple pay` | Apple Pay payment demo |
| `payment` | Apple Pay payment demo |
| `pay` | Apple Pay payment demo |
| `form` | Apple Messages Form demo |
| `help me decide` | Apple Messages Form demo |
| `ar` | Augmented Reality demo |
| `augmented reality` | Augmented Reality demo |

## Usage Patterns

### During Time Picker State

**Problem**: User is stuck at time picker and wants to change location.

**Solution**:
```
User: "schedule"
Bot: "Let's schedule a lesson with your guitar!"
Bot: "We can find the closest location for you, just message us your zipcode. Where are you?"
```

**Alternative Solution**:
```
User: "lesson"
Bot: "Let's schedule a lesson with your guitar!"
Bot: "We can find the closest location for you, just message us your zipcode. Where are you?"
```

### After Completing a Purchase

**Problem**: User wants to schedule another lesson after completing the flow.

**Solution**:
```
User: "schedule"
Bot: "Let's schedule a lesson with your guitar!"
→ User provides new location
→ Bot shows stores
→ User selects store
→ Bot shows time picker
```

### Testing Different Locations

**Problem**: User wants to quickly test different store locations.

**Solution**:
```
User: "schedule"
Bot: "Let's schedule a lesson with your guitar!"
User: "94102" (San Francisco)
→ Bot shows SF stores

User: "schedule"
Bot: "Let's schedule a lesson with your guitar!"
User: "10019" (New York)
→ Bot shows NY stores
```

## Implementation Details

### Keyword Detection

- **Case Insensitive**: Keywords work in any case (e.g., "SCHEDULE", "Schedule", "schedule")
- **Priority**: Flow control keywords are checked before state-based processing
- **Availability**: Keywords work at any point in the conversation (except demo mode)

### Schedule Lesson Handler

**Method**: `handle_schedule_lesson`

**Behavior**:
1. Logs the keyword trigger
2. Resets retry counts
3. Gets selected guitar from conversation attributes (or defaults to "guitar")
4. Sends friendly message: "Let's schedule a lesson with your {guitar}!"
5. Calls `handle_location_request` to restart from location sharing

**State Change**: Sets bot state to `AHG1` (waiting for location input)

### Location Request Flow

**State**: AHG1

**Behavior**:
- Checks if user selected "Traveling" region → asks for travel destination zipcode
- Otherwise → asks for their current zipcode
- Waits for user to provide:
  - Zipcode (e.g., "94102", "10019")
  - Apple Maps URL (e.g., "https://maps.apple.com/?ll=37.7749,-122.4194")

**Next State**: AHG2 (store selection) or AHH1 (time picker if API fails)

## Related Files

- Bot Service: `app/services/apple_messages_for_business/acoustic_house_bot_service.rb`
  - Lines 33-46: Keyword definitions
  - Lines 1158-1169: Schedule lesson handler
  - Lines 836-846: Location request handler
- Apple Maps Service: `app/services/apple_messages_for_business/apple_maps_service.rb`

## Testing Keywords

```bash
# Start development server
./script//dev-server.sh start-public

# Connect via Apple Messages for Business

# Test schedule keyword at different points:
1. At welcome screen: "schedule"
2. After guitar selection: "schedule"
3. During time picker: "schedule"
4. After completing flow: "schedule"
```

## User Experience

### Before This Update

**User sends**: "schedule"

**Bot responds**: "Looks like we're waiting for you to select a time from the menu above"

❌ **Problem**: Bot doesn't understand intent, treats as invalid input during time picker state

### After This Update

**User sends**: "schedule"

**Bot responds**: "Let's schedule a lesson with your guitar!"

**Bot continues**: "We can find the closest location for you, just message us your zipcode. Where are you?"

✅ **Solution**: Bot recognizes intent and restarts scheduling flow from location request

## Best Practices

1. **Use "schedule" for quick access** to lesson booking flow
2. **Use "menu"** to see all available options
3. **Use "startover"** to completely restart the conversation
4. **Use "stop"** to pause bot interactions

## Future Enhancements

Potential additions:
- `reschedule` - Cancel current selection and pick new time
- `change location` - Go back to location selection
- `different store` - Show store list picker again
- `my bookings` - View scheduled lessons
- `cancel lesson` - Cancel a scheduled lesson
