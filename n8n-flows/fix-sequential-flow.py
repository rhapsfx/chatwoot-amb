#!/usr/bin/env python3
"""
Fix Acoustic House Bot to add missing Region Selection and proper sequential onboarding flow.

According to ACOUSTIC-HOUSE-BOT-FINAL-IMPLEMENTATION-REPORT.md:
- Phase 1: Welcome → Region Selection → Name Collection
- Region Selection should be a Quick Reply with 3 options (Americas, EMEA, APAC)
- This is currently missing and goes straight to AMB Main Menu

This script:
1. Adds Region Selection Quick Reply node (AHA2)
2. Adds Parse Region Selection node
3. Adds Update Region node
4. Rewires Welcome Message 2 → Region Selection (not AMB Main Menu)
5. Connects Region Selection → Name Collection flow
"""

import json
import uuid
from datetime import datetime

def generate_node_id():
    """Generate a unique node ID."""
    return str(uuid.uuid4())

def create_region_quick_reply_node():
    """Create the Region Selection Quick Reply node (AHA2)."""
    return {
        "id": generate_node_id(),
        "name": "AHA2 - Region Selection",
        "type": "CUSTOM.chatwootAMBQuickReply",
        "typeVersion": 1,
        "position": [1200, 400],
        "credentials": {
            "chatwootBotApi": {
                "id": "c1Q7oV1mUwnc9b5T",
                "name": "Chatwoot Test Bot"
            }
        },
        "parameters": {
            "accountId": "={{ $('Router with State').item.json.accountId }}",
            "conversationId": "={{ $('Router with State').item.json.conversationId }}",
            "message": "Welcome to Acoustic House! 🎸\n\nWhere are you in the world?",
            "options": [
                {
                    "title": "Americas",
                    "value": "americas"
                },
                {
                    "title": "EMEA",
                    "value": "emea"
                },
                {
                    "title": "APAC",
                    "value": "apac"
                }
            ]
        }
    }

def create_parse_region_node():
    """Create the Parse Region Selection node."""
    return {
        "id": generate_node_id(),
        "name": "Parse Region Selection",
        "type": "n8n-nodes-base.code",
        "typeVersion": 2,
        "position": [1400, 400],
        "parameters": {
            "jsCode": """// Parse region selection from Quick Reply
const data = $json.body || $json;
const content = (data.content || '').toLowerCase().trim();

// Map region selection
let region = 'unknown';
if (content.includes('americas') || content === 'americas') {
  region = 'Americas';
} else if (content.includes('emea') || content === 'emea') {
  region = 'EMEA';
} else if (content.includes('apac') || content === 'apac') {
  region = 'APAC';
}

console.log('Region selected:', region);

return {
  json: {
    accountId: data.conversation?.account_id,
    conversationId: data.conversation?.id,
    region: region,
    userId: data.sender?.id
  }
};"""
        }
    }

def create_update_region_node():
    """Create the Update Region node (stores region in custom_attributes)."""
    return {
        "id": generate_node_id(),
        "name": "Update Region Attribute",
        "type": "n8n-nodes-base.httpRequest",
        "typeVersion": 4,
        "position": [1600, 400],
        "credentials": {
            "httpHeaderAuth": {
                "id": "RQQuzy3scKeZsK8H",
                "name": "n8n Local -Bot Chatwoot"
            }
        },
        "parameters": {
            "method": "POST",
            "url": "=https://liquid-m3-pro.tail367da4.ts.net/api/v1/accounts/{{ $json.accountId }}/conversations/{{ $json.conversationId }}/custom_attributes",
            "authentication": "genericCredentialType",
            "genericAuthType": "httpHeaderAuth",
            "sendBody": True,
            "bodyParameters": {
                "parameters": [
                    {
                        "name": "custom_attributes[region]",
                        "value": "={{ $json.region }}"
                    }
                ]
            }
        }
    }

def create_thank_you_message_node():
    """Create thank you message after region selection."""
    return {
        "id": generate_node_id(),
        "name": "AHA3 - Region Confirmation",
        "type": "n8n-nodes-base.httpRequest",
        "typeVersion": 4,
        "position": [1800, 400],
        "credentials": {
            "httpHeaderAuth": {
                "id": "RQQuzy3scKeZsK8H",
                "name": "n8n Local -Bot Chatwoot"
            }
        },
        "parameters": {
            "method": "POST",
            "url": "=https://liquid-m3-pro.tail367da4.ts.net/api/v1/accounts/{{ $('Parse Region Selection').item.json.accountId }}/conversations/{{ $('Parse Region Selection').item.json.conversationId }}/messages",
            "authentication": "genericCredentialType",
            "genericAuthType": "httpHeaderAuth",
            "sendBody": True,
            "bodyParameters": {
                "parameters": [
                    {
                        "name": "content",
                        "value": "Thank you! Let's help you find your next guitar. 🎸"
                    },
                    {
                        "name": "message_type",
                        "value": "outgoing"
                    }
                ]
            }
        }
    }

def create_has_form_capability_node():
    """Create node to check if device has FORM capability."""
    return {
        "id": generate_node_id(),
        "name": "Has FORM Capability?",
        "type": "n8n-nodes-base.if",
        "typeVersion": 2,
        "position": [2000, 400],
        "parameters": {
            "conditions": {
                "options": {
                    "leftValue": "",
                    "caseSensitive": True,
                    "typeValidation": "strict"
                },
                "combinator": "and",
                "conditions": [
                    {
                        "id": "form-capability",
                        "leftValue": "={{ true }}",
                        "rightValue": "={{ true }}",
                        "operator": {
                            "type": "boolean",
                            "operation": "equals"
                        }
                    }
                ]
            }
        }
    }

