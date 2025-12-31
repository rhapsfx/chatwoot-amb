#!/usr/bin/env python3
"""
Implement Complete Menu Routing and Text Message Handlers
for Acoustic House Bot n8n Flow

Tier 3.1: Complete Menu Routing (12 options from template 341)
Tier 3.2: Text Message Handlers (40+ keywords)

Reference: AH.py lines 150-200 (messageList), 300-306 (requestMenu)
"""

import json
import sys

def create_enhanced_router_code():
    """Generate the complete enhanced router JavaScript code."""

    return """const data = $json.body || $json;
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

// ============================================================
// TIER 3.1: Handle Main Menu List Picker Selections (12 Options)
// ============================================================
if (contentAttrs.interactive_type === 'list_picker') {
  const items = contentAttrs.interactive_data?.data?.['list-picker']?.selectedItems || [];
  if (items.length > 0) {
    const id = items[0].identifier;
    console.log('List picker selection:', id);

    // Main menu routing (template 341 - 12 options)
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
    // Guitar list selection (existing logic)
    else if (id.includes('guitar_')) {
      route = 'GUITAR_SELECTED';
      nextState = 'guitar_selected';
    }
    // Other existing selections
    else if (id.includes('ar_')) {
      route = 'AR';
      nextState = 'ar_prompt';
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
  route = 'FORM_RESPONSE';
  nextState = 'form_submitted';
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
    }
    else if (customAttrs.bot_state === 'ar_place_asked') {
      route = 'AR_PLACE_YES';
      nextState = 'ar_place_yes';
    }
  } else if (reply === 'ar_view_no' || reply === '222') {
    if (customAttrs.bot_state === 'ar_view_asked') {
      route = 'AR_VIEW_NO';
      nextState = 'ar_view_no';
    }
    else if (customAttrs.bot_state === 'ar_place_asked') {
      route = 'AR_PLACE_NO';
      nextState = 'ar_place_no';
    }
  }
}

// ============================================================
// TIER 3.2: Text Message Keyword Handlers (40+ keywords)
// ============================================================

// Welcome/Start keywords
else if (content === 'start' || content === 'hello' || content === 'hi' || content === 'help' || content === 'begin') {
  route = 'WELCOME';
  nextState = 'welcomed';
}

// Menu and navigation
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

// Interactive features - List Picker
else if (content === 'list picker' || content === 'listpicker' || content === 'guitar' || content === 'guitars') {
  route = 'GUITAR';
  nextState = 'guitar_list_shown';
}

// Interactive features - Time Picker
else if (content === 'time picker' || content === 'timepicker' || content === 'appointment' || content === 'time') {
  route = 'TIME';
  nextState = 'time_picker_shown';
}

// Interactive features - Apple Pay
else if (content === 'apple pay' || content === 'payment' || content === 'pay') {
  route = 'PAYMENT';
  nextState = 'payment_request';
}

// Interactive features - Forms
else if (content === 'form' || content === 'help me decide') {
  route = 'FORM';
  nextState = 'form_shown';
}

// Interactive features - Rich Link
else if (content === 'rich link' || content === 'richlink') {
  route = 'RICH_LINK';
  nextState = 'rich_link_shown';
}

// Interactive features - Quick Reply
else if (content === 'quick reply' || content === 'qr') {
  route = 'QUICK_REPLY';
  nextState = 'qr_shown';
}

// Location/Store features
else if (content === 'location' || content === 'locator' || content === 'store' || content === 'stores') {
  route = 'LOCATION';
  nextState = 'location_request';
}

// AR features
else if (content === 'ar' || content === 'augmented reality') {
  route = 'AR_DIRECT';
  nextState = 'ar_sent';
}

// Wallet features
else if (content === 'wallet') {
  route = 'WALLET';
  nextState = 'wallet_shown';
}

// Authentication features
else if (content === 'authenticate' || content === 'authentication') {
  route = 'AUTH';
  nextState = 'auth_requested';
}
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

// iMessage App features
else if (content === 'imessageapp' || content === 'imessage app' || content === 'imessageextension') {
  route = 'IMESSAGE_APP';
  nextState = 'imessage_shown';
}

// Special demo features
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

// Document features
else if (content === 'documents' || content === 'docs') {
  route = 'DOCUMENTS';
  nextState = 'documents_sent';
}

// Image request
else if (content === 'image' || content === 'photo' || content === 'selfie') {
  route = 'IMAGE_REQUEST';
  nextState = 'image_requested';
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

    // ========== Boolean Routing Flags ==========

    // Core navigation
    isWelcome: route === 'WELCOME',
    isMenu: route === 'MENU',
    isRestart: route === 'RESTART',
    isStop: route === 'STOP',
    isUnknown: route === 'UNKNOWN',

    // Menu selections (Tier 3.1)
    isIntentSetup: route === 'INTENT_SETUP',
    isARDirect: route === 'AR_DIRECT',
    isForm: route === 'FORM',
    isFormResponse: route === 'FORM_RESPONSE',
    isImageRequest: route === 'IMAGE_REQUEST',
    isDocuments: route === 'DOCUMENTS',
    isAuth: route === 'AUTH',
    isIMESSAGEApp: route === 'IMESSAGE_APP',
    isWallet: route === 'WALLET',

    // Interactive features (existing + new)
    isGuitar: route === 'GUITAR',
    isGuitarSelected: route === 'GUITAR_SELECTED',
    isTime: route === 'TIME',
    isConfirm: route === 'CONFIRM',
    isPayment: route === 'PAYMENT',
    isLocation: route === 'LOCATION',
    isFeatures: route === 'FEATURES',
    isRichLink: route === 'RICH_LINK',
    isQuickReply: route === 'QUICK_REPLY',

    // AR flow (existing)
    isARViewYes: route === 'AR_VIEW_YES',
    isARViewNo: route === 'AR_VIEW_NO',
    isARPlaceYes: route === 'AR_PLACE_YES',
    isARPlaceNo: route === 'AR_PLACE_NO',

    // Name collection flow (existing)
    isRegionSelected: route === 'REGION_SELECTED',
    isNameCollected: route === 'NAME_COLLECTED',
    isNameSelected: route === 'NAME_SELECTED',

    // Special demos (Tier 3.2)
    isAirport: route === 'AIRPORT',
    isContentPayload: route === 'CONTENT_PAYLOAD',
    isSurvey: route === 'SURVEY',

    // Authentication variants
    isNativeAuth: route === 'NATIVE_AUTH',
    isServerFail: route === 'SERVER_FAIL',
    isServerResponse: route === 'SERVER_RESPONSE',
    isServerUnknown: route === 'SERVER_UNKNOWN',

    // Micro features (advanced)
    isMicroLink: route === 'MICRO_LINK',
    isMicroMap: route === 'MICRO_MAP',
    isMicroClip: route === 'MICRO_CLIP',
    isMicroRegion: route === 'MICRO_REGION',
    isMicroCustom: route === 'MICRO_CUSTOM',
    isMicroAuto: route === 'MICRO_AUTO'
  }
};"""

