# Menu Routing and Text Handler Implementation

## Tier 3.1: Complete Menu Routing (12 Options)

### Python Reference (AH.py lines 300-306)
```python
def requestMenu(usr):
    dbLastMessage(usr.userId, "AHA19")
    menuList = {
        "1.": menu_intent1,       # Intent ID Setup
        "2.": menu_listpicker,    # List Picker (Guitars)
        "3.": menu_AR,            # AR Direct
        "4.": menu_Apple_Pay,     # Apple Pay
        "5.": menu_timePicker,    # Time Picker
        "6.": menu_form,          # Help Me Decide Form
        "7.": menu_image,         # Image/Selfie Request
        "8.": menu_documents,     # Send Documents
        "9.": menu_authenticate,  # Authentication
        "10": menu_imessageapp,   # iMessage App
        "11": menu_wallet,        # Wallet Pass
        "12": menu_location       # Store Locator
    }
```

### Menu Options Implementation

**Template 341** (AMB Main Menu) has 12 items with these identifiers:
1. `menu_intent` - Intent ID Setup
2. `menu_listpicker` - List Picker (Guitars)
3. `menu_ar` - AR Direct
4. `menu_applepay` - Apple Pay
5. `menu_timepicker` - Time Picker
6. `menu_form` - Help Me Decide Form
7. `menu_image` - Image/Selfie Request
8. `menu_documents` - Send Documents
9. `menu_authenticate` - Authentication
10. `menu_imessageapp` - iMessage App
11. `menu_wallet` - Wallet Pass
12. `menu_location` - Store Locator

## Tier 3.2: Text Message Handlers (40+ Keywords)

### Python Reference (AH.py lines 150-200)
```python
messageList = {
    # Start/Welcome
    "hi, i would like to learn more about apple messages for business": fresh_start,
    "send this message to start a conversation with acoustic house": fresh_start,
    "hi, i have a question about this guitar.": fresh_start,

    # High Priority Keywords
    "menu": receivedMenu,
    "startover": receivedStartOver,
    "start over": receivedStartOver,
    "stop": receivedStop,
    "summary": menu_summary,
    "time picker": send_timePicker,
    "timepicker": menu_timePicker,
    "list picker": menu_listpicker,
    "listpicker": menu_listpicker,
    "rich link": richlinkSQA,
    "wallet": menu_wallet,
    "apple pay": menu_Apple_Pay,
    "authenticate": menu_authenticate,
    "authentication": menu_authenticate,
    "location": menu_location,
    "locator": menu_location,

    # Feature Demos
    "airport": menu_airport,
    "content payload": menu_content,
    "survey": send_csat,
    "quick reply": send_qr,

    # Special Features
    "imessageapp": receivediMessageApp,
    "imessageextextension": receivediMessageApp,
    "native auth": send_native_auth,
    "server fail": send_ss_fail,
    "server response": send_ss_response,
    "server unknown": send_ss_unknown,

    # Micro Features
    "micro link": micro_link,
    "micro map": micro_map,
    "micro clip": micro_clip,
    "micro region": micro_region,
    "micro custom": micro_custom,
    "micro auto": micro_automation
}
```

## n8n Implementation Strategy

### 1. Enhanced Router Node

Add to the Router's jsCode:

