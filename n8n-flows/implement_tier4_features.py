#!/usr/bin/env python3
"""
Implement Tier 4 Advanced Features in Acoustic House Bot n8n workflow.

This script adds:
- State catchers (AHC1, AHF1, AHH1) with retry logic
- Authentication flow placeholders
- Store locator system (simplified)
- Rich link features
- Special integrations placeholders
"""

import json
import sys
from pathlib import Path

def load_workflow(file_path):
    """Load the n8n workflow JSON."""
    with open(file_path, 'r') as f:
        return json.load(f)

def save_workflow(workflow, file_path):
    """Save the n8n workflow JSON."""
    with open(file_path, 'w') as f:
        json.dump(workflow, f, indent=2)

def create_state_catcher_nodes():
    """Create nodes for state catchers (AHC1, AHF1, AHH1)."""
    nodes = []

    # AHC1 - Guitar Picker Catcher
    nodes.append({
        "parameters": {
            "jsCode": """// AHC1 - Guitar Picker Catcher
const data = $json.body || $json;
const conversation = data.conversation || {};
const customAttrs = conversation.custom_attributes || {};
const botState = customAttrs.bot_state || '';
const retryCount = customAttrs.retry_count || 0;

// Check if we're in guitar_list state and user hasn't responded
const isGuitarState = botState === 'guitar_list';
const conversationId = conversation.id;
const accountId = data.account?.id || 1;

return {
  json: {
    isGuitarState: isGuitarState,
    retryCount: retryCount,
    conversationId: conversationId,
    accountId: accountId,
    shouldPrompt: retryCount === 2,
    shouldResend: retryCount === 3,
    shouldAutoSelect: retryCount >= 5
  }
};"""
        },
        "type": "n8n-nodes-base.code",
        "typeVersion": 2,
        "position": [3800, -200],
        "id": "ahc1-guitar-catcher",
        "name": "AHC1 - Guitar Picker Catcher"
    })

    # AHC1 - Increment Retry Count
    nodes.append({
        "parameters": {
            "method": "POST",
            "url": "=https://app.chatwoot.com/api/v1/accounts/{{ $json.accountId }}/conversations/{{ $json.conversationId }}/custom_attributes",
            "authentication": "genericCredentialType",
            "genericAuthType": "httpHeaderAuth",
            "sendBody": True,
            "bodyParameters": {
                "parameters": [
                    {
                        "name": "custom_attributes[retry_count]",
                        "value": "={{ $json.retryCount + 1 }}"
                    }
                ]
            }
        },
        "type": "n8n-nodes-base.httpRequest",
        "typeVersion": 4.3,
        "position": [4000, -200],
        "id": "ahc1-increment-retry",
        "name": "AHC1 - Increment Retry Count"
    })

    # AHC1 - Retry Router (Switch)
    nodes.append({
        "parameters": {
            "conditions": {
                "options": {
                    "caseSensitive": False,
                    "leftValue": "",
                    "typeValidation": "strict"
                },
                "conditions": [
                    {
                        "leftValue": "={{ $json.shouldPrompt }}",
                        "rightValue": True,
                        "operator": {"type": "boolean", "operation": "equals"}
                    }
                ],
                "combinator": "and"
            }
        },
        "type": "n8n-nodes-base.if",
        "typeVersion": 2.2,
        "position": [4200, -300],
        "id": "ahc1-should-prompt",
        "name": "AHC1 - Should Prompt?"
    })

    # AHC1 - Send Prompt (Count = 2)
    nodes.append({
        "parameters": {
            "method": "POST",
            "url": "=https://app.chatwoot.com/api/v1/accounts/{{ $json.accountId }}/conversations/{{ $json.conversationId }}/messages",
            "authentication": "genericCredentialType",
            "genericAuthType": "httpHeaderAuth",
            "sendBody": True,
            "bodyParameters": {
                "parameters": [
                    {
                        "name": "content",
                        "value": "Looks like we're waiting for you to select a guitar from the list above. Take your time! 🎸"
                    },
                    {
                        "name": "message_type",
                        "value": "outgoing"
                    }
                ]
            }
        },
        "type": "n8n-nodes-base.httpRequest",
        "typeVersion": 4.3,
        "position": [4400, -400],
        "id": "ahc1-send-prompt",
        "name": "AHC1 - Send Prompt"
    })

    # AHC1 - Should Resend?
    nodes.append({
        "parameters": {
            "conditions": {
                "options": {
                    "caseSensitive": False,
                    "leftValue": "",
                    "typeValidation": "strict"
                },
                "conditions": [
                    {
                        "leftValue": "={{ $json.shouldResend }}",
                        "rightValue": True,
                        "operator": {"type": "boolean", "operation": "equals"}
                    }
                ],
                "combinator": "and"
            }
        },
        "type": "n8n-nodes-base.if",
        "typeVersion": 2.2,
        "position": [4200, -200],
        "id": "ahc1-should-resend",
        "name": "AHC1 - Should Resend?"
    })

    # AHC1 - Resend Guitar List (Count = 3)
    nodes.append({
        "parameters": {
            "accountId": "={{ $json.accountId }}",
            "conversationId": "={{ $json.conversationId }}",
            "templateId": 329
        },
        "type": "CUSTOM.chatwootAMBListPicker",
        "typeVersion": 1,
        "position": [4400, -300],
        "id": "ahc1-resend-guitar-list",
        "name": "AHC1 - Resend Guitar List",
        "credentials": {
            "chatwootBotApi": {
                "id": "1",
                "name": "Chatwoot Bot API"
            }
        }
    })

    # AHC1 - Should Auto-Select?
    nodes.append({
        "parameters": {
            "conditions": {
                "options": {
                    "caseSensitive": False,
                    "leftValue": "",
                    "typeValidation": "strict"
                },
                "conditions": [
                    {
                        "leftValue": "={{ $json.shouldAutoSelect }}",
                        "rightValue": True,
                        "operator": {"type": "boolean", "operation": "equals"}
                    }
                ],
                "combinator": "and"
            }
        },
        "type": "n8n-nodes-base.if",
        "typeVersion": 2.2,
        "position": [4200, -100],
        "id": "ahc1-should-auto-select",
        "name": "AHC1 - Should Auto-Select?"
    })

    # AHC1 - Auto-Select Message (Count >= 5)
    nodes.append({
        "parameters": {
            "method": "POST",
            "url": "=https://app.chatwoot.com/api/v1/accounts/{{ $json.accountId }}/conversations/{{ $json.conversationId }}/messages",
            "authentication": "genericCredentialType",
            "genericAuthType": "httpHeaderAuth",
            "sendBody": True,
            "bodyParameters": {
                "parameters": [
                    {
                        "name": "content",
                        "value": "Okay, we'll just pretend you selected the Martin DC28E Dreadnought - it's a great choice! Let's continue..."
                    },
                    {
                        "name": "message_type",
                        "value": "outgoing"
                    }
                ]
            }
        },
        "type": "n8n-nodes-base.httpRequest",
        "typeVersion": 4.3,
        "position": [4400, -200],
        "id": "ahc1-auto-select-message",
        "name": "AHC1 - Auto-Select Message"
    })

    # AHC1 - Auto-Select Guitar Image
    nodes.append({
        "parameters": {
            "accountId": "={{ $json.accountId }}",
            "conversationId": "={{ $json.conversationId }}",
            "templateId": 344
        },
        "type": "CUSTOM.chatwootAMBTemplateMessage",
        "typeVersion": 1,
        "position": [4600, -200],
        "id": "ahc1-auto-select-image",
        "name": "AHC1 - Auto-Select Guitar Image",
        "credentials": {
            "chatwootBotApi": {
                "id": "1",
                "name": "Chatwoot Bot API"
            }
        }
    })

    # AHF1 - Apple Pay Catcher
    nodes.append({
        "parameters": {
            "jsCode": """// AHF1 - Apple Pay Catcher
const data = $json.body || $json;
const conversation = data.conversation || {};
const customAttrs = conversation.custom_attributes || {};
const botState = customAttrs.bot_state || '';
const retryCount = customAttrs.retry_count || 0;
const userName = customAttrs.selected_name || customAttrs.user_name || 'there';

// Check if we're in payment_request state
const isPaymentState = botState === 'payment_request';
const conversationId = conversation.id;
const accountId = data.account?.id || 1;

return {
  json: {
    isPaymentState: isPaymentState,
    retryCount: retryCount,
    conversationId: conversationId,
    accountId: accountId,
    userName: userName,
    shouldSkipPayment: retryCount > 2
  }
};"""
        },
        "type": "n8n-nodes-base.code",
        "typeVersion": 2,
        "position": [3800, 0],
        "id": "ahf1-payment-catcher",
        "name": "AHF1 - Apple Pay Catcher"
    })

    # AHF1 - Increment Retry Count
    nodes.append({
        "parameters": {
            "method": "POST",
            "url": "=https://app.chatwoot.com/api/v1/accounts/{{ $json.accountId }}/conversations/{{ $json.conversationId }}/custom_attributes",
            "authentication": "genericCredentialType",
            "genericAuthType": "httpHeaderAuth",
            "sendBody": True,
            "bodyParameters": {
                "parameters": [
                    {
                        "name": "custom_attributes[retry_count]",
                        "value": "={{ $json.retryCount + 1 }}"
                    }
                ]
            }
        },
        "type": "n8n-nodes-base.httpRequest",
        "typeVersion": 4.3,
        "position": [4000, 0],
        "id": "ahf1-increment-retry",
        "name": "AHF1 - Increment Retry Count"
    })

    # AHF1 - Should Skip Payment?
    nodes.append({
        "parameters": {
            "conditions": {
                "options": {
                    "caseSensitive": False,
                    "leftValue": "",
                    "typeValidation": "strict"
                },
                "conditions": [
                    {
                        "leftValue": "={{ $json.shouldSkipPayment }}",
                        "rightValue": True,
                        "operator": {"type": "boolean", "operation": "equals"}
                    }
                ],
                "combinator": "and"
            }
        },
        "type": "n8n-nodes-base.if",
        "typeVersion": 2.2,
        "position": [4200, 0],
        "id": "ahf1-should-skip-payment",
        "name": "AHF1 - Should Skip Payment?"
    })

    # AHF1 - Skip Payment Message
    nodes.append({
        "parameters": {
            "method": "POST",
            "url": "=https://app.chatwoot.com/api/v1/accounts/{{ $json.accountId }}/conversations/{{ $json.conversationId }}/messages",
            "authentication": "genericCredentialType",
            "genericAuthType": "httpHeaderAuth",
            "sendBody": True,
            "bodyParameters": {
                "parameters": [
                    {
                        "name": "content",
                        "value": "=Just kidding {{ $json.userName }}! No payment was processed. This is just a demo. 😊\n\nLet's schedule a lesson with your new guitar instead!"
                    },
                    {
                        "name": "message_type",
                        "value": "outgoing"
                    }
                ]
            }
        },
        "type": "n8n-nodes-base.httpRequest",
        "typeVersion": 4.3,
        "position": [4400, -100],
        "id": "ahf1-skip-payment-message",
        "name": "AHF1 - Skip Payment Message"
    })

    # AHH1 - Time Picker Catcher
    nodes.append({
        "parameters": {
            "jsCode": """// AHH1 - Time Picker Catcher
const data = $json.body || $json;
const conversation = data.conversation || {};
const customAttrs = conversation.custom_attributes || {};
const botState = customAttrs.bot_state || '';
const retryCount = customAttrs.retry_count || 0;

// Check if we're in appointment_booking state
const isTimePickerState = botState === 'appointment_booking';
const conversationId = conversation.id;
const accountId = data.account?.id || 1;

return {
  json: {
    isTimePickerState: isTimePickerState,
    retryCount: retryCount,
    conversationId: conversationId,
    accountId: accountId,
    shouldPrompt: retryCount === 2,
    shouldResend: retryCount === 3,
    shouldSkip: retryCount >= 5
  }
};"""
        },
        "type": "n8n-nodes-base.code",
        "typeVersion": 2,
        "position": [3800, 200],
        "id": "ahh1-time-catcher",
        "name": "AHH1 - Time Picker Catcher"
    })

    # AHH1 - Increment Retry Count
    nodes.append({
        "parameters": {
            "method": "POST",
            "url": "=https://app.chatwoot.com/api/v1/accounts/{{ $json.accountId }}/conversations/{{ $json.conversationId }}/custom_attributes",
            "authentication": "genericCredentialType",
            "genericAuthType": "httpHeaderAuth",
            "sendBody": True,
            "bodyParameters": {
                "parameters": [
                    {
                        "name": "custom_attributes[retry_count]",
                        "value": "={{ $json.retryCount + 1 }}"
                    }
                ]
            }
        },
        "type": "n8n-nodes-base.httpRequest",
        "typeVersion": 4.3,
        "position": [4000, 200],
        "id": "ahh1-increment-retry",
        "name": "AHH1 - Increment Retry Count"
    })

    # AHH1 - Retry Router
    nodes.append({
        "parameters": {
            "conditions": {
                "options": {
                    "caseSensitive": False,
                    "leftValue": "",
                    "typeValidation": "strict"
                },
                "conditions": [
                    {
                        "leftValue": "={{ $json.shouldPrompt }}",
                        "rightValue": True,
                        "operator": {"type": "boolean", "operation": "equals"}
                    }
                ],
                "combinator": "and"
            }
        },
        "type": "n8n-nodes-base.if",
        "typeVersion": 2.2,
        "position": [4200, 100],
        "id": "ahh1-should-prompt",
        "name": "AHH1 - Should Prompt?"
    })

    # AHH1 - Send Prompt
    nodes.append({
        "parameters": {
            "method": "POST",
            "url": "=https://app.chatwoot.com/api/v1/accounts/{{ $json.accountId }}/conversations/{{ $json.conversationId }}/messages",
            "authentication": "genericCredentialType",
            "genericAuthType": "httpHeaderAuth",
            "sendBody": True,
            "bodyParameters": {
                "parameters": [
                    {
                        "name": "content",
                        "value": "Looks like we're waiting for you to select a time for your lesson. No rush! 📅"
                    },
                    {
                        "name": "message_type",
                        "value": "outgoing"
                    }
                ]
            }
        },
        "type": "n8n-nodes-base.httpRequest",
        "typeVersion": 4.3,
        "position": [4400, 0],
        "id": "ahh1-send-prompt",
        "name": "AHH1 - Send Prompt"
    })

    # AHH1 - Should Resend?
    nodes.append({
        "parameters": {
            "conditions": {
                "options": {
                    "caseSensitive": False,
                    "leftValue": "",
                    "typeValidation": "strict"
                },
                "conditions": [
                    {
                        "leftValue": "={{ $json.shouldResend }}",
                        "rightValue": True,
                        "operator": {"type": "boolean", "operation": "equals"}
                    }
                ],
                "combinator": "and"
            }
        },
        "type": "n8n-nodes-base.if",
        "typeVersion": 2.2,
        "position": [4200, 200],
        "id": "ahh1-should-resend",
        "name": "AHH1 - Should Resend?"
    })

    # AHH1 - Resend Time Picker
    nodes.append({
        "parameters": {
            "accountId": "={{ $json.accountId }}",
            "conversationId": "={{ $json.conversationId }}",
            "templateId": 5
        },
        "type": "CUSTOM.chatwootAMBTimePicker",
        "typeVersion": 1,
        "position": [4400, 100],
        "id": "ahh1-resend-time-picker",
        "name": "AHH1 - Resend Time Picker",
        "credentials": {
            "chatwootBotApi": {
                "id": "1",
                "name": "Chatwoot Bot API"
            }
        }
    })

    # AHH1 - Should Skip?
    nodes.append({
        "parameters": {
            "conditions": {
                "options": {
                    "caseSensitive": False,
                    "leftValue": "",
                    "typeValidation": "strict"
                },
                "conditions": [
                    {
                        "leftValue": "={{ $json.shouldSkip }}",
                        "rightValue": True,
                        "operator": {"type": "boolean", "operation": "equals"}
                    }
                ],
                "combinator": "and"
            }
        },
        "type": "n8n-nodes-base.if",
        "typeVersion": 2.2,
        "position": [4200, 300],
        "id": "ahh1-should-skip",
        "name": "AHH1 - Should Skip?"
    })

    # AHH1 - Skip Lesson Message
    nodes.append({
        "parameters": {
            "method": "POST",
            "url": "=https://app.chatwoot.com/api/v1/accounts/{{ $json.accountId }}/conversations/{{ $json.conversationId }}/messages",
            "authentication": "genericCredentialType",
            "genericAuthType": "httpHeaderAuth",
            "sendBody": True,
            "bodyParameters": {
                "parameters": [
                    {
                        "name": "content",
                        "value": "You must be a shredding pro already! 🎸🔥 We can skip the lesson and continue with the demo..."
                    },
                    {
                        "name": "message_type",
                        "value": "outgoing"
                    }
                ]
            }
        },
        "type": "n8n-nodes-base.httpRequest",
        "typeVersion": 4.3,
        "position": [4400, 200],
        "id": "ahh1-skip-lesson-message",
        "name": "AHH1 - Skip Lesson Message"
    })

    return nodes

