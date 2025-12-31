#!/usr/bin/env python3
"""
Add Tier 2 flows to the Acoustic House Bot n8n workflow.

This script adds:
- Tier 2.1: Rich Links Flow (AHI2, AHI3, AHI4)
- Tier 2.2: Documents Flow (AHJ1, AHJ2, AHJ3, AHJ4)
- Tier 2.3: Summary & Wrap-up (AHK1, AHK2, AHK3)
"""

import json
import sys
from pathlib import Path

def update_router_code(workflow):
    """Update the Router with State node to handle new routes."""
    router = workflow['nodes'][1]  # Router is second node

    # Updated router code with Tier 2 routing
    router_code = """const data = $json.body || $json;
const content = (data.content || '').toLowerCase().trim();
const messageType = data.message_type;
const event = data.event;
const contentAttrs = data.content_attributes || {};
const conversation = data.conversation || {};
const customAttrs = conversation.custom_attributes || {};

console.log('==========================================');
console.log('Incoming webhook - Content:', content);
console.log('Message Type:', messageType);
console.log('Event:', event);
console.log('Interactive Type:', contentAttrs.interactive_type);
console.log('Bot State:', customAttrs.bot_state);
console.log('==========================================');

// Skip outgoing and updated messages
if (event === 'message_updated' || messageType === 'outgoing') {
  console.log('SKIPPING: outgoing or updated message');
  return { json: { skip: true, reason: 'outgoing_or_updated' } };
}

// Determine route based on content and state
let route = 'UNKNOWN';
let nextState = customAttrs.bot_state || null;

// Handle interactive responses
if (contentAttrs.interactive_type === 'list_picker') {
  const items = contentAttrs.interactive_data?.data?.['list-picker']?.selectedItems || [];
  if (items.length > 0) {
    const id = items[0].identifier;
    console.log('List picker selection:', id);

    if (id === 'main_menu_guitar' || id.includes('guitar')) {
      route = 'GUITAR';
      nextState = 'guitar_selected';
    } else if (id === 'main_menu_appointment' || id === 'book_appointment') {
      route = 'TIME';
      nextState = 'appointment_booking';
    } else if (id === 'main_menu_location' || id.includes('location')) {
      route = 'LOCATION';
      nextState = 'location_request';
    } else if (id === 'main_menu_features' || id.includes('features')) {
      route = 'FEATURES';
      nextState = 'features_shown';
    } else if (id.includes('ar_')) {
      route = 'AR';
      nextState = 'ar_prompt';
    } else if (id.includes('payment')) {
      route = 'PAYMENT';
      nextState = 'payment_request';
    }
  }
}
// Handle time picker responses
else if (contentAttrs.interactive_type === 'time_picker') {
  route = 'CONFIRM';
  nextState = 'appointment_confirmed';
}
// Handle form responses
else if (contentAttrs.interactive_type === 'form') {
  route = 'NAME_COLLECTED';
  nextState = 'name_collected';
}
// Handle quick reply responses
else if (contentAttrs.interactive_type === 'quick_reply') {
  const reply = contentAttrs.interactive_data?.data?.['quick-reply']?.identifier || '';
  console.log('Quick reply selection:', reply);

  if (reply.includes('region_')) {
    route = 'REGION_SELECTED';
    nextState = 'region_selected';
  } else if (reply === 'name_real' || reply === 'name_stage') {
    route = 'NAME_SELECTED';
    nextState = 'name_selected';
  } else if (reply === 'ar_view_yes' || reply === '111') {
    if (customAttrs.bot_state === 'ar_view_asked') {
      route = 'AR_VIEW_YES';
      nextState = 'ar_view_yes';
    } else if (customAttrs.bot_state === 'ar_place_asked') {
      route = 'AR_PLACE_YES';
      nextState = 'ar_place_yes';
    }
  } else if (reply === 'ar_view_no' || reply === '222') {
    if (customAttrs.bot_state === 'ar_view_asked') {
      route = 'AR_VIEW_NO';
      nextState = 'ar_view_no';
    } else if (customAttrs.bot_state === 'ar_place_asked') {
      route = 'AR_PLACE_NO';
      nextState = 'ar_place_no';
    }
  }
  // TIER 2: Continue question handling
  else if (reply === 'continue_yes' || reply === 'continue_no') {
    if (customAttrs.bot_state === 'continue_asked') {
      route = reply === 'continue_yes' ? 'CONTINUE_YES' : 'CONTINUE_NO';
      nextState = reply === 'continue_yes' ? 'rich_links_start' : 'summary_start';
    }
  }
  // TIER 2: Photo question handling
  else if (reply === 'photo_yes' || reply === 'photo_no') {
    if (customAttrs.bot_state === 'photo_asked') {
      route = reply === 'photo_yes' ? 'PHOTO_YES' : 'PHOTO_NO';
      nextState = reply === 'photo_yes' ? 'waiting_photo' : 'documents_start';
    }
  }
  // TIER 2: Learn more question handling
  else if (reply === 'learn_more_yes' || reply === 'learn_more_no') {
    if (customAttrs.bot_state === 'learn_more_asked') {
      route = reply === 'learn_more_yes' ? 'LEARN_MORE_YES' : 'LEARN_MORE_NO';
      nextState = 'summary_start';
    }
  }
}
// Handle keyword triggers
else if (content === 'start' || content === 'hello' || content === 'hi' || content === 'help' || content === 'begin') {
  route = 'WELCOME';
  nextState = 'welcomed';
} else if (content === 'menu' || content === 'main menu') {
  route = 'MENU';
  nextState = 'menu_shown';
} else if (content === 'guitar' || content === 'guitars' || content === 'list picker') {
  route = 'GUITAR';
  nextState = 'guitar_list';
} else if (content === 'time picker' || content === 'appointment' || content === 'time') {
  route = 'TIME';
  nextState = 'appointment_booking';
} else if (content === 'location' || content === 'store' || content === 'stores') {
  route = 'LOCATION';
  nextState = 'location_request';
} else if (content === 'apple pay' || content === 'payment' || content === 'pay') {
  route = 'PAYMENT';
  nextState = 'payment_request';
} else if (content === 'summary' || content === 'features') {
  route = 'FEATURES';
  nextState = 'features_shown';
} else if (content === 'startover' || content === 'start over' || content === 'restart') {
  route = 'RESTART';
  nextState = null;
}

console.log('==========================================');
console.log('ROUTE DECISION:', route);
console.log('NEXT STATE:', nextState);
console.log('==========================================');

return {
  json: {
    skip: false,
    route: route,
    nextState: nextState,
    conversationId: conversation.id,
    accountId: data.account?.id || 1,
    rawContent: content,
    rawEvent: event,
    botState: customAttrs.bot_state,
    // Boolean flags for routing
    isWelcome: route === 'WELCOME',
    isMenu: route === 'MENU',
    isRegionSelected: route === 'REGION_SELECTED',
    isNameCollected: route === 'NAME_COLLECTED',
    isNameSelected: route === 'NAME_SELECTED',
    isGuitar: route === 'GUITAR',
    isARViewYes: route === 'AR_VIEW_YES',
    isARViewNo: route === 'AR_VIEW_NO',
    isARPlaceYes: route === 'AR_PLACE_YES',
    isARPlaceNo: route === 'AR_PLACE_NO',
    isPayment: route === 'PAYMENT',
    isTime: route === 'TIME',
    isConfirm: route === 'CONFIRM',
    isLocation: route === 'LOCATION',
    isFeatures: route === 'FEATURES',
    isRestart: route === 'RESTART',
    isUnknown: route === 'UNKNOWN',
    // TIER 2: New routing flags
    isContinueYes: route === 'CONTINUE_YES',
    isContinueNo: route === 'CONTINUE_NO',
    isPhotoYes: route === 'PHOTO_YES',
    isPhotoNo: route === 'PHOTO_NO',
    isLearnMoreYes: route === 'LEARN_MORE_YES',
    isLearnMoreNo: route === 'LEARN_MORE_NO'
  }
};"""

    router['parameters']['jsCode'] = router_code
    print("✓ Updated router with Tier 2 routing logic")

