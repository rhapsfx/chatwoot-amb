#!/usr/bin/env python3
"""
AR Flow Implementation Script for Acoustic House Bot n8n Workflow

This script adds the complete two-question AR flow to the n8n workflow JSON.
Based on Python bot code (AH.py lines 1037-1087): AHC2, AHC3, AHD1, AHE1
"""

import json
import sys
from pathlib import Path

def load_workflow(filepath):
    """Load the n8n workflow JSON file."""
    with open(filepath, 'r') as f:
        return json.load(f)

def save_workflow(filepath, workflow):
    """Save the modified workflow JSON file."""
    with open(filepath, 'w') as f:
        json.dump(workflow, f, indent=2)
    print(f"✅ Workflow saved to {filepath}")

def remove_old_ar_nodes(workflow):
    """Remove old single-question AR flow nodes."""
    nodes_to_remove = [
        'ar-prompt',  # Old single AR prompt
        'parse-ar-response',  # Old AR response parser
        'check-ar-yes',  # Old AR yes/no checker
        'ar-no-message',  # Old AR no message
        'send-ar-file',  # Old AR file sender
        'check-ar'  # Old AR route checker
    ]

    original_count = len(workflow['nodes'])
    workflow['nodes'] = [n for n in workflow['nodes'] if n['id'] not in nodes_to_remove]
    removed_count = original_count - len(workflow['nodes'])

    print(f"🗑️  Removed {removed_count} old AR nodes")
    return workflow

def add_ar_introduction_node(workflow):
    """Add AR Introduction message node (AHC2)."""
    node = {
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
                        "value": "Just in. We have this cool Stratocaster. Check it out!!!"
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
        "position": [1650, -200],
        "id": "ar-introduction",
        "name": "AR Introduction"
    }
    workflow['nodes'].append(node)
    return workflow

def add_send_ar_file_node(workflow):
    """Add Send AR File node (AHC2)."""
    node = {
        "parameters": {
            "accountId": "={{ $json.accountId }}",
            "conversationId": "={{ $json.conversationId }}",
            "templateId": 344
        },
        "type": "CUSTOM.chatwootAMBTemplateMessage",
        "typeVersion": 1,
        "position": [1800, -200],
        "id": "send-ar-file",
        "name": "Send AR File",
        "credentials": {
            "chatwootBotApi": {
                "id": "1",
                "name": "Chatwoot Bot API"
            }
        }
    }
    workflow['nodes'].append(node)
    return workflow

def add_first_ar_question_node(workflow):
    """Add First AR Question message node (AHC3)."""
    node = {
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
                        "value": "Did you click on the image and see the 3D augmented reality view of the guitar? (Yes | No)"
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
        "position": [1950, -200],
        "id": "first-ar-question",
        "name": "First AR Question"
    }
    workflow['nodes'].append(node)
    return workflow

def add_ar_view_question_node(workflow):
    """Add AR View Question quick reply node (AHC3)."""
    node = {
        "parameters": {
            "accountId": "={{ $json.accountId }}",
            "conversationId": "={{ $json.conversationId }}",
            "templateId": 3,
            "summaryText": "Did you click on the image and see the 3D AR view?",
            "items": {
                "item": [
                    {
                        "identifier": "ar_view_yes",
                        "title": "Yes"
                    },
                    {
                        "identifier": "ar_view_no",
                        "title": "No"
                    }
                ]
            }
        },
        "type": "CUSTOM.chatwootAMBQuickReply",
        "typeVersion": 1,
        "position": [2100, -200],
        "id": "ar-view-question",
        "name": "AR View Question",
        "credentials": {
            "chatwootBotApi": {
                "id": "1",
                "name": "Chatwoot Bot API"
            }
        }
    }
    workflow['nodes'].append(node)
    return workflow