def create_store_locator_nodes():
    """Create nodes for store locator system."""
    nodes = []

    # Store Locator - Geocoding Placeholder
    nodes.append({
        "parameters": {
            "jsCode": """// Store Locator - Geocoding Placeholder
const input = ($json.rawContent || '').trim();
let coordinates = { lat: 37.7749, lng: -122.4194 }; // SF default

// Hardcoded zipcode mapping
const zipcodeMap = {
  '94102': { lat: 37.7749, lng: -122.4194, city: 'San Francisco' },
  '94103': { lat: 37.7749, lng: -122.4194, city: 'San Francisco' },
  '10001': { lat: 40.7506, lng: -73.9971, city: 'New York' },
  '90210': { lat: 34.0901, lng: -118.4065, city: 'Beverly Hills' },
  '60601': { lat: 41.8858, lng: -87.6229, city: 'Chicago' },
  '98101': { lat: 47.6097, lng: -122.3331, city: 'Seattle' }
};

if (zipcodeMap[input]) {
  coordinates = zipcodeMap[input];
}

// Hardcoded store list (5 nearest)
const stores = [
  {
    identifier: 'store_sf_union',
    title: 'Acoustic House - Union Square',
    subtitle: '300 Post St, San Francisco, CA 94108 (0.8 miles)',
    distance: 0.8
  },
  {
    identifier: 'store_sf_soma',
    title: 'Acoustic House - SOMA',
    subtitle: '123 Townsend St, San Francisco, CA 94107 (1.2 miles)',
    distance: 1.2
  },
  {
    identifier: 'store_sf_marina',
    title: 'Acoustic House - Marina',
    subtitle: '2100 Chestnut St, San Francisco, CA 94123 (2.5 miles)',
    distance: 2.5
  },
  {
    identifier: 'store_sf_mission',
    title: 'Acoustic House - Mission',
    subtitle: '3045 24th St, San Francisco, CA 94110 (3.1 miles)',
    distance: 3.1
  },
  {
    identifier: 'store_oakland',
    title: 'Acoustic House - Oakland',
    subtitle: '1111 Broadway, Oakland, CA 94607 (12.5 miles)',
    distance: 12.5
  }
];

return {
  json: {
    coordinates: coordinates,
    stores: stores,
    conversationId: $json.conversationId,
    accountId: $json.accountId
  }
};"""
        },
        "type": "n8n-nodes-base.code",
        "typeVersion": 2,
        "position": [2400, -200],
        "id": "store-locator-geocode",
        "name": "Store Locator - Geocoding"
    })

    # Store Locator - Build List Picker
    nodes.append({
        "parameters": {
            "accountId": "={{ $json.accountId }}",
            "conversationId": "={{ $json.conversationId }}",
            "templateId": 7,  # New template for stores
            "title": "🏪 Stores Near You",
            "sections": {
                "section": [
                    {
                        "title": "Select a store to book your lesson",
                        "multipleSelection": False,
                        "items": {
                            "item": "={{ $json.stores }}"
                        }
                    }
                ]
            },
            "images": {"image": []},
            "receivedMessage": {},
            "replyMessage": {}
        },
        "type": "CUSTOM.chatwootAMBListPicker",
        "typeVersion": 1,
        "position": [2600, -200],
        "id": "store-locator-list-picker",
        "name": "Store Locator - List Picker",
        "credentials": {
            "chatwootBotApi": {
                "id": "1",
                "name": "Chatwoot Bot API"
            }
        }
    })

    # Store Locator - Parse Selection
    nodes.append({
        "parameters": {
            "jsCode": """// Parse Store Selection
const data = $json.body || $json;
const contentAttrs = data.content_attributes || {};
const interactive = contentAttrs.interactive_data?.data?.['list-picker'] || {};
const selected = interactive.selectedItems?.[0] || {};

const storeIdentifier = selected.identifier || '';
const storeTitle = selected.title || '';

console.log('Store selected:', storeIdentifier, storeTitle);

return {
  json: {
    storeIdentifier: storeIdentifier,
    storeTitle: storeTitle,
    conversationId: data.conversation?.id,
    accountId: data.account?.id || 1
  }
};"""
        },
        "type": "n8n-nodes-base.code",
        "typeVersion": 2,
        "position": [2800, -200],
        "id": "store-locator-parse-selection",
        "name": "Store Locator - Parse Selection"
    })

    # Store Locator - Send Time Picker
    nodes.append({
        "parameters": {
            "accountId": "={{ $json.accountId }}",
            "conversationId": "={{ $json.conversationId }}",
            "templateId": 5
        },
        "type": "CUSTOM.chatwootAMBTimePicker",
        "typeVersion": 1,
        "position": [3000, -200],
        "id": "store-locator-time-picker",
        "name": "Store Locator - Time Picker",
        "credentials": {
            "chatwootBotApi": {
                "id": "1",
                "name": "Chatwoot Bot API"
            }
        }
    })

    return nodes