def add_tier2_nodes(workflow):
    """Add all Tier 2 flow nodes."""
    base_x = 2900
    base_y = -200

    tier2_nodes = [
        # TIER 2.1: Rich Links Flow (AHI2, AHI3, AHI4)
        {
            "parameters": {
                "conditions": {
                    "options": {"caseSensitive": False, "leftValue": "", "typeValidation": "strict"},
                    "conditions": [
                        {"leftValue": "={{ $json.isContinueYes || $json.isContinueNo }}", "rightValue": True,
                         "operator": {"type": "boolean", "operation": "equals"}}
                    ],
                    "combinator": "and"
                }
            },
            "type": "n8n-nodes-base.if",
            "typeVersion": 2.2,
            "position": [base_x, 0],
            "id": "check-continue-response",
            "name": "Is Continue Response?"
        },
        {
            "parameters": {
                "conditions": {
                    "options": {"caseSensitive": False, "leftValue": "", "typeValidation": "strict"},
                    "conditions": [
                        {"leftValue": "={{ $json.isContinueYes }}", "rightValue": True,
                         "operator": {"type": "boolean", "operation": "equals"}}
                    ],
                    "combinator": "and"
                }
            },
            "type": "n8n-nodes-base.if",
            "typeVersion": 2.2,
            "position": [base_x + 200, -100],
            "id": "ahi1-continue-yes",
            "name": "AHI1 - Continue Yes?"
        },
        {
            "parameters": {
                "method": "POST",
                "url": "=https://app.chatwoot.com/api/v1/accounts/{{ $('Router with State').item.json.accountId }}/conversations/{{ $('Router with State').item.json.conversationId }}/messages",
                "authentication": "genericCredentialType",
                "genericAuthType": "httpHeaderAuth",
                "sendBody": True,
                "bodyParameters": {
                    "parameters": [
                        {"name": "content", "value": "There's so much more you can do like sharing beautiful links..."},
                        {"name": "message_type", "value": "outgoing"}
                    ]
                }
            },
            "type": "n8n-nodes-base.httpRequest",
            "typeVersion": 4.3,
            "position": [base_x + 400, -200],
            "id": "ahi2-transition-message",
            "name": "AHI2 - Transition Message"
        },
        {
            "parameters": {
                "accountId": "={{ $('Router with State').item.json.accountId }}",
                "conversationId": "={{ $('Router with State').item.json.conversationId }}",
                "templateId": 7,
                "url": "https://register.apple.com/resources/messages/messaging-documentation/",
                "title": "Apple Messages for Business",
                "subtitle": "Learn about Business Chat features and capabilities",
                "imageUrl": "https://developer.apple.com/assets/elements/icons/messages-for-business/messages-for-business-96x96_2x.png"
            },
            "type": "CUSTOM.chatwootAMBRichLink",
            "typeVersion": 1,
            "position": [base_x + 600, -200],
            "id": "ahi2-rich-link",
            "name": "AHI2 - Rich Link (Apple Docs)",
            "credentials": {"chatwootBotApi": {"id": "1", "name": "Chatwoot Bot API"}}
        },
        {
            "parameters": {
                "method": "POST",
                "url": "=https://app.chatwoot.com/api/v1/accounts/{{ $('Router with State').item.json.accountId }}/conversations/{{ $('Router with State').item.json.conversationId }}/messages",
                "authentication": "genericCredentialType",
                "genericAuthType": "httpHeaderAuth",
                "sendBody": True,
                "bodyParameters": {
                    "parameters": [
                        {"name": "content", "value": "Earlier we sent you a photo."},
                        {"name": "message_type", "value": "outgoing"}
                    ]
                }
            },
            "type": "n8n-nodes-base.httpRequest",
            "typeVersion": 4.3,
            "position": [base_x + 800, -200],
            "id": "ahi3-photo-transition",
            "name": "AHI3 - Photo Transition"
        },
        {
            "parameters": {
                "method": "POST",
                "url": "=https://app.chatwoot.com/api/v1/accounts/{{ $('Router with State').item.json.accountId }}/conversations/{{ $('Router with State').item.json.conversationId }}/messages",
                "authentication": "genericCredentialType",
                "genericAuthType": "httpHeaderAuth",
                "sendBody": True,
                "bodyParameters": {
                    "parameters": [
                        {"name": "content", "value": "={{ $('Router with State').item.json.selectedName || 'Friend' }}, will you share a picture of your favorite food?"},
                        {"name": "message_type", "value": "outgoing"}
                    ]
                }
            },
            "type": "n8n-nodes-base.httpRequest",
            "typeVersion": 4.3,
            "position": [base_x + 1000, -200],
            "id": "ahi4-ask-photo",
            "name": "AHI4 - Ask for Photo"
        },
        {
            "parameters": {
                "accountId": "={{ $('Router with State').item.json.accountId }}",
                "conversationId": "={{ $('Router with State').item.json.conversationId }}",
                "templateId": 3,
                "summaryText": "Will you share a picture?",
                "items": {
                    "item": [
                        {"identifier": "photo_yes", "title": "Yes, I'll share"},
                        {"identifier": "photo_no", "title": "No, thanks"}
                    ]
                }
            },
            "type": "CUSTOM.chatwootAMBQuickReply",
            "typeVersion": 1,
            "position": [base_x + 1200, -200],
            "id": "ahi4-photo-quick-reply",
            "name": "AHI4 - Photo Quick Reply",
            "credentials": {"chatwootBotApi": {"id": "1", "name": "Chatwoot Bot API"}}
        },
        {
            "parameters": {
                "method": "POST",
                "url": "=https://app.chatwoot.com/api/v1/accounts/{{ $('Router with State').item.json.accountId }}/conversations/{{ $('Router with State').item.json.conversationId }}/custom_attributes",
                "authentication": "genericCredentialType",
                "genericAuthType": "httpHeaderAuth",
                "sendBody": True,
                "bodyParameters": {
                    "parameters": [
                        {"name": "custom_attributes", "value": "={{ { bot_state: 'photo_asked' } }}"}
                    ]
                }
            },
            "type": "n8n-nodes-base.httpRequest",
            "typeVersion": 4.3,
            "position": [base_x + 1400, -200],
            "id": "set-state-photo-asked",
            "name": "Set State: photo_asked"
        },
        # TIER 2.2: Documents Flow (AHJ1, AHJ2, AHJ3, AHJ4)
        {
            "parameters": {
                "conditions": {
                    "options": {"caseSensitive": False, "leftValue": "", "typeValidation": "strict"},
                    "conditions": [
                        {"leftValue": "={{ $json.isPhotoYes || $json.isPhotoNo }}", "rightValue": True,
                         "operator": {"type": "boolean", "operation": "equals"}}
                    ],
                    "combinator": "and"
                }
            },
            "type": "n8n-nodes-base.if",
            "typeVersion": 2.2,
            "position": [base_x + 1600, 0],
            "id": "check-photo-response",
            "name": "Is Photo Response?"
        },
        {
            "parameters": {
                "conditions": {
                    "options": {"caseSensitive": False, "leftValue": "", "typeValidation": "strict"},
                    "conditions": [
                        {"leftValue": "={{ $json.isPhotoYes }}", "rightValue": True,
                         "operator": {"type": "boolean", "operation": "equals"}}
                    ],
                    "combinator": "and"
                }
            },
            "type": "n8n-nodes-base.if",
            "typeVersion": 2.2,
            "position": [base_x + 1800, -100],
            "id": "ahj1-photo-yes",
            "name": "AHJ1 - Photo Yes?"
        },
        {
            "parameters": {
                "method": "POST",
                "url": "=https://app.chatwoot.com/api/v1/accounts/{{ $('Router with State').item.json.accountId }}/conversations/{{ $('Router with State').item.json.conversationId }}/messages",
                "authentication": "genericCredentialType",
                "genericAuthType": "httpHeaderAuth",
                "sendBody": True,
                "bodyParameters": {
                    "parameters": [
                        {"name": "content", "value": "Awesome! We will hang tight while you send your fav."},
                        {"name": "message_type", "value": "outgoing"}
                    ]
                }
            },
            "type": "n8n-nodes-base.httpRequest",
            "typeVersion": 4.3,
            "position": [base_x + 2000, -200],
            "id": "ahj1-photo-wait",
            "name": "AHJ1 - Wait for Photo"
        },
        {
            "parameters": {
                "method": "POST",
                "url": "=https://app.chatwoot.com/api/v1/accounts/{{ $('Router with State').item.json.accountId }}/conversations/{{ $('Router with State').item.json.conversationId }}/messages",
                "authentication": "genericCredentialType",
                "genericAuthType": "httpHeaderAuth",
                "sendBody": True,
                "bodyParameters": {
                    "parameters": [
                        {"name": "content", "value": "Or... just send a photo anytime"},
                        {"name": "message_type", "value": "outgoing"}
                    ]
                }
            },
            "type": "n8n-nodes-base.httpRequest",
            "typeVersion": 4.3,
            "position": [base_x + 2000, 0],
            "id": "ahj1-photo-anytime",
            "name": "AHJ1 - Send Anytime"
        },
        {
            "parameters": {
                "method": "POST",
                "url": "=https://app.chatwoot.com/api/v1/accounts/{{ $('Router with State').item.json.accountId }}/conversations/{{ $('Router with State').item.json.conversationId }}/messages",
                "authentication": "genericCredentialType",
                "genericAuthType": "httpHeaderAuth",
                "sendBody": True,
                "bodyParameters": {
                    "parameters": [
                        {"name": "content", "value": "In Business Chat, we can also share documents..."},
                        {"name": "message_type", "value": "outgoing"}
                    ]
                }
            },
            "type": "n8n-nodes-base.httpRequest",
            "typeVersion": 4.3,
            "position": [base_x + 2200, -100],
            "id": "ahj2-documents-intro",
            "name": "AHJ2 - Documents Intro"
        },
        {
            "parameters": {
                "accountId": "={{ $('Router with State').item.json.accountId }}",
                "conversationId": "={{ $('Router with State').item.json.conversationId }}",
                "templateId": 8
            },
            "type": "CUSTOM.chatwootAMBTemplateMessage",
            "typeVersion": 1,
            "position": [base_x + 2400, -100],
            "id": "ahj2-send-numbers",
            "name": "AHJ2 - Send Numbers File",
            "credentials": {"chatwootBotApi": {"id": "1", "name": "Chatwoot Bot API"}}
        },
        {
            "parameters": {
                "accountId": "={{ $('Router with State').item.json.accountId }}",
                "conversationId": "={{ $('Router with State').item.json.conversationId }}",
                "templateId": 9
            },
            "type": "CUSTOM.chatwootAMBTemplateMessage",
            "typeVersion": 1,
            "position": [base_x + 2600, -100],
            "id": "ahj3-send-pdf",
            "name": "AHJ3 - Send PDF",
            "credentials": {"chatwootBotApi": {"id": "1", "name": "Chatwoot Bot API"}}
        },
        {
            "parameters": {
                "method": "POST",
                "url": "=https://app.chatwoot.com/api/v1/accounts/{{ $('Router with State').item.json.accountId }}/conversations/{{ $('Router with State').item.json.conversationId }}/messages",
                "authentication": "genericCredentialType",
                "genericAuthType": "httpHeaderAuth",
                "sendBody": True,
                "bodyParameters": {
                    "parameters": [
                        {"name": "content", "value": "={{ $('Router with State').item.json.selectedName || 'Friend' }}, would you like to learn more about Business Chat?"},
                        {"name": "message_type", "value": "outgoing"}
                    ]
                }
            },
            "type": "n8n-nodes-base.httpRequest",
            "typeVersion": 4.3,
            "position": [base_x + 2800, -100],
            "id": "ahj4-learn-more-question",
            "name": "AHJ4 - Learn More Question"
        },
        {
            "parameters": {
                "accountId": "={{ $('Router with State').item.json.accountId }}",
                "conversationId": "={{ $('Router with State').item.json.conversationId }}",
                "templateId": 3,
                "summaryText": "Would you like to learn more?",
                "items": {
                    "item": [
                        {"identifier": "learn_more_yes", "title": "Yes, tell me more"},
                        {"identifier": "learn_more_no", "title": "No, thanks"}
                    ]
                }
            },
            "type": "CUSTOM.chatwootAMBQuickReply",
            "typeVersion": 1,
            "position": [base_x + 3000, -100],
            "id": "ahj4-learn-more-quick-reply",
            "name": "AHJ4 - Learn More Quick Reply",
            "credentials": {"chatwootBotApi": {"id": "1", "name": "Chatwoot Bot API"}}
        },
        {
            "parameters": {
                "method": "POST",
                "url": "=https://app.chatwoot.com/api/v1/accounts/{{ $('Router with State').item.json.accountId }}/conversations/{{ $('Router with State').item.json.conversationId }}/custom_attributes",
                "authentication": "genericCredentialType",
                "genericAuthType": "httpHeaderAuth",
                "sendBody": True,
                "bodyParameters": {
                    "parameters": [
                        {"name": "custom_attributes", "value": "={{ { bot_state: 'learn_more_asked' } }}"}
                    ]
                }
            },
            "type": "n8n-nodes-base.httpRequest",
            "typeVersion": 4.3,
            "position": [base_x + 3200, -100],
            "id": "set-state-learn-more-asked",
            "name": "Set State: learn_more_asked"
        },
        # TIER 2.3: Summary & Wrap-up (AHK1, AHK2, AHK3)
        {
            "parameters": {
                "conditions": {
                    "options": {"caseSensitive": False, "leftValue": "", "typeValidation": "strict"},
                    "conditions": [
                        {"leftValue": "={{ $json.isLearnMoreYes || $json.isLearnMoreNo || $json.isContinueNo }}", "rightValue": True,
                         "operator": {"type": "boolean", "operation": "equals"}}
                    ],
                    "combinator": "and"
                }
            },
            "type": "n8n-nodes-base.if",
            "typeVersion": 2.2,
            "position": [base_x + 3400, 0],
            "id": "check-summary-route",
            "name": "Is Summary Route?"
        },
        {
            "parameters": {
                "method": "POST",
                "url": "=https://app.chatwoot.com/api/v1/accounts/{{ $('Router with State').item.json.accountId }}/conversations/{{ $('Router with State').item.json.conversationId }}/messages",
                "authentication": "genericCredentialType",
                "genericAuthType": "httpHeaderAuth",
                "sendBody": True,
                "bodyParameters": {
                    "parameters": [
                        {"name": "content", "value": "We've thrown a handful of Messages features at you today..."},
                        {"name": "message_type", "value": "outgoing"}
                    ]
                }
            },
            "type": "n8n-nodes-base.httpRequest",
            "typeVersion": 4.3,
            "position": [base_x + 3600, -100],
            "id": "ahk1-summary-intro",
            "name": "AHK1 - Summary Intro"
        },
        {
            "parameters": {
                "accountId": "={{ $('Router with State').item.json.accountId }}",
                "conversationId": "={{ $('Router with State').item.json.conversationId }}",
                "templateId": 10
            },
            "type": "CUSTOM.chatwootAMBListPicker",
            "typeVersion": 1,
            "position": [base_x + 3800, -100],
            "id": "ahk1-summary-list-picker",
            "name": "AHK1 - Summary List Picker",
            "credentials": {"chatwootBotApi": {"id": "1", "name": "Chatwoot Bot API"}}
        },
        {
            "parameters": {
                "method": "POST",
                "url": "=https://app.chatwoot.com/api/v1/accounts/{{ $('Router with State').item.json.accountId }}/conversations/{{ $('Router with State').item.json.conversationId }}/messages",
                "authentication": "genericCredentialType",
                "genericAuthType": "httpHeaderAuth",
                "sendBody": True,
                "bodyParameters": {
                    "parameters": [
                        {"name": "content", "value": "A great first step will be to visit our Register site..."},
                        {"name": "message_type", "value": "outgoing"}
                    ]
                }
            },
            "type": "n8n-nodes-base.httpRequest",
            "typeVersion": 4.3,
            "position": [base_x + 4000, -100],
            "id": "ahk2-register-intro",
            "name": "AHK2 - Register Site Intro"
        },
        {
            "parameters": {
                "accountId": "={{ $('Router with State').item.json.accountId }}",
                "conversationId": "={{ $('Router with State').item.json.conversationId }}",
                "templateId": 7,
                "url": "https://register.apple.com/business-chat",
                "title": "Apple Messages for Business",
                "subtitle": "Register your business for Messages",
                "imageUrl": "https://developer.apple.com/assets/elements/icons/messages-for-business/messages-for-business-96x96_2x.png"
            },
            "type": "CUSTOM.chatwootAMBRichLink",
            "typeVersion": 1,
            "position": [base_x + 4200, -100],
            "id": "ahk3-register-rich-link",
            "name": "AHK3 - Register Rich Link",
            "credentials": {"chatwootBotApi": {"id": "1", "name": "Chatwoot Bot API"}}
        },
        {
            "parameters": {
                "method": "POST",
                "url": "=https://app.chatwoot.com/api/v1/accounts/{{ $('Router with State').item.json.accountId }}/conversations/{{ $('Router with State').item.json.conversationId }}/messages",
                "authentication": "genericCredentialType",
                "genericAuthType": "httpHeaderAuth",
                "sendBody": True,
                "bodyParameters": {
                    "parameters": [
                        {"name": "content", "value": "We will get back to you soon 😀"},
                        {"name": "message_type", "value": "outgoing"}
                    ]
                }
            },
            "type": "n8n-nodes-base.httpRequest",
            "typeVersion": 4.3,
            "position": [base_x + 4400, -100],
            "id": "ahk3-final-message",
            "name": "AHK3 - Final Message"
        },
        {
            "parameters": {
                "method": "POST",
                "url": "=https://app.chatwoot.com/api/v1/accounts/{{ $('Router with State').item.json.accountId }}/conversations/{{ $('Router with State').item.json.conversationId }}/custom_attributes",
                "authentication": "genericCredentialType",
                "genericAuthType": "httpHeaderAuth",
                "sendBody": True,
                "bodyParameters": {
                    "parameters": [
                        {"name": "custom_attributes", "value": "={{ { bot_state: 'flow_complete' } }}"}
                    ]
                }
            },
            "type": "n8n-nodes-base.httpRequest",
            "typeVersion": 4.3,
            "position": [base_x + 4600, -100],
            "id": "set-state-flow-complete",
            "name": "Set State: flow_complete"
        }
    ]

    # Add all new nodes
    workflow['nodes'].extend(tier2_nodes)
    print(f"✓ Added {len(tier2_nodes)} Tier 2 nodes")