def add_set_state_ar_view_asked_node(workflow):
    """Add Set State: ar_view_asked node (AHC3)."""
    node = {
        "parameters": {
            "method": "POST",
            "url": "=https://app.chatwoot.com/api/v1/accounts/{{ $json.accountId }}/conversations/{{ $json.conversationId }}/custom_attributes",
            "authentication": "genericCredentialType",
            "genericAuthType": "httpHeaderAuth",
            "sendBody": True,
            "bodyParameters": {
                "parameters": [
                    {
                        "name": "custom_attributes",
                        "value": "={{ { bot_state: 'ar_view_asked' } }}"
                    }
                ]
            }
        },
        "type": "n8n-nodes-base.httpRequest",
        "typeVersion": 4.3,
        "position": [2250, -200],
        "id": "set-state-ar-view-asked",
        "name": "Set State: ar_view_asked"
    }
    workflow['nodes'].append(node)
    return workflow

def add_check_ar_view_response_node(workflow):
    """Add Check AR View Response IF node."""
    node = {
        "parameters": {
            "conditions": {
                "options": {
                    "caseSensitive": False,
                    "leftValue": "",
                    "typeValidation": "strict"
                },
                "conditions": [
                    {
                        "leftValue": "={{ $json.isARViewYes || $json.isARViewNo }}",
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
        "position": [1200, 0],
        "id": "check-ar-view-response",
        "name": "Is AR View Response?"
    }
    workflow['nodes'].append(node)
    return workflow

def add_did_view_ar_node(workflow):
    """Add Did View AR? IF node (AHD1)."""
    node = {
        "parameters": {
            "conditions": {
                "options": {
                    "caseSensitive": False,
                    "leftValue": "",
                    "typeValidation": "strict"
                },
                "conditions": [
                    {
                        "leftValue": "={{ $json.isARViewYes }}",
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
        "position": [1350, -300],
        "id": "did-view-ar",
        "name": "Did View AR?"
    }
    workflow['nodes'].append(node)
    return workflow

def add_ar_view_success_node(workflow):
    """Add AR View Success message node (AHD1)."""
    node = {
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
                        "value": "Awesome! Did you select AR from the top of the image and set it down in front of you? (Yes | No)"
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
        "position": [1500, -400],
        "id": "ar-view-success",
        "name": "AR View Success"
    }
    workflow['nodes'].append(node)
    return workflow

def add_ar_view_instruction_node(workflow):
    """Add AR View Instruction message node (AHD1)."""
    node = {
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
                        "value": "Try tapping on the image to see the AR image of the guitar!"
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
        "position": [1500, -200],
        "id": "ar-view-instruction",
        "name": "AR View Instruction"
    }
    workflow['nodes'].append(node)
    return workflow

def add_second_ar_question_node(workflow):
    """Add Second AR Question message node (AHD1)."""
    node = {
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
                        "value": "Did you select AR from the top of the image and set it down in front of you? (Yes | No)"
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
        "position": [1650, -300],
        "id": "second-ar-question-after-no",
        "name": "Second AR Question (After No)"
    }
    workflow['nodes'].append(node)
    return workflow

def add_ar_place_question_node(workflow):
    """Add AR Place Question quick reply node (AHD1)."""
    node = {
        "parameters": {
            "accountId": "={{ $json.accountId }}",
            "conversationId": "={{ $json.conversationId }}",
            "templateId": 3,
            "summaryText": "Did you place the AR guitar in your space?",
            "items": {
                "item": [
                    {
                        "identifier": "ar_place_yes",
                        "title": "Yes"
                    },
                    {
                        "identifier": "ar_place_no",
                        "title": "No"
                    }
                ]
            }
        },
        "type": "CUSTOM.chatwootAMBQuickReply",
        "typeVersion": 1,
        "position": [1800, -300],
        "id": "ar-place-question",
        "name": "AR Place Question",
        "credentials": {
            "chatwootBotApi": {
                "id": "1",
                "name": "Chatwoot Bot API"
            }
        }
    }
    workflow['nodes'].append(node)
    return workflow

def add_set_state_ar_place_asked_node(workflow):
    """Add Set State: ar_place_asked node (AHD1)."""
    node = {
        "parameters": {
            "method": "POST",
            "url": "=https://app.chatwoot.com/api/v1/accounts/{{ $json.accountId }}/conversations/{{ $json.conversationId }}/custom_attributes",
            "authentication": "genericCredentialType",
            "genericAuthType": "httpHeaderAuth",
            "sendBody": True,
            "bodyParameters": {
                "parameters": [
                    {
                        "name": "custom_attributes",
                        "value": "={{ { bot_state: 'ar_place_asked' } }}"
                    }
                ]
            }
        },
        "type": "n8n-nodes-base.httpRequest",
        "typeVersion": 4.3,
        "position": [1950, -300],
        "id": "set-state-ar-place-asked",
        "name": "Set State: ar_place_asked"
    }
    workflow['nodes'].append(node)
    return workflow

def add_check_ar_place_response_node(workflow):
    """Add Check AR Place Response IF node."""
    node = {
        "parameters": {
            "conditions": {
                "options": {
                    "caseSensitive": False,
                    "leftValue": "",
                    "typeValidation": "strict"
                },
                "conditions": [
                    {
                        "leftValue": "={{ $json.isARPlaceYes || $json.isARPlaceNo }}",
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
        "position": [1400, 0],
        "id": "check-ar-place-response",
        "name": "Is AR Place Response?"
    }
    workflow['nodes'].append(node)
    return workflow

def add_did_place_ar_node(workflow):
    """Add Did Place AR? IF node (AHE1)."""
    node = {
        "parameters": {
            "conditions": {
                "options": {
                    "caseSensitive": False,
                    "leftValue": "",
                    "typeValidation": "strict"
                },
                "conditions": [
                    {
                        "leftValue": "={{ $json.isARPlaceNo }}",
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
        "position": [1550, -400],
        "id": "did-place-ar",
        "name": "Did Place AR?"
    }
    workflow['nodes'].append(node)
    return workflow

def add_ar_place_instruction_node(workflow):
    """Add AR Place Instruction message node (AHE1)."""
    node = {
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
                        "value": "Try tapping on the image to see the AR image of the guitar!"
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
        "position": [1700, -500],
        "id": "ar-place-instruction",
        "name": "AR Place Instruction"
    }
    workflow['nodes'].append(node)
    return workflow

def add_apple_pay_transition_node(workflow):
    """Add Apple Pay Transition message node (AHE1)."""
    node = {
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
                        "value": "Great, let's buy your new guitar."
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
        "position": [1850, -400],
        "id": "apple-pay-transition",
        "name": "Apple Pay Transition"
    }
    workflow['nodes'].append(node)
    return workflow

def update_connections(workflow):
    """Update all node connections for the AR flow."""
    connections = workflow.get('connections', {})

    # Update "Send Guitar Image" to connect to "AR Introduction"
    connections['Send Guitar Image'] = {
        "main": [[{
            "node": "AR Introduction",
            "type": "main",
            "index": 0
        }]]
    }

    # Linear flow for AR setup
    connections['AR Introduction'] = {
        "main": [[{
            "node": "Send AR File",
            "type": "main",
            "index": 0
        }]]
    }

    connections['Send AR File'] = {
        "main": [[{
            "node": "First AR Question",
            "type": "main",
            "index": 0
        }]]
    }

    connections['First AR Question'] = {
        "main": [[{
            "node": "AR View Question",
            "type": "main",
            "index": 0
        }]]
    }

    connections['AR View Question'] = {
        "main": [[{
            "node": "Set State: ar_view_asked",
            "type": "main",
            "index": 0
        }]]
    }

    # Update router chain to include AR response checkers
    connections['Is Guitar?']['main'][1] = [{
        "node": "Is AR View Response?",
        "type": "main",
        "index": 0
    }]

    connections['Is AR View Response?'] = {
        "main": [
            [{
                "node": "Did View AR?",
                "type": "main",
                "index": 0
            }],
            [{
                "node": "Is AR Place Response?",
                "type": "main",
                "index": 0
            }]
        ]
    }

    connections['Did View AR?'] = {
        "main": [
            [{
                "node": "AR View Success",
                "type": "main",
                "index": 0
            }],
            [{
                "node": "AR View Instruction",
                "type": "main",
                "index": 0
            }]
        ]
    }

    connections['AR View Success'] = {
        "main": [[{
            "node": "AR Place Question",
            "type": "main",
            "index": 0
        }]]
    }

    connections['AR View Instruction'] = {
        "main": [[{
            "node": "Second AR Question (After No)",
            "type": "main",
            "index": 0
        }]]
    }

    connections['Second AR Question (After No)'] = {
        "main": [[{
            "node": "AR Place Question",
            "type": "main",
            "index": 0
        }]]
    }

    connections['AR Place Question'] = {
        "main": [[{
            "node": "Set State: ar_place_asked",
            "type": "main",
            "index": 0
        }]]
    }

    connections['Is AR Place Response?'] = {
        "main": [
            [{
                "node": "Did Place AR?",
                "type": "main",
                "index": 0
            }],
            [{
                "node": "Is Payment?",
                "type": "main",
                "index": 0
            }]
        ]
    }

    connections['Did Place AR?'] = {
        "main": [
            [{
                "node": "AR Place Instruction",
                "type": "main",
                "index": 0
            }],
            [{
                "node": "Apple Pay Transition",
                "type": "main",
                "index": 0
            }]
        ]
    }

    connections['AR Place Instruction'] = {
        "main": [[{
            "node": "Apple Pay Transition",
            "type": "main",
            "index": 0
        }]]
    }

    connections['Apple Pay Transition'] = {
        "main": [[{
            "node": "AMB Apple Pay Request",
            "type": "main",
            "index": 0
        }]]
    }

    workflow['connections'] = connections
    return workflow

def main():
    """Main execution function."""
    filepath = Path('/Users/rhaps/LocalGit/chatwoot/n8n-flows/Acoustic-House-Bot-MIGRATED.json')

    print("🚀 Starting AR Flow Implementation...")
    print(f"📄 Loading workflow from: {filepath}")

    workflow = load_workflow(filepath)
    original_node_count = len(workflow['nodes'])
    print(f"📊 Original node count: {original_node_count}")

    # Step 1: Remove old nodes
    print("\n🗑️  Removing old AR nodes...")
    workflow = remove_old_ar_nodes(workflow)

    # Step 2: Add new nodes
    print("\n➕ Adding new AR flow nodes...")
    workflow = add_ar_introduction_node(workflow)
    workflow = add_send_ar_file_node(workflow)
    workflow = add_first_ar_question_node(workflow)
    workflow = add_ar_view_question_node(workflow)
    workflow = add_set_state_ar_view_asked_node(workflow)
    workflow = add_check_ar_view_response_node(workflow)
    workflow = add_did_view_ar_node(workflow)
    workflow = add_ar_view_success_node(workflow)
    workflow = add_ar_view_instruction_node(workflow)
    workflow = add_second_ar_question_node(workflow)
    workflow = add_ar_place_question_node(workflow)
    workflow = add_set_state_ar_place_asked_node(workflow)
    workflow = add_check_ar_place_response_node(workflow)
    workflow = add_did_place_ar_node(workflow)
    workflow = add_ar_place_instruction_node(workflow)
    workflow = add_apple_pay_transition_node(workflow)

    new_node_count = len(workflow['nodes'])
    print(f"📊 New node count: {new_node_count} (added {new_node_count - original_node_count + 6} nodes)")

    # Step 3: Update connections
    print("\n🔗 Updating node connections...")
    workflow = update_connections(workflow)

    # Step 4: Save workflow
    print("\n💾 Saving modified workflow...")
    save_workflow(filepath, workflow)

    print("\n✅ AR Flow Implementation Complete!")
    print(f"📊 Final Statistics:")
    print(f"   - Removed: 6 old AR nodes")
    print(f"   - Added: 16 new AR flow nodes")
    print(f"   - Total nodes: {new_node_count}")
    print(f"\n📝 Next steps:")
    print("   1. Import the updated workflow into n8n")
    print("   2. Test the complete AR flow")
    print("   3. Verify state transitions")
    print("   4. Test both Yes/No paths for both questions")

if __name__ == '__main__':
    main()