def update_router_node(flow_data):
    """Update the Router node with enhanced code."""

    enhanced_code = create_enhanced_router_code()

    # Find and update the Router node
    for node in flow_data['nodes']:
        if node.get('name') == 'Router with State' or node.get('id') == 'router':
            print(f"✓ Updating Router node with enhanced menu routing and keyword handlers")
            node['parameters']['jsCode'] = enhanced_code
            return True

    print("✗ Router node not found")
    return False

def add_new_routing_nodes(flow_data):
    """Add new IF nodes for Tier 3 routes."""

    # Base position for new nodes (after existing check nodes)
    base_x = 3200
    base_y = 0

    new_routes = [
        # Menu-triggered routes
        ('check-intent-setup', 'Is Intent Setup?', 'isIntentSetup'),
        ('check-ar-direct', 'Is AR Direct?', 'isARDirect'),
        ('check-form', 'Is Form?', 'isForm'),
        ('check-form-response', 'Is Form Response?', 'isFormResponse'),
        ('check-image-request', 'Is Image Request?', 'isImageRequest'),
        ('check-documents', 'Is Documents?', 'isDocuments'),
        ('check-auth', 'Is Auth?', 'isAuth'),
        ('check-imessage-app', 'Is iMessage App?', 'isIMESSAGEApp'),
        ('check-wallet', 'Is Wallet?', 'isWallet'),
        ('check-rich-link', 'Is Rich Link?', 'isRichLink'),

        # Special demos
        ('check-airport', 'Is Airport?', 'isAirport'),
        ('check-survey', 'Is Survey?', 'isSurvey'),
        ('check-quick-reply', 'Is Quick Reply?', 'isQuickReply'),
    ]

    existing_node_ids = {node['id'] for node in flow_data['nodes']}
    nodes_added = []

    for i, (node_id, node_name, flag) in enumerate(new_routes):
        if node_id not in existing_node_ids:
            new_node = {
                "parameters": {
                    "conditions": {
                        "options": {
                            "caseSensitive": False,
                            "leftValue": "",
                            "typeValidation": "strict"
                        },
                        "conditions": [
                            {
                                "leftValue": f"={{{{ $json.{flag} }}}}",
                                "rightValue": True,
                                "operator": {
                                    "type": "boolean",
                                    "operation": "equals"
                                }
                            }
                        ],
                        "combinator": "and"
                    }
                },
                "type": "n8n-nodes-base.if",
                "typeVersion": 2.2,
                "position": [
                    base_x + (i % 5) * 200,
                    base_y + (i // 5) * 200
                ],
                "id": node_id,
                "name": node_name
            }
            flow_data['nodes'].append(new_node)
            nodes_added.append(node_name)

    if nodes_added:
        print(f"✓ Added {len(nodes_added)} new routing nodes:")
        for name in nodes_added:
            print(f"  - {name}")
    else:
        print("○ All routing nodes already exist")

    return len(nodes_added) > 0

def add_placeholder_feature_nodes(flow_data):
    """Add placeholder nodes for Tier 4 features."""

    base_x = 3400
    base_y = -200

    placeholder_nodes = [
        {
            "id": "intent-setup-placeholder",
            "name": "Intent Setup Placeholder",
            "message": "🔧 Intent ID Setup feature coming in Tier 4!\n\nThis will allow you to configure custom Intent IDs for Business Chat links."
        },
        {
            "id": "ar-direct-node",
            "name": "AR Direct Send",
            "type": "template",
            "templateId": 344,
            "message": "Check out this guitar in augmented reality!"
        },
        {
            "id": "form-direct-node",
            "name": "Form Direct Send",
            "type": "template",
            "templateId": "TBD",
            "message": "Let's help you find the perfect guitar!"
        },
        {
            "id": "image-request-node",
            "name": "Image Request",
            "message": "📸 Please share a photo or selfie with your guitar!\n\nWe'd love to see you with your new instrument."
        },
        {
            "id": "documents-node",
            "name": "Send Documents",
            "message": "📄 Here are the documents you requested:\n\n• metrics.numbers - Sales performance data\n• document.pdf - Product catalog"
        },
        {
            "id": "auth-placeholder",
            "name": "Authentication Placeholder",
            "message": "🔐 Authentication feature coming in Tier 4!\n\nThis will demonstrate OAuth and server-side authentication flows."
        },
        {
            "id": "imessage-app-placeholder",
            "name": "iMessage App Placeholder",
            "message": "📱 iMessage App extension coming in Tier 4!\n\nThis will demonstrate custom iMessage app interactions."
        },
        {
            "id": "wallet-placeholder",
            "name": "Wallet Pass Placeholder",
            "message": "💳 Wallet pass feature coming in Tier 4!\n\nThis will send a .pkpass file for Apple Wallet."
        },
        {
            "id": "rich-link-node",
            "name": "Rich Link Demo",
            "message": "Here's a rich link preview demo",
            "url": "https://www.apple.com"
        },
        {
            "id": "airport-node",
            "name": "Airport Rich Link",
            "message": "✈️ Airport information rich link",
            "url": "https://maps.apple.com/?q=airport"
        },
        {
            "id": "survey-node",
            "name": "CSAT Survey",
            "message": "📊 How would you rate your experience today?\n\n1 = Poor, 5 = Excellent"
        },
        {
            "id": "quick-reply-demo",
            "name": "Quick Reply Demo",
            "type": "template",
            "templateId": 3,
            "message": "Try these quick replies!"
        }
    ]

    existing_node_ids = {node['id'] for node in flow_data['nodes']}
    nodes_added = []

    for i, placeholder in enumerate(placeholder_nodes):
        node_id = placeholder['id']
        if node_id not in existing_node_ids:
            if placeholder.get('type') == 'template':
                # Template node
                new_node = {
                    "parameters": {
                        "accountId": "={{ $('Router with State').item.json.accountId }}",
                        "conversationId": "={{ $('Router with State').item.json.conversationId }}",
                        "templateId": placeholder['templateId']
                    },
                    "type": "CUSTOM.chatwootAMBTemplateMessage",
                    "typeVersion": 1,
                    "position": [
                        base_x + (i % 4) * 200,
                        base_y + (i // 4) * 150
                    ],
                    "id": node_id,
                    "name": placeholder['name'],
                    "credentials": {
                        "chatwootBotApi": {
                            "id": "1",
                            "name": "Chatwoot Bot API"
                        }
                    }
                }
            else:
                # HTTP Request node (text message)
                new_node = {
                    "parameters": {
                        "method": "POST",
                        "url": "=https://app.chatwoot.com/api/v1/accounts/{{ $('Router with State').item.json.accountId }}/conversations/{{ $('Router with State').item.json.conversationId }}/messages",
                        "authentication": "genericCredentialType",
                        "genericAuthType": "httpHeaderAuth",
                        "sendBody": True,
                        "bodyParameters": {
                            "parameters": [
                                {
                                    "name": "content",
                                    "value": placeholder['message']
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
                    "position": [
                        base_x + (i % 4) * 200,
                        base_y + (i // 4) * 150
                    ],
                    "id": node_id,
                    "name": placeholder['name']
                }

            flow_data['nodes'].append(new_node)
            nodes_added.append(placeholder['name'])

    if nodes_added:
        print(f"✓ Added {len(nodes_added)} placeholder feature nodes:")
        for name in nodes_added:
            print(f"  - {name}")
    else:
        print("○ All placeholder nodes already exist")

    return len(nodes_added) > 0

def main():
    input_file = '/Users/rhaps/LocalGit/chatwoot/n8n-flows/Acoustic-House-Bot-MIGRATED.json'
    output_file = '/Users/rhaps/LocalGit/chatwoot/n8n-flows/Acoustic-House-Bot-MIGRATED.json'

    print("\n" + "="*70)
    print("Implementing Menu Routing and Text Message Handlers")
    print("="*70 + "\n")

    print("Reading flow file...")
    with open(input_file, 'r') as f:
        flow_data = json.load(f)

    print(f"✓ Loaded flow: {flow_data['name']}")
    print(f"  Current nodes: {len(flow_data['nodes'])}")
    print()

    # Update Router node
    print("Phase 1: Updating Router Node")
    print("-" * 50)
    router_updated = update_router_node(flow_data)
    print()

    # Add new routing nodes
    print("Phase 2: Adding Routing Nodes")
    print("-" * 50)
    routing_added = add_new_routing_nodes(flow_data)
    print()

    # Add placeholder feature nodes
    print("Phase 3: Adding Feature Nodes")
    print("-" * 50)
    features_added = add_placeholder_feature_nodes(flow_data)
    print()

    # Save updated flow
    if router_updated or routing_added or features_added:
        print("Saving updated flow...")
        with open(output_file, 'w') as f:
            json.dump(flow_data, f, indent=2)

        print(f"✓ Flow saved: {output_file}")
        print(f"  Total nodes: {len(flow_data['nodes'])}")
        print()
        print("="*70)
        print("✓ Menu routing and text handlers implementation complete!")
        print("="*70)
        print()
        print("Next steps:")
        print("1. Import the updated flow into n8n")
        print("2. Test keyword triggers (menu, guitar, time picker, etc.)")
        print("3. Test menu selections from template 341")
        print("4. Implement Tier 4 features (auth, imessage app, wallet)")
        print()
    else:
        print("○ No changes needed - flow already up to date")

if __name__ == '__main__':
    main()