def create_auth_placeholder_nodes():
    """Create placeholder nodes for authentication."""
    nodes = []

    # Auth - Explanation Message
    nodes.append({
        "parameters": {
            "method": "POST",
            "url": "=https://app.chatwoot.com/api/v1/accounts/{{ $json.accountId }}/conversations/{{ $json.conversationId }}/messages",
            "authentication": "genericCredentialType",
            "genericAuthType": "httpHeaderAuth",
            "sendBody": True,
            "bodyParameters": {
                "parameters": [
                    {
                        "name": "content",
                        "value": "🔐 Authentication Demo\n\nThis feature demonstrates OAuth and authentication capabilities.\n\n⚠️ PLACEHOLDER: Real implementation requires OAuth server setup and Apple Business Chat authentication credentials."
                    },
                    {
                        "name": "message_type",
                        "value": "outgoing"
                    }
                ]
            }
        },
        "type": "n8n-nodes-base.httpRequest",
        "typeVersion": 4.3,
        "position": [4800, -400],
        "id": "auth-explanation",
        "name": "Auth - Explanation Message"
    })

    # Auth - Options List Picker
    nodes.append({
        "parameters": {
            "accountId": "={{ $json.accountId }}",
            "conversationId": "={{ $json.conversationId }}",
            "templateId": 8,  # New template for auth options
            "title": "Authentication Options",
            "sections": {
                "section": [
                    {
                        "title": "Select an authentication method",
                        "multipleSelection": False,
                        "items": {
                            "item": [
                                {
                                    "identifier": "auth_linkedin",
                                    "title": "LinkedIn OAuth",
                                    "subtitle": "Connect with LinkedIn (Placeholder)",
                                    "style": "large"
                                },
                                {
                                    "identifier": "auth_native",
                                    "title": "Native Auth",
                                    "subtitle": "iOS native authentication (Placeholder)",
                                    "style": "large"
                                },
                                {
                                    "identifier": "auth_server_side",
                                    "title": "Server-Side Auth",
                                    "subtitle": "Backend authentication (Placeholder)",
                                    "style": "large"
                                }
                            ]
                        }
                    }
                ]
            },
            "images": {"image": []},
            "receivedMessage": {},
            "replyMessage": {}
        },
        "type": "CUSTOM.chatwootAMBListPicker",
        "typeVersion": 1,
        "position": [5000, -400],
        "id": "auth-options-list",
        "name": "Auth - Options List Picker",
        "credentials": {
            "chatwootBotApi": {
                "id": "1",
                "name": "Chatwoot Bot API"
            }
        }
    })

    # Auth - Parse Selection
    nodes.append({
        "parameters": {
            "jsCode": """// Parse Auth Selection
const data = $json.body || $json;
const contentAttrs = data.content_attributes || {};
const interactive = contentAttrs.interactive_data?.data?.['list-picker'] || {};
const selected = interactive.selectedItems?.[0] || {};

const authType = selected.identifier || '';

let message = '';
if (authType === 'auth_linkedin') {
  message = '✅ LinkedIn OAuth Selected\\n\\nTODO: Setup OAuth app at https://www.linkedin.com/developers/\\n- Implement OAuth callback handler\\n- Exchange for user profile data\\n- Store access tokens securely';
} else if (authType === 'auth_native') {
  message = '✅ Native Auth Selected\\n\\nTODO: Configure Apple Messages for Business native auth\\n- Requires native auth capability\\n- Handle auth tokens in backend\\n- iOS native authentication flow';
} else if (authType === 'auth_server_side') {
  message = '✅ Server-Side Auth Selected\\n\\nTODO: Setup auth server endpoint\\n- Implement token exchange\\n- Store user session data\\n- Provide auth status API';
}

return {
  json: {
    authType: authType,
    message: message,
    conversationId: data.conversation?.id,
    accountId: data.account?.id || 1
  }
};"""
        },
        "type": "n8n-nodes-base.code",
        "typeVersion": 2,
        "position": [5200, -400],
        "id": "auth-parse-selection",
        "name": "Auth - Parse Selection"
    })

    # Auth - Send TODO Message
    nodes.append({
        "parameters": {
            "method": "POST",
            "url": "=https://app.chatwoot.com/api/v1/accounts/{{ $json.accountId }}/conversations/{{ $json.conversationId }}/messages",
            "authentication": "genericCredentialType",
            "genericAuthType": "httpHeaderAuth",
            "sendBody": True,
            "bodyParameters": {
                "parameters": [
                    {
                        "name": "content",
                        "value": "={{ $json.message }}"
                    },
                    {
                        "name": "message_type",
                        "value": "outgoing"
                    }
                ]
            }
        },
        "type": "n8n-nodes-base.httpRequest",
        "typeVersion": 4.3,
        "position": [5400, -400],
        "id": "auth-send-todo",
        "name": "Auth - Send TODO Message"
    })

    return nodes

