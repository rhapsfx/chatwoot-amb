# Acoustic House Bot - Complete Tier 2 Flow Diagram

## Overview

This document provides a complete flow diagram for all Tier 2 flows (Rich Links, Documents, and Summary) that have been added to the Acoustic House Bot.

## Summary Statistics

- **Total Nodes**: 117 (92 original + 25 new)
- **Total Connections**: 96 (72 original + 24 new)
- **New Flows**: 3 (Rich Links, Documents, Summary)
- **New Router Routes**: 6 (continue_yes, continue_no, photo_yes, photo_no, learn_more_yes, learn_more_no)

## Complete Flow Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                         TIER 1: Core Flow                            │
│                      (Previously Implemented)                        │
└─────────────────────────────────────────────────────────────────────┘
                                  │
                Welcome → Form → Name Flow → Guitar List
                                  │
                            AR Flow → Apple Pay
                                  │
                      AHF2 - Schedule Lesson Intro
                                  │
                      AHF3 - Request Location
                                  │
                      Set State: location_requested
                                  │
                         [User inputs location]
                                  │
                      AHG1 - Parse Location
                                  │
                      AHG1 - Time Picker Intro
                                  │
                      AMB Time Picker (Template ID 5)
                                  │
                      Set State: time_confirmed
                                  │
                      Confirm Appointment
                                  │
                      AHH2 - Lesson Confirmation
                                  │
                      AHH2 - Continue Question
                                  │
                  AHH2 - Continue Quick Reply (Yes/No)
                                  │
                  Set State: continue_asked
                                  │
┌─────────────────────────────────────────────────────────────────────┐
│                     TIER 2: Extended Features                        │
│                         (Newly Added)                                │
└─────────────────────────────────────────────────────────────────────┘
                                  │
                      Is Continue Response?
                                  │
                    ┌─────────────┴─────────────┐
                    ↓                           ↓
              Continue Yes                 Continue No
                    │                           │
            AHI1 - Continue Yes?                │
                    │                           │
        ┌───────────┴───────────┐              │
        ↓                       ↓              │
  [Continue: Yes]         [Continue: No]       │
        │                       │              │
        ↓                       └──────┬───────┘
        │                              │
┌──────────────────────────────────────────────────────────────┐
│                   Tier 2.1: Rich Links Flow                   │
│                   (AHI2, AHI3, AHI4)                          │
└──────────────────────────────────────────────────────────────┘
        │
        ↓
  AHI2 - Transition Message
        "There's so much more you can do like sharing beautiful links..."
        │
        ↓
  AHI2 - Rich Link (Apple Docs)
        Template ID: 7
        URL: https://register.apple.com/resources/messages/messaging-documentation/
        Title: "Apple Messages for Business"
        │
        ↓
  AHI3 - Photo Transition
        "Earlier we sent you a photo."
        │
        ↓
  AHI4 - Ask for Photo
        "{{name}}, will you share a picture of your favorite food?"
        │
        ↓
  AHI4 - Photo Quick Reply
        Template ID: 3
        Options: [photo_yes: "Yes, I'll share", photo_no: "No, thanks"]
        │
        ↓
  Set State: photo_asked
        │
        ↓
        │
┌──────────────────────────────────────────────────────────────┐
│                  Tier 2.2: Documents Flow                     │
│                  (AHJ1, AHJ2, AHJ3, AHJ4)                     │
└──────────────────────────────────────────────────────────────┘
        │
        ↓
  Is Photo Response?
        │
    ┌───┴───┐
    ↓       ↓
Photo Yes  Photo No
    │       │
    ↓       ↓
AHJ1 - Wait  AHJ1 - Send Anytime
"Awesome!"   "Or... just send a photo anytime"
    │       │
    └───┬───┘
        ↓
  AHJ2 - Documents Intro
        "In Business Chat, we can also share documents..."
        │
        ↓
  AHJ2 - Send Numbers File
        Template ID: 8
        File: metrics.numbers
        │
        ↓
  AHJ3 - Send PDF
        Template ID: 9
        File: document.pdf
        │
        ↓
  AHJ4 - Learn More Question
        "{{name}}, would you like to learn more about Business Chat?"
        │
        ↓
  AHJ4 - Learn More Quick Reply
        Template ID: 3
        Options: [learn_more_yes: "Yes, tell me more", learn_more_no: "No, thanks"]
        │
        ↓
  Set State: learn_more_asked
        │
        ↓
        │