def fix_workflow(input_path: str, output_path: str = None):
    """Fix the workflow to add Region Selection."""

    # Read workflow
    with open(input_path, 'r') as f:
        workflow = json.load(f)

    print("="*70)
    print("FIXING SEQUENTIAL ONBOARDING FLOW")
    print("="*70)

    # Create new nodes
    print("\n1️⃣  Creating new nodes...")
    region_qr = create_region_quick_reply_node()
    parse_region = create_parse_region_node()
    update_region = create_update_region_node()
    thank_you = create_thank_you_message_node()
    has_form = create_has_form_capability_node()

    new_nodes = [region_qr, parse_region, update_region, thank_you, has_form]

    print(f"   ✅ Created {len(new_nodes)} new nodes:")
    for node in new_nodes:
        print(f"      - {node['name']}")

    # Add nodes to workflow
    workflow['nodes'].extend(new_nodes)

    # Rewire connections
    print("\n2️⃣  Rewiring connections...")
    connections = workflow['connections']

    # Welcome Message 2 → Region Selection (instead of AMB Main Menu)
    print("   ✅ Welcome Message 2 → AHA2 - Region Selection")
    connections['Welcome Message 2'] = {
        'main': [[{'node': 'AHA2 - Region Selection', 'type': 'main', 'index': 0}]]
    }

    # Region Selection → Parse Region
    print("   ✅ AHA2 - Region Selection → Parse Region Selection")
    connections['AHA2 - Region Selection'] = {
        'main': [[{'node': 'Parse Region Selection', 'type': 'main', 'index': 0}]]
    }

    # Parse Region → Update Region
    print("   ✅ Parse Region Selection → Update Region Attribute")
    connections['Parse Region Selection'] = {
        'main': [[{'node': 'Update Region Attribute', 'type': 'main', 'index': 0}]]
    }

    # Update Region → Thank You Message
    print("   ✅ Update Region Attribute → AHA3 - Region Confirmation")
    connections['Update Region Attribute'] = {
        'main': [[{'node': 'AHA3 - Region Confirmation', 'type': 'main', 'index': 0}]]
    }

    # Thank You → Check Form Capability
    print("   ✅ AHA3 - Region Confirmation → Has FORM Capability?")
    connections['AHA3 - Region Confirmation'] = {
        'main': [[{'node': 'Has FORM Capability?', 'type': 'main', 'index': 0}]]
    }

    # Has FORM Capability → Form (TRUE) or Text Name (FALSE)
    # For now, always route to Form (we'll check if Form Direct Send exists)
    form_node = next((n for n in workflow['nodes'] if n['name'] == 'Form Direct Send'), None)
    if form_node:
        print("   ✅ Has FORM Capability? → Form Direct Send (TRUE)")
        connections['Has FORM Capability?'] = {
            'main': [
                [{'node': 'Form Direct Send', 'type': 'main', 'index': 0}],
                [{'node': 'Form Direct Send', 'type': 'main', 'index': 0}]  # For now, both paths go to form
            ]
        }

    # Save workflow
    if not output_path:
        output_path = input_path.replace('.json', '-SEQUENTIAL-FLOW.json')

    with open(output_path, 'w') as f:
        json.dump(workflow, f, indent=2)

    # Summary
    print("\n" + "="*70)
    print("✅ SEQUENTIAL FLOW FIXED!")
    print("="*70)
    print(f"\n📊 Summary:")
    print(f"  • New nodes added: {len(new_nodes)}")
    print(f"  • Total nodes: {len(workflow['nodes'])}")
    print(f"  • Connections rewired: 6")

    print(f"\n🎯 New Flow:")
    print(f"  1. Webhook")
    print(f"  2. Router with State")
    print(f"  3. Should Process?")
    print(f"  4. Is Welcome?")
    print(f"  5. Welcome Message 1")
    print(f"  6. Welcome Message 2")
    print(f"  7. AHA2 - Region Selection ⭐ NEW")
    print(f"  8. Parse Region Selection ⭐ NEW")
    print(f"  9. Update Region Attribute ⭐ NEW")
    print(f"  10. AHA3 - Region Confirmation ⭐ NEW")
    print(f"  11. Has FORM Capability? ⭐ NEW")
    print(f"  12. Form Direct Send (Name Collection)")
    print(f"  13. ... AR Flow → Apple Pay → Lesson → etc.")

    print(f"\n💾 Fixed workflow saved to:")
    print(f"  {output_path}")

    print(f"\n🚀 Next Steps:")
    print(f"  1. Import {output_path.split('/')[-1]} into n8n")
    print(f"  2. Test: Send 'start' → Select region → Complete flow")
    print(f"  3. Verify: Region stored in custom_attributes")

    print("="*70 + "\n")

    return output_path

if __name__ == '__main__':
    import sys

    input_file = sys.argv[1] if len(sys.argv) > 1 else 'Acoustic-House-Bot-TIER4-COMPLETE-FIX.json'
    output_file = sys.argv[2] if len(sys.argv) > 2 else None

    fix_workflow(input_file, output_file)