```javascript
// TIER 3.2: Text Message Handlers (40+ keywords)

// Menu-related keywords
else if (content === 'menu' || content === 'main menu') {
  route = 'MENU';
  nextState = 'menu_shown';
}
else if (content === 'startover' || content === 'start over' || content === 'restart') {
  route = 'RESTART';
  nextState = null;
}
else if (content === 'summary' || content === 'features') {
  route = 'FEATURES';
  nextState = 'features_shown';
}
else if (content === 'stop') {
  route = 'STOP';
  nextState = 'stopped';
}

// Interactive feature keywords
else if (content === 'time picker' || content === 'timepicker') {
  route = 'TIME';
  nextState = 'time_picker_shown';
}
else if (content === 'list picker' || content === 'listpicker' || content === 'guitar' || content === 'guitars') {
  route = 'GUITAR';
  nextState = 'guitar_list_shown';
}
else if (content === 'rich link' || content === 'richlink') {
  route = 'RICH_LINK';
  nextState = 'rich_link_shown';
}
else if (content === 'wallet') {
  route = 'WALLET';
  nextState = 'wallet_shown';
}
else if (content === 'apple pay' || content === 'payment' || content === 'pay') {
  route = 'PAYMENT';
  nextState = 'payment_request';
}
else if (content === 'authenticate' || content === 'authentication') {
  route = 'AUTH';
  nextState = 'auth_requested';
}
else if (content === 'location' || content === 'locator' || content === 'store' || content === 'stores') {
  route = 'LOCATION';
  nextState = 'location_request';
}
else if (content === 'form' || content === 'help me decide') {
  route = 'FORM';
  nextState = 'form_shown';
}
else if (content === 'ar' || content === 'augmented reality') {
  route = 'AR_DIRECT';
  nextState = 'ar_sent';
}

// Special demo keywords
else if (content === 'airport') {
  route = 'AIRPORT';
  nextState = 'airport_shown';
}
else if (content === 'content payload') {
  route = 'CONTENT_PAYLOAD';
  nextState = 'content_shown';
}
else if (content === 'survey' || content === 'csat') {
  route = 'SURVEY';
  nextState = 'survey_shown';
}
else if (content === 'quick reply' || content === 'qr') {
  route = 'QUICK_REPLY';
  nextState = 'qr_shown';
}

// iMessage App keywords
else if (content === 'imessageapp' || content === 'imessage app' || content === 'imessageextension') {
  route = 'IMESSAGE_APP';
  nextState = 'imessage_shown';
}

// Authentication variations
else if (content === 'native auth') {
  route = 'NATIVE_AUTH';
  nextState = 'native_auth_shown';
}
else if (content === 'server fail') {
  route = 'SERVER_FAIL';
  nextState = 'server_fail_shown';
}
else if (content === 'server response') {
  route = 'SERVER_RESPONSE';
  nextState = 'server_response_shown';
}
else if (content === 'server unknown') {
  route = 'SERVER_UNKNOWN';
  nextState = 'server_unknown_shown';
}

// Micro features (advanced)
else if (content === 'micro link') {
  route = 'MICRO_LINK';
  nextState = 'micro_link_shown';
}
else if (content === 'micro map') {
  route = 'MICRO_MAP';
  nextState = 'micro_map_shown';
}
else if (content === 'micro clip') {
  route = 'MICRO_CLIP';
  nextState = 'micro_clip_shown';
}
else if (content === 'micro region') {
  route = 'MICRO_REGION';
  nextState = 'micro_region_shown';
}
else if (content === 'micro custom') {
  route = 'MICRO_CUSTOM';
  nextState = 'micro_custom_shown';
}
else if (content === 'micro auto' || content === 'micro automation') {
  route = 'MICRO_AUTO';
  nextState = 'micro_auto_shown';
}

// Documents
else if (content === 'documents' || content === 'docs') {
  route = 'DOCUMENTS';
  nextState = 'documents_sent';
}

// Image request
else if (content === 'image' || content === 'photo' || content === 'selfie') {
  route = 'IMAGE_REQUEST';
  nextState = 'image_requested';
}
```

### 2. Menu Selection Handler

When list picker selection comes from template 341 (main menu):