def add_tier2_connections(workflow):
    """Add all connections for Tier 2 flows."""

    # Update existing connections: Connect "Set State: continue_asked" → check-continue-response
    workflow['connections']['Set State: continue_asked'] = {
        "main": [[{"node": "Is Continue Response?", "type": "main", "index": 0}]]
    }

    # Remove the old reference in connections where needed
    # Update Is Confirm? to route to check-continue-response instead
    for i, conn in enumerate(workflow['connections']['Is Confirm?']['main'][1]):
        if conn['node'] == 'Is Continue Response?':
            workflow['connections']['Is Confirm?']['main'][1][i]['node'] = 'check-continue-response'

    # New Tier 2 connections
    tier2_connections = {
        "Is Continue Response?": {
            "main": [
                [{"node": "AHI1 - Continue Yes?", "type": "main", "index": 0}],
                [{"node": "check-summary-route", "type": "main", "index": 0}]  # Route to unknown for now
            ]
        },
        "AHI1 - Continue Yes?": {
            "main": [
                [{"node": "AHI2 - Transition Message", "type": "main", "index": 0}],
                [{"node": "check-summary-route", "type": "main", "index": 0}]  # Continue No → Summary
            ]
        },
        "AHI2 - Transition Message": {
            "main": [[{"node": "AHI2 - Rich Link (Apple Docs)", "type": "main", "index": 0}]]
        },
        "AHI2 - Rich Link (Apple Docs)": {
            "main": [[{"node": "AHI3 - Photo Transition", "type": "main", "index": 0}]]
        },
        "AHI3 - Photo Transition": {
            "main": [[{"node": "AHI4 - Ask for Photo", "type": "main", "index": 0}]]
        },
        "AHI4 - Ask for Photo": {
            "main": [[{"node": "AHI4 - Photo Quick Reply", "type": "main", "index": 0}]]
        },
        "AHI4 - Photo Quick Reply": {
            "main": [[{"node": "Set State: photo_asked", "type": "main", "index": 0}]]
        },
        "Set State: photo_asked": {
            "main": [[{"node": "Is Photo Response?", "type": "main", "index": 0}]]
        },
        "Is Photo Response?": {
            "main": [
                [{"node": "AHJ1 - Photo Yes?", "type": "main", "index": 0}],
                [{"node": "Unknown Route", "type": "main", "index": 0}]
            ]
        },
        "AHJ1 - Photo Yes?": {
            "main": [
                [{"node": "AHJ1 - Wait for Photo", "type": "main", "index": 0}],
                [{"node": "AHJ1 - Send Anytime", "type": "main", "index": 0}]
            ]
        },
        "AHJ1 - Wait for Photo": {
            "main": [[{"node": "AHJ2 - Documents Intro", "type": "main", "index": 0}]]
        },
        "AHJ1 - Send Anytime": {
            "main": [[{"node": "AHJ2 - Documents Intro", "type": "main", "index": 0}]]
        },
        "AHJ2 - Documents Intro": {
            "main": [[{"node": "AHJ2 - Send Numbers File", "type": "main", "index": 0}]]
        },
        "AHJ2 - Send Numbers File": {
            "main": [[{"node": "AHJ3 - Send PDF", "type": "main", "index": 0}]]
        },
        "AHJ3 - Send PDF": {
            "main": [[{"node": "AHJ4 - Learn More Question", "type": "main", "index": 0}]]
        },
        "AHJ4 - Learn More Question": {
            "main": [[{"node": "AHJ4 - Learn More Quick Reply", "type": "main", "index": 0}]]
        },
        "AHJ4 - Learn More Quick Reply": {
            "main": [[{"node": "Set State: learn_more_asked", "type": "main", "index": 0}]]
        },
        "Set State: learn_more_asked": {
            "main": [[{"node": "Is Summary Route?", "type": "main", "index": 0}]]
        },
        "Is Summary Route?": {
            "main": [
                [{"node": "AHK1 - Summary Intro", "type": "main", "index": 0}],
                [{"node": "Unknown Route", "type": "main", "index": 0}]
            ]
        },
        "AHK1 - Summary Intro": {
            "main": [[{"node": "AHK1 - Summary List Picker", "type": "main", "index": 0}]]
        },
        "AHK1 - Summary List Picker": {
            "main": [[{"node": "AHK2 - Register Site Intro", "type": "main", "index": 0}]]
        },
        "AHK2 - Register Site Intro": {
            "main": [[{"node": "AHK3 - Register Rich Link", "type": "main", "index": 0}]]
        },
        "AHK3 - Register Rich Link": {
            "main": [[{"node": "AHK3 - Final Message", "type": "main", "index": 0}]]
        },
        "AHK3 - Final Message": {
            "main": [[{"node": "Set State: flow_complete", "type": "main", "index": 0}]]
        }
    }

    workflow['connections'].update(tier2_connections)
    print(f"✓ Added {len(tier2_connections)} Tier 2 connections")

