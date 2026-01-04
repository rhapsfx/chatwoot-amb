#!/usr/bin/env python3
"""
Add fallback flow when device doesn't support forms.

When "Has FORM Capability?" returns false:
1. Send message: "Looks like your device doesn't support forms, let's skip"
2. Execute AMB Guitar List
"""

import json
import sys

def add_skip_form_message(workflow):
    """Add skip message node."""

    skip_message_node = {
        "id": "skip-form-message",
        "name": "Skip Form - No Capability",
        "type": "n8n-nodes-base.httpRequest",
        "typeVersion": 4.3,
        "position": [2200, 500],
        "credentials": {
            "httpHeaderAuth": {
                "id": "RQQuzy3scKeZsK8H",
                "name": "n8n Local -Bot Chatwoot"
            }
        },
        "parameters": {
            "method": "POST",
            "url": "=https://macbook-pro-14-perso.tail367da4.ts.net/api/v1/accounts/{{ $('Parse Region Selection').item.json.accountId }}/conversations/{{ $('Parse Region Selection').item.json.conversationId }}/messages",
            "authentication": "genericCredentialType",
            "genericAuthType": "httpHeaderAuth",
            "sendBody": True,
            "bodyParameters": {
                "parameters": [
                    {
                        "name": "content",
                        "value": "Looks like your device doesn't support forms, let's skip"
                    },
                    {
                        "name": "message_type",
                        "value": "outgoing"
                    }
                ]
            }
        }
    }

    workflow['nodes'].append(skip_message_node)
    print("✅ Created 'Skip Form - No Capability' message node")

    return skip_message_node

def update_form_capability_connections(workflow):
    """Update connections for Has FORM Capability? node."""

    # Find Has FORM Capability? node ID
    form_capability_node = next((n for n in workflow['nodes']
                                 if n['name'] == 'Has FORM Capability?'), None)

    if not form_capability_node:
        print("❌ Could not find 'Has FORM Capability?' node")
        return

    node_id = form_capability_node['id']

    # Update connections
    # True branch (index 0) → Form Direct Send
    # False branch (index 1) → Skip Form message
    workflow['connections'][node_id] = {
        "main": [
            [
                {
                    "node": "Form Direct Send",
                    "type": "main",
                    "index": 0
                }
            ],
            [
                {
                    "node": "Skip Form - No Capability",
                    "type": "main",
                    "index": 0
                }
            ]
        ]
    }

    print("✅ Updated 'Has FORM Capability?' connections:")
    print("   - True branch → Form Direct Send")
    print("   - False branch → Skip Form - No Capability")

def add_skip_to_guitar_connection(workflow):
    """Connect skip message to AMB Guitar List."""

    workflow['connections']['skip-form-message'] = {
        "main": [
            [
                {
                    "node": "AMB Guitar List",
                    "type": "main",
                    "index": 0
                }
            ]
        ]
    }

    print("✅ Connected 'Skip Form - No Capability' → 'AMB Guitar List'")

def main(input_path, output_path=None):
    """Add form fallback flow."""

    with open(input_path, 'r') as f:
        workflow = json.load(f)

    print("=" * 70)
    print("ADDING FORM CAPABILITY FALLBACK")
    print("=" * 70)

    # Add nodes and connections
    add_skip_form_message(workflow)
    update_form_capability_connections(workflow)
    add_skip_to_guitar_connection(workflow)

    # Save
    if not output_path:
        output_path = input_path.replace('.json', '-FORM-FALLBACK.json')

    with open(output_path, 'w') as f:
        json.dump(workflow, f, indent=2)

    print("\n" + "=" * 70)
    print("✅ FORM FALLBACK ADDED SUCCESSFULLY")
    print("=" * 70)
    print(f"\n🔄 New flow when device doesn't support forms:")
    print(f"   1. Has FORM Capability? [FALSE]")
    print(f"   2. → Skip Form - No Capability (send message)")
    print(f"   3. → AMB Guitar List (continue with guitar selection)")

    print(f"\n💾 Saved to: {output_path}")
    print("=" * 70 + "\n")

    return output_path

if __name__ == '__main__':
    input_file = sys.argv[1] if len(sys.argv) > 1 else 'Acoustic-House-Bot-FINAL-v2.json'
    output_file = sys.argv[2] if len(sys.argv) > 2 else None

    main(input_file, output_file)