┌──────────────────────────────────────────────────────────────┐
│                 Tier 2.3: Summary & Wrap-up                   │
│                 (AHK1, AHK2, AHK3)                            │
└──────────────────────────────────────────────────────────────┘
        │
        ↓
  Is Summary Route?
        (Learn More Yes/No OR Continue No)
        │
        ↓
  AHK1 - Summary Intro
        "We've thrown a handful of Messages features at you today..."
        │
        ↓
  AHK1 - Summary List Picker
        Template ID: 10
        13 Features with Images:
        - List Picker
        - Time Picker
        - Forms
        - Apple Pay
        - Rich Links
        - Quick Replies
        - Photos
        - Documents
        - Authentication
        - Location
        - AR
        - Custom Attributes
        - Conversations
        │
        ↓
  AHK2 - Register Site Intro
        "A great first step will be to visit our Register site..."
        │
        ↓
  AHK3 - Register Rich Link
        Template ID: 7
        URL: https://register.apple.com/business-chat
        Title: "Apple Messages for Business"
        │
        ↓
  AHK3 - Final Message
        "We will get back to you soon 😀"
        │
        ↓
  Set State: flow_complete
        │
        ↓
      [END]
```

## Node Details

### Tier 2.1: Rich Links Flow (6 nodes)

| Node ID | Name | Type | Purpose |
|---------|------|------|---------|
| `check-continue-response` | Is Continue Response? | If (condition check) | Route handler for continue question |
| `ahi1-continue-yes` | AHI1 - Continue Yes? | If (condition check) | Branch for continue decision |
| `ahi2-transition-message` | AHI2 - Transition Message | HTTP Request | Introduce rich links feature |
| `ahi2-rich-link` | AHI2 - Rich Link (Apple Docs) | Custom AMB Rich Link | Send Apple documentation rich link |
| `ahi3-photo-transition` | AHI3 - Photo Transition | HTTP Request | Transition to photo sharing |
| `ahi4-ask-photo` | AHI4 - Ask for Photo | HTTP Request | Ask user to share photo |
| `ahi4-photo-quick-reply` | AHI4 - Photo Quick Reply | Custom AMB Quick Reply | Yes/No quick reply for photo |
| `set-state-photo-asked` | Set State: photo_asked | HTTP Request | Update bot state |

### Tier 2.2: Documents Flow (10 nodes)

| Node ID | Name | Type | Purpose |
|---------|------|------|---------|
| `check-photo-response` | Is Photo Response? | If (condition check) | Route handler for photo question |
| `ahj1-photo-yes` | AHJ1 - Photo Yes? | If (condition check) | Branch for photo decision |
| `ahj1-photo-wait` | AHJ1 - Wait for Photo | HTTP Request | Acknowledge waiting for photo |
| `ahj1-photo-anytime` | AHJ1 - Send Anytime | HTTP Request | Alternative message for no photo |
| `ahj2-documents-intro` | AHJ2 - Documents Intro | HTTP Request | Introduce documents feature |
| `ahj2-send-numbers` | AHJ2 - Send Numbers File | Custom AMB Template | Send metrics.numbers file |
| `ahj3-send-pdf` | AHJ3 - Send PDF | Custom AMB Template | Send document.pdf file |
| `ahj4-learn-more-question` | AHJ4 - Learn More Question | HTTP Request | Ask about learning more |
| `ahj4-learn-more-quick-reply` | AHJ4 - Learn More Quick Reply | Custom AMB Quick Reply | Yes/No quick reply for learn more |
| `set-state-learn-more-asked` | Set State: learn_more_asked | HTTP Request | Update bot state |

### Tier 2.3: Summary & Wrap-up (9 nodes)

| Node ID | Name | Type | Purpose |
|---------|------|------|---------|
| `check-summary-route` | Is Summary Route? | If (condition check) | Route handler for summary flow |
| `ahk1-summary-intro` | AHK1 - Summary Intro | HTTP Request | Introduce summary |
| `ahk1-summary-list-picker` | AHK1 - Summary List Picker | Custom AMB List Picker | Display all 13 features |
| `ahk2-register-intro` | AHK2 - Register Site Intro | HTTP Request | Introduce register site |
| `ahk3-register-rich-link` | AHK3 - Register Rich Link | Custom AMB Rich Link | Send register.apple.com link |
| `ahk3-final-message` | AHK3 - Final Message | HTTP Request | Final goodbye message |
| `set-state-flow-complete` | Set State: flow_complete | HTTP Request | Mark flow as complete |

## Router Updates

### New Routes Added

```javascript
// Continue question routing
else if (reply === 'continue_yes' || reply === 'continue_no') {
  if (customAttrs.bot_state === 'continue_asked') {
    route = reply === 'continue_yes' ? 'CONTINUE_YES' : 'CONTINUE_NO';
    nextState = reply === 'continue_yes' ? 'rich_links_start' : 'summary_start';
  }
}