def main():
    """Main execution function."""
    input_file = Path("Acoustic-House-Bot-MIGRATED.json")
    output_file = Path("Acoustic-House-Bot-WITH-TIER2.json")

    if not input_file.exists():
        print(f"ERROR: {input_file} not found")
        sys.exit(1)

    print(f"Reading {input_file}...")
    with open(input_file, 'r') as f:
        workflow = json.load(f)

    print(f"Original workflow: {len(workflow['nodes'])} nodes, {len(workflow['connections'])} connections")

    # Apply all changes
    update_router_code(workflow)
    add_tier2_nodes(workflow)
    add_tier2_connections(workflow)

    # Write output
    print(f"\nWriting {output_file}...")
    with open(output_file, 'w') as f:
        json.dump(workflow, f, indent=2)

    print(f"\n✅ SUCCESS!")
    print(f"New workflow: {len(workflow['nodes'])} nodes, {len(workflow['connections'])} connections")
    print(f"\nCreated: {output_file}")
    print("\nNext steps:")
    print("1. Import the new JSON into n8n")
    print("2. Verify all connections")
    print("3. Create templates for:")
    print("   - Template ID 7: Rich Link")
    print("   - Template ID 8: Numbers file (metrics.numbers)")
    print("   - Template ID 9: PDF file (document.pdf)")
    print("   - Template ID 10: Summary List Picker with 13 features")

if __name__ == "__main__":
    main()