```javascript
// Handle main menu selections (template 341)
if (contentAttrs.interactive_type === 'list_picker') {
  const items = contentAttrs.interactive_data?.data?.['list-picker']?.selectedItems || [];
  if (items.length > 0) {
    const id = items[0].identifier;
    console.log('List picker selection:', id);

    // Main menu routing (12 options)
    if (id === 'menu_intent') {
      route = 'INTENT_SETUP';
      nextState = 'intent_asked';
    }
    else if (id === 'menu_listpicker') {
      route = 'GUITAR';
      nextState = 'guitar_list_shown';
    }
    else if (id === 'menu_ar') {
      route = 'AR_DIRECT';
      nextState = 'ar_sent';
    }
    else if (id === 'menu_applepay') {
      route = 'PAYMENT';
      nextState = 'payment_request';
    }
    else if (id === 'menu_timepicker') {
      route = 'TIME';
      nextState = 'time_picker_shown';
    }
    else if (id === 'menu_form') {
      route = 'FORM';
      nextState = 'form_shown';
    }
    else if (id === 'menu_image') {
      route = 'IMAGE_REQUEST';
      nextState = 'image_requested';
    }
    else if (id === 'menu_documents') {
      route = 'DOCUMENTS';
      nextState = 'documents_sent';
    }
    else if (id === 'menu_authenticate') {
      route = 'AUTH';
      nextState = 'auth_requested';
    }
    else if (id === 'menu_imessageapp') {
      route = 'IMESSAGE_APP';
      nextState = 'imessage_shown';
    }
    else if (id === 'menu_wallet') {
      route = 'WALLET';
      nextState = 'wallet_shown';
    }
    else if (id === 'menu_location') {
      route = 'LOCATION';
      nextState = 'location_request';
    }
  }
}
```

### 3. Additional Routing Flags

Add these boolean flags to the router output:

```javascript
return {
  json: {
    // ... existing fields ...

    // Tier 3 new routes
    isIntentSetup: route === 'INTENT_SETUP',
    isARDirect: route === 'AR_DIRECT',
    isForm: route === 'FORM',
    isImageRequest: route === 'IMAGE_REQUEST',
    isDocuments: route === 'DOCUMENTS',
    isAuth: route === 'AUTH',
    isIMESSAGEApp: route === 'IMESSAGE_APP',
    isWallet: route === 'WALLET',
    isRichLink: route === 'RICH_LINK',
    isAirport: route === 'AIRPORT',
    isContentPayload: route === 'CONTENT_PAYLOAD',
    isSurvey: route === 'SURVEY',
    isQuickReply: route === 'QUICK_REPLY',
    isNativeAuth: route === 'NATIVE_AUTH',
    isServerFail: route === 'SERVER_FAIL',
    isServerResponse: route === 'SERVER_RESPONSE',
    isServerUnknown: route === 'SERVER_UNKNOWN',
    isMicroLink: route === 'MICRO_LINK',
    isMicroMap: route === 'MICRO_MAP',
    isMicroClip: route === 'MICRO_CLIP',
    isMicroRegion: route === 'MICRO_REGION',
    isMicroCustom: route === 'MICRO_CUSTOM',
    isMicroAuto: route === 'MICRO_AUTO',
    isStop: route === 'STOP'
  }
};
```

## Implementation Order

### Phase 1: Core Menu Routing (Tier 3.1)
1. Update Router node with menu selection logic
2. Add IF nodes for each of 12 menu options
3. Connect existing features (guitar, time, payment, location)
4. Add placeholder nodes for Tier 4 features

### Phase 2: Text Keyword Handlers (Tier 3.2)
1. Update Router with 40+ keyword detection
2. Add routing for high-priority keywords
3. Create demo/placeholder responses for advanced features
4. Test keyword coverage

### Phase 3: Feature Implementation
1. **Implemented**: Guitar list, Time picker, Apple Pay, Location, Features summary
2. **Add**: Rich link demo, Wallet pass, Form direct, AR direct, Documents
3. **Placeholder**: Authentication, iMessage App, Micro features

## Testing Matrix

| Keyword | Expected Route | Template/Action |
|---------|---------------|-----------------|
| menu | MENU | Template 341 |
| guitar | GUITAR | Template 329 |
| time picker | TIME | Template 5 |
| apple pay | PAYMENT | Template 4 |
| location | LOCATION | HTTP Request |
| summary | FEATURES | Template 6 |
| rich link | RICH_LINK | TBD |
| wallet | WALLET | TBD |
| form | FORM | TBD |
| ar | AR_DIRECT | Template 344 |
| authenticate | AUTH | Placeholder |
| imessage app | IMESSAGE_APP | Placeholder |
| documents | DOCUMENTS | TBD |
| image | IMAGE_REQUEST | HTTP Request |
| stop | STOP | Set flag |

## Next Steps

1. Implement updated Router node code
2. Add routing IF nodes for new features
3. Create feature implementation nodes
4. Add Tier 4 placeholder nodes
5. Test all keyword triggers
6. Document routing diagram