// Photo question routing
else if (reply === 'photo_yes' || reply === 'photo_no') {
  if (customAttrs.bot_state === 'photo_asked') {
    route = reply === 'photo_yes' ? 'PHOTO_YES' : 'PHOTO_NO';
    nextState = reply === 'photo_yes' ? 'waiting_photo' : 'documents_start';
  }
}

// Learn more question routing
else if (reply === 'learn_more_yes' || reply === 'learn_more_no') {
  if (customAttrs.bot_state === 'learn_more_asked') {
    route = reply === 'learn_more_yes' ? 'LEARN_MORE_YES' : 'LEARN_MORE_NO';
    nextState = 'summary_start';
  }
}
```

### New Boolean Flags

- `isContinueYes`: True when user selects "continue_yes"
- `isContinueNo`: True when user selects "continue_no"
- `isPhotoYes`: True when user selects "photo_yes"
- `isPhotoNo`: True when user selects "photo_no"
- `isLearnMoreYes`: True when user selects "learn_more_yes"
- `isLearnMoreNo`: True when user selects "learn_more_no"

## Templates Required

The following templates need to be created in Chatwoot:

### Template ID 7: Rich Link
```json
{
  "type": "rich_link",
  "url": "https://register.apple.com/resources/messages/messaging-documentation/",
  "title": "Apple Messages for Business",
  "subtitle": "Learn about Business Chat features and capabilities",
  "image_url": "https://developer.apple.com/assets/elements/icons/messages-for-business/messages-for-business-96x96_2x.png"
}
```

### Template ID 8: Numbers File (metrics.numbers)
```json
{
  "type": "file",
  "file_name": "metrics.numbers",
  "file_type": "application/vnd.apple.numbers",
  "file_url": "[URL to metrics.numbers file]"
}
```

### Template ID 9: PDF File (document.pdf)
```json
{
  "type": "file",
  "file_name": "document.pdf",
  "file_type": "application/pdf",
  "file_url": "[URL to document.pdf file]"
}
```

### Template ID 10: Summary List Picker
```json
{
  "type": "list_picker",
  "title": "Apple Messages for Business Features",
  "sections": [
    {
      "title": "Interactive Features",
      "multiple_selection": false,
      "items": [
        {
          "identifier": "summary_list_picker",
          "title": "List Picker",
          "subtitle": "Browse products and options",
          "image_identifier": "list_picker_img",
          "style": "large"
        },
        {
          "identifier": "summary_time_picker",
          "title": "Time Picker",
          "subtitle": "Schedule appointments",
          "image_identifier": "time_picker_img",
          "style": "large"
        },
        {
          "identifier": "summary_forms",
          "title": "Forms",
          "subtitle": "Collect customer information",
          "image_identifier": "forms_img",
          "style": "large"
        },
        {
          "identifier": "summary_apple_pay",
          "title": "Apple Pay",
          "subtitle": "Secure payments",
          "image_identifier": "apple_pay_img",
          "style": "large"
        },
        {
          "identifier": "summary_rich_links",
          "title": "Rich Links",
          "subtitle": "Beautiful link previews",
          "image_identifier": "rich_links_img",
          "style": "large"
        },
        {
          "identifier": "summary_quick_replies",
          "title": "Quick Replies",
          "subtitle": "One-tap responses",
          "image_identifier": "quick_replies_img",
          "style": "large"
        },
        {
          "identifier": "summary_photos",
          "title": "Photos",
          "subtitle": "Share images",
          "image_identifier": "photos_img",
          "style": "large"
        },
        {
          "identifier": "summary_documents",
          "title": "Documents",
          "subtitle": "Share files",
          "image_identifier": "documents_img",
          "style": "large"
        },
        {
          "identifier": "summary_auth",
          "title": "Authentication",
          "subtitle": "OAuth integration",
          "image_identifier": "auth_img",
          "style": "large"
        },
        {
          "identifier": "summary_location",
          "title": "Location",
          "subtitle": "Share locations",
          "image_identifier": "location_img",
          "style": "large"
        },
        {
          "identifier": "summary_ar",
          "title": "AR Quick Look",
          "subtitle": "3D product views",
          "image_identifier": "ar_img",
          "style": "large"
        },
        {
          "identifier": "summary_custom_attrs",
          "title": "Custom Attributes",
          "subtitle": "Personalization",
          "image_identifier": "custom_attrs_img",
          "style": "large"
        },
        {
          "identifier": "summary_conversations",
          "title": "Conversations",
          "subtitle": "Rich messaging",
          "image_identifier": "conversations_img",
          "style": "large"
        }
      ]
    }
  ],
  "images": [
    {"identifier": "list_picker_img", "data": "[base64]"},
    {"identifier": "time_picker_img", "data": "[base64]"},
    {"identifier": "forms_img", "data": "[base64]"},
    {"identifier": "apple_pay_img", "data": "[base64]"},
    {"identifier": "rich_links_img", "data": "[base64]"},
    {"identifier": "quick_replies_img", "data": "[base64]"},
    {"identifier": "photos_img", "data": "[base64]"},
    {"identifier": "documents_img", "data": "[base64]"},
    {"identifier": "auth_img", "data": "[base64]"},
    {"identifier": "location_img", "data": "[base64]"},
    {"identifier": "ar_img", "data": "[base64]"},
    {"identifier": "custom_attrs_img", "data": "[base64]"},
    {"identifier": "conversations_img", "data": "[base64]"}
  ]
}
```

## Bot States

### New States Added

- `continue_asked`: After asking "Shall we continue?"
- `rich_links_start`: Start of rich links flow
- `photo_asked`: After asking "Will you share a picture?"
- `waiting_photo`: Waiting for user to upload photo
- `documents_start`: Start of documents flow
- `learn_more_asked`: After asking "Learn more about Business Chat?"
- `summary_start`: Start of summary flow
- `flow_complete`: Flow completed successfully

## Testing Checklist

- [ ] Import JSON into n8n successfully
- [ ] Verify all nodes are connected correctly
- [ ] Create Template ID 7 (Rich Link)
- [ ] Create Template ID 8 (Numbers file)
- [ ] Create Template ID 9 (PDF file)
- [ ] Create Template ID 10 (Summary List Picker with 13 features)
- [ ] Test Continue Yes path → Rich Links flow
- [ ] Test Continue No path → Skip to Summary
- [ ] Test Photo Yes path → Wait for photo
- [ ] Test Photo No path → Documents flow
- [ ] Test Learn More Yes path → Summary
- [ ] Test Learn More No path → Summary
- [ ] Verify all bot states are set correctly
- [ ] Verify Final Message and flow_complete state

## Next Steps

1. Import `Acoustic-House-Bot-WITH-TIER2.json` into n8n
2. Create the 4 required templates (IDs 7, 8, 9, 10)
3. Test each flow path
4. Document any issues or adjustments needed
5. Deploy to production when testing is complete

## File Locations

- **Generated JSON**: `/Users/rhaps/LocalGit/chatwoot/n8n-flows/Acoustic-House-Bot-WITH-TIER2.json`
- **Implementation Script**: `/Users/rhaps/LocalGit/chatwoot/n8n-flows/add_tier2_flows.py`
- **Implementation Tracking**: `/Users/rhaps/LocalGit/chatwoot/n8n-flows/Acoustic-House-Bot-TIER2-IMPLEMENTATION.md`
- **This Flow Diagram**: `/Users/rhaps/LocalGit/chatwoot/n8n-flows/Acoustic-House-Bot-TIER2-FLOW-DIAGRAM.md`