def create_rich_link_nodes():
    """Create nodes for rich link features."""
    nodes = []

    # Rich Link - Website
    nodes.append({
        "parameters": {
            "method": "POST",
            "url": "=https://app.chatwoot.com/api/v1/accounts/{{ $json.accountId }}/conversations/{{ $json.conversationId }}/messages",
            "authentication": "genericCredentialType",
            "genericAuthType": "httpHeaderAuth",
            "sendBody": True,
            "bodyParameters": {
                "parameters": [
                    {
                        "name": "content",
                        "value": "🔗 Rich Link Demo - Website:\n\nhttps://register.apple.com/resources/messages/\n\n(Rich preview would display here with image, title, description)"
                    },
                    {
                        "name": "message_type",
                        "value": "outgoing"
                    }
                ]
            }
        },
        "type": "n8n-nodes-base.httpRequest",
        "typeVersion": 4.3,
        "position": [4800, -200],
        "id": "rich-link-website",
        "name": "Rich Link - Website"
    })

    # Rich Link - Maps
    nodes.append({
        "parameters": {
            "method": "POST",
            "url": "=https://app.chatwoot.com/api/v1/accounts/{{ $json.accountId }}/conversations/{{ $json.conversationId }}/messages",
            "authentication": "genericCredentialType",
            "genericAuthType": "httpHeaderAuth",
            "sendBody": True,
            "bodyParameters": {
                "parameters": [
                    {
                        "name": "content",
                        "value": "📍 Rich Link Demo - Maps:\n\nhttps://maps.apple.com/?address=300+Post+St,San+Francisco,CA\n\n(Maps preview would display here with location, directions)"
                    },
                    {
                        "name": "message_type",
                        "value": "outgoing"
                    }
                ]
            }
        },
        "type": "n8n-nodes-base.httpRequest",
        "typeVersion": 4.3,
        "position": [5000, -200],
        "id": "rich-link-maps",
        "name": "Rich Link - Maps"
    })

    # Rich Link - App Clip
    nodes.append({
        "parameters": {
            "method": "POST",
            "url": "=https://app.chatwoot.com/api/v1/accounts/{{ $json.accountId }}/conversations/{{ $json.conversationId }}/messages",
            "authentication": "genericCredentialType",
            "genericAuthType": "httpHeaderAuth",
            "sendBody": True,
            "bodyParameters": {
                "parameters": [
                    {
                        "name": "content",
                        "value": "📲 Rich Link Demo - App Clip:\n\nhttps://acoustichouse.example.com/clip\n\n⚠️ PLACEHOLDER: Requires App Clip registration and development\n\nTODO:\n- Register App Clip with Apple\n- Configure invocation URLs\n- Setup App Clip experience\n- Handle universal links"
                    },
                    {
                        "name": "message_type",
                        "value": "outgoing"
                    }
                ]
            }
        },
        "type": "n8n-nodes-base.httpRequest",
        "typeVersion": 4.3,
        "position": [5200, -200],
        "id": "rich-link-app-clip",
        "name": "Rich Link - App Clip"
    })

    # Rich Link - TODO Message
    nodes.append({
        "parameters": {
            "method": "POST",
            "url": "=https://app.chatwoot.com/api/v1/accounts/{{ $json.accountId }}/conversations/{{ $json.conversationId }}/messages",
            "authentication": "genericCredentialType",
            "genericAuthType": "httpHeaderAuth",
            "sendBody": True,
            "bodyParameters": {
                "parameters": [
                    {
                        "name": "content",
                        "value": "📋 Rich Link Implementation TODO:\n\n1. Rich Link Microservice:\n   - Scrape URL metadata (og:title, og:image)\n   - Cache metadata for performance\n   - Serve via API endpoint\n\n2. Media Assets:\n   - Image hosting for hero images\n   - Video support\n   - CDN for performance\n\n3. External Services:\n   - Open Graph scraper\n   - Metadata API\n   - Link preview generator"
                    },
                    {
                        "name": "message_type",
                        "value": "outgoing"
                    }
                ]
            }
        },
        "type": "n8n-nodes-base.httpRequest",
        "typeVersion": 4.3,
        "position": [5400, -200],
        "id": "rich-link-todo",
        "name": "Rich Link - TODO"
    })

    return nodes

def create_special_integration_nodes():
    """Create placeholder nodes for special integrations."""
    nodes = []

    # Shopify Placeholder
    nodes.append({
        "parameters": {
            "method": "POST",
            "url": "=https://app.chatwoot.com/api/v1/accounts/{{ $json.accountId }}/conversations/{{ $json.conversationId }}/messages",
            "authentication": "genericCredentialType",
            "genericAuthType": "httpHeaderAuth",
            "sendBody": True,
            "bodyParameters": {
                "parameters": [
                    {
                        "name": "content",
                        "value": "🛍️ Shopify Integration Demo\n\n⚠️ PLACEHOLDER: Would display product catalog here\n\nTODO:\n- Setup Shopify API credentials\n- Implement product sync\n- Handle cart and checkout\n- Webhook for order updates\n\nExternal Service: Shopify API"
                    },
                    {
                        "name": "message_type",
                        "value": "outgoing"
                    }
                ]
            }
        },
        "type": "n8n-nodes-base.httpRequest",
        "typeVersion": 4.3,
        "position": [4800, 0],
        "id": "shopify-placeholder",
        "name": "Shopify - Placeholder"
    })

    # BIA Placeholder
    nodes.append({
        "parameters": {
            "method": "POST",
            "url": "=https://app.chatwoot.com/api/v1/accounts/{{ $json.accountId }}/conversations/{{ $json.conversationId }}/messages",
            "authentication": "genericCredentialType",
            "genericAuthType": "httpHeaderAuth",
            "sendBody": True,
            "bodyParameters": {
                "parameters": [
                    {
                        "name": "content",
                        "value": "🔐 Business Initiated Auth (BIA) Demo\n\n⚠️ PLACEHOLDER: Would request authentication here\n\nTODO:\n- Register BIA credentials with Apple\n- Setup encryption keys\n- Implement OAuth flow\n- Handle auth responses\n\nExternal Service: Apple BIA Registration"
                    },
                    {
                        "name": "message_type",
                        "value": "outgoing"
                    }
                ]
            }
        },
        "type": "n8n-nodes-base.httpRequest",
        "typeVersion": 4.3,
        "position": [5000, 0],
        "id": "bia-placeholder",
        "name": "BIA - Placeholder"
    })

    # CSAT Survey
    nodes.append({
        "parameters": {
            "method": "POST",
            "url": "=https://app.chatwoot.com/api/v1/accounts/{{ $json.accountId }}/conversations/{{ $json.conversationId }}/messages",
            "authentication": "genericCredentialType",
            "genericAuthType": "httpHeaderAuth",
            "sendBody": True,
            "bodyParameters": {
                "parameters": [
                    {
                        "name": "content",
                        "value": "⭐ How would you rate your experience today?"
                    },
                    {
                        "name": "message_type",
                        "value": "outgoing"
                    }
                ]
            }
        },
        "type": "n8n-nodes-base.httpRequest",
        "typeVersion": 4.3,
        "position": [5200, 0],
        "id": "csat-survey-message",
        "name": "CSAT - Survey Message"
    })

    # CSAT Quick Reply
    nodes.append({
        "parameters": {
            "accountId": "={{ $json.accountId }}",
            "conversationId": "={{ $json.conversationId }}",
            "templateId": 3,
            "summaryText": "Rate your experience:",
            "items": {
                "item": [
                    {"identifier": "csat_5", "title": "⭐⭐⭐⭐⭐ Excellent"},
                    {"identifier": "csat_4", "title": "⭐⭐⭐⭐ Good"},
                    {"identifier": "csat_3", "title": "⭐⭐⭐ Average"},
                    {"identifier": "csat_2", "title": "⭐⭐ Poor"},
                    {"identifier": "csat_1", "title": "⭐ Very Poor"}
                ]
            }
        },
        "type": "CUSTOM.chatwootAMBQuickReply",
        "typeVersion": 1,
        "position": [5400, 0],
        "id": "csat-survey-qr",
        "name": "CSAT - Quick Reply",
        "credentials": {
            "chatwootBotApi": {
                "id": "1",
                "name": "Chatwoot Bot API"
            }
        }
    })

    # iMessage Extension Placeholder
    nodes.append({
        "parameters": {
            "method": "POST",
            "url": "=https://app.chatwoot.com/api/v1/accounts/{{ $json.accountId }}/conversations/{{ $json.conversationId }}/messages",
            "authentication": "genericCredentialType",
            "genericAuthType": "httpHeaderAuth",
            "sendBody": True,
            "bodyParameters": {
                "parameters": [
                    {
                        "name": "content",
                        "value": "📱 iMessage App/Extension Demo\n\n⚠️ PLACEHOLDER: Would trigger iMessage app here\n\nTODO:\n- Develop iMessage app (Xcode)\n- Configure MSP for app bubbles\n- Handle interactive app data\n- Test on iOS devices\n\nExternal Service: iMessage App Development"
                    },
                    {
                        "name": "message_type",
                        "value": "outgoing"
                    }
                ]
            }
        },
        "type": "n8n-nodes-base.httpRequest",
        "typeVersion": 4.3,
        "position": [5600, 0],
        "id": "imessage-extension-placeholder",
        "name": "iMessage Extension - Placeholder"
    })

    return nodes

def update_router_for_tier4(workflow):
    """Update router to handle Tier 4 keywords."""
    router_node = None
    for node in workflow['nodes']:
        if node.get('id') == 'router' or node.get('name') == 'Router with State':
            router_node = node
            break

    if not router_node:
        print("Warning: Router node not found")
        return

    # Add Tier 4 routes to router logic
    router_code = router_node['parameters']['jsCode']

    # Add keywords before the console.log statement
    tier4_keywords = """
// Tier 4: Advanced Features
else if (content === 'authenticate' || content === 'auth' || content === 'oauth') {
  route = 'AUTH';
  nextState = 'auth_prompted';
} else if (content === 'rich link' || content === 'rich links') {
  route = 'RICH_LINK';
  nextState = 'rich_link_shown';
} else if (content === 'shopify') {
  route = 'SHOPIFY';
  nextState = 'shopify_shown';
} else if (content === 'bia' || content === 'business auth') {
  route = 'BIA';
  nextState = 'bia_shown';
} else if (content === 'survey' || content === 'csat') {
  route = 'CSAT';
  nextState = 'csat_shown';
} else if (content === 'imessage' || content === 'imessage app') {
  route = 'IMESSAGE_APP';
  nextState = 'imessage_shown';
}
"""

    # Insert before the final console.log
    router_code = router_code.replace(
        "\nconsole.log('==========================================');",
        tier4_keywords + "\nconsole.log('==========================================');"
    )

    # Add boolean flags for Tier 4
    tier4_flags = """    isAuth: route === 'AUTH',
    isRichLink: route === 'RICH_LINK',
    isShopify: route === 'SHOPIFY',
    isBIA: route === 'BIA',
    isCSAT: route === 'CSAT',
    isIMessageApp: route === 'IMESSAGE_APP',
"""

    router_code = router_code.replace(
        "    isUnknown: route === 'UNKNOWN'",
        tier4_flags + "    isUnknown: route === 'UNKNOWN'"
    )

    router_node['parameters']['jsCode'] = router_code

def main():
    """Main implementation function."""
    input_file = Path(__file__).parent / "Acoustic-House-Bot-MIGRATED.json"
    output_file = Path(__file__).parent / "Acoustic-House-Bot-TIER4.json"

    print("Loading workflow...")
    workflow = load_workflow(input_file)

    print("Creating Tier 4 nodes...")

    # Create all Tier 4 nodes
    tier4_nodes = []
    tier4_nodes.extend(create_state_catcher_nodes())
    tier4_nodes.extend(create_store_locator_nodes())
    tier4_nodes.extend(create_auth_placeholder_nodes())
    tier4_nodes.extend(create_rich_link_nodes())
    tier4_nodes.extend(create_special_integration_nodes())

    print(f"Created {len(tier4_nodes)} new nodes")

    # Add nodes to workflow
    workflow['nodes'].extend(tier4_nodes)

    # Update router
    print("Updating router for Tier 4...")
    update_router_for_tier4(workflow)

    # Save workflow
    print(f"Saving to {output_file}...")
    save_workflow(workflow, output_file)

    print(f"\n✅ SUCCESS!")
    print(f"\nTier 4 Features Added:")
    print(f"  - State Catchers: 18 nodes (AHC1, AHF1, AHH1)")
    print(f"  - Store Locator: 4 nodes")
    print(f"  - Authentication: 4 nodes")
    print(f"  - Rich Links: 4 nodes")
    print(f"  - Special Integrations: 5 nodes")
    print(f"\nTotal New Nodes: {len(tier4_nodes)}")
    print(f"Total Workflow Nodes: {len(workflow['nodes'])}")
    print(f"\nOutput: {output_file}")
    print(f"\nNext Steps:")
    print(f"  1. Import workflow into n8n")
    print(f"  2. Assign credentials to HTTP Request nodes")
    print(f"  3. Test state catchers with retry scenarios")
    print(f"  4. Test store locator with zipcode input")
    print(f"  5. Review placeholder implementations")

if __name__ == '__main__':
    main()
