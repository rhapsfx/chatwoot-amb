#!/usr/bin/env python3
"""
Script to add Name Collection Flow nodes to Acoustic House Bot workflow
"""

import json
import sys

def add_name_collection_flow(workflow_path):
    """Add name collection flow nodes and connections to the workflow"""

    # Read the existing workflow
    with open(workflow_path, 'r') as f:
        workflow = json.load(f)

    # Update the Router with State to handle NAME_SELECTED route
    router_node = next(n for n in workflow['nodes'] if n['id'] == 'router')
    router_code = router_node['parameters']['jsCode']

    # Add NAME_SELECTED route to quick reply handler
    router_code = router_code.replace(
        "  if (reply.includes('region_')) {\n    route = 'REGION_SELECTED';\n    nextState = 'region_selected';\n  } else if (reply === 'ar_yes') {",
        "  if (reply.includes('region_')) {\n    route = 'REGION_SELECTED';\n    nextState = 'region_selected';\n  } else if (reply === 'name_real' || reply === 'name_stage') {\n    route = 'NAME_SELECTED';\n    nextState = 'name_selected';\n  } else if (reply === 'ar_yes') {"
    )

    # Add isNameSelected flag
    router_code = router_code.replace(
        "    isNameCollected: route === 'NAME_COLLECTED',\n    isGuitar:",
        "    isNameCollected: route === 'NAME_COLLECTED',\n    isNameSelected: route === 'NAME_SELECTED',\n    isGuitar:"
    )

    router_node['parameters']['jsCode'] = router_code

    # Add new nodes for name collection flow
    new_nodes = [
        # Check if Region Selected
        {
            "parameters": {
                "conditions": {
                    "options": {
                        "caseSensitive": False,
                        "leftValue": "",
                        "typeValidation": "strict"
                    },
                    "conditions": [
                        {
                            "leftValue": "={{ $json.isRegionSelected }}",
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
            "position": [2600, 0],
            "id": "check-region-selected",
            "name": "Is Region Selected?"
        },
        # Check if Name Collected (form)
        {
            "parameters": {
                "conditions": {
                    "options": {
                        "caseSensitive": False,
                        "leftValue": "",
                        "typeValidation": "strict"
                    },
                    "conditions": [
                        {
                            "leftValue": "={{ $json.isNameCollected }}",
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
            "position": [2800, 0],
            "id": "check-name-collected",
            "name": "Is Name Collected?"
        },
        # Check if Name Selected (quick reply)
        {
            "parameters": {
                "conditions": {
                    "options": {
                        "caseSensitive": False,
                        "leftValue": "",
                        "typeValidation": "strict"
                    },
                    "conditions": [
                        {
                            "leftValue": "={{ $json.isNameSelected }}",
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
            "position": [3000, 0],
            "id": "check-name-selected",
            "name": "Is Name Selected?"
        },
        # AHB1 - Parse Form Response
        {
            "parameters": {
                "jsCode": "// AHB1 - Parse Help Me Decide Form Response\nconst data = $json.body || $json;\nconst contentAttrs = data.content_attributes || {};\nconst formData = contentAttrs.interactive_data?.data?.form || {};\nconst items = formData.items || [];\n\n// Extract name from field 4 (index 3)\nlet userName = '';\nlet stageName = '';\n\nif (items.length > 3 && items[3].items && items[3].items.length > 0) {\n  userName = items[3].items[0].value || '';\n}\n\n// Extract optional stage name from field 5 (index 4)\nif (items.length > 4 && items[4].items && items[4].items.length > 0) {\n  stageName = items[4].items[0].value || '';\n}\n\nconsole.log('AHB1 - Name:', userName, 'Stage Name:', stageName);\n\nreturn {\n  json: {\n    ...($json || {}),\n    userName: userName,\n    stageName: stageName,\n    hasStageName: stageName !== '',\n    conversationId: data.conversation?.id,\n    accountId: data.account?.id || 1\n  }\n};"
            },
            "type": "n8n-nodes-base.code",
            "typeVersion": 2,
            "position": [2800, -200],
            "id": "parse-form-response",
            "name": "AHB1 - Parse Form Response"
        },
        # Has Stage Name check
        {
            "parameters": {
                "conditions": {
                    "options": {
                        "caseSensitive": False,
                        "leftValue": "",
                        "typeValidation": "strict"
                    },
                    "conditions": [
                        {
                            "leftValue": "={{ $json.hasStageName }}",
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
            "position": [3000, -200],
            "id": "has-stage-name",
            "name": "Has Stage Name?"
        },
        # Ask Name Preference
        {
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
                            "value": "How would you like to be addressed?"
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
            "position": [3200, -300],
            "id": "ask-name-preference",
            "name": "AHB2 - Ask Name Preference"
        },
        # Name Selection Quick Reply
        {
            "parameters": {
                "accountId": "={{ $json.accountId }}",
                "conversationId": "={{ $json.conversationId }}",
                "templateId": 3,
                "summaryText": "Choose how you'd like to be addressed:",
                "items": {
                    "item": [
                        {
                            "identifier": "name_real",
                            "title": "Use my name"
                        },
                        {
                            "identifier": "name_stage",
                            "title": "Use stage name"
                        }
                    ]
                }
            },
            "type": "CUSTOM.chatwootAMBQuickReply",
            "typeVersion": 1,
            "position": [3200, -200],
            "id": "name-selection-qr",
            "name": "AHB2 - Name Selection Quick Reply",
            "credentials": {
                "chatwootBotApi": {
                    "id": "1",
                    "name": "Chatwoot Bot API"
                }
            }
        },
        # AHB2 - Select Name from Quick Reply
        {
            "parameters": {
                "jsCode": "// AHB2 - Select Name based on Quick Reply\nconst data = $json.body || $json;\nconst contentAttrs = data.content_attributes || {};\nconst quickReply = contentAttrs.interactive_data?.data?.['quick-reply'] || {};\nconst identifier = quickReply.identifier || '';\n\n// Get the previously stored names from custom attributes or webhook data\nconst conversation = data.conversation || {};\nconst customAttrs = conversation.custom_attributes || {};\n\nlet selectedName = '';\nif (identifier === 'name_real') {\n  selectedName = customAttrs.user_name || '';\n} else if (identifier === 'name_stage') {\n  selectedName = customAttrs.stage_name || '';\n}\n\nconsole.log('AHB2 - Selected:', identifier, 'Name:', selectedName);\n\nreturn {\n  json: {\n    ...($json || {}),\n    selectedName: selectedName,\n    nameSelection: identifier,\n    conversationId: conversation.id,\n    accountId: data.account?.id || 1\n  }\n};"
            },
            "type": "n8n-nodes-base.code",
            "typeVersion": 2,
            "position": [3200, -100],
            "id": "select-name",
            "name": "AHB2 - Select Name"
        },
        # AHB1_2 - Parse Text Name Input
        {
            "parameters": {
                "jsCode": "// AHB1_2 - Parse text name input (fallback when form capability not available)\nconst data = $json.body || $json;\nconst content = data.content || '';\n\n// Capitalize first letter\nconst name = content.charAt(0).toUpperCase() + content.slice(1);\n\nconsole.log('AHB1_2 - Text name:', name);\n\nreturn {\n  json: {\n    ...($json || {}),\n    selectedName: name,\n    conversationId: data.conversation?.id,\n    accountId: data.account?.id || 1\n  }\n};"
            },
            "type": "n8n-nodes-base.code",
            "typeVersion": 2,
            "position": [3200, -400],
            "id": "parse-text-name",
            "name": "AHB1_2 - Parse Text Name"
        },
        # Update Custom Attributes with Name
        {
            "parameters": {
                "method": "POST",
                "url": "=https://app.chatwoot.com/api/v1/accounts/{{ $json.accountId }}/conversations/{{ $json.conversationId }}/custom_attributes",
                "authentication": "genericCredentialType",
                "genericAuthType": "httpHeaderAuth",
                "sendBody": True,
                "bodyParameters": {
                    "parameters": [
                        {
                            "name": "custom_attributes[user_name]",
                            "value": "={{ $json.userName || '' }}"
                        },
                        {
                            "name": "custom_attributes[stage_name]",
                            "value": "={{ $json.stageName || '' }}"
                        },
                        {
                            "name": "custom_attributes[selected_name]",
                            "value": "={{ $json.selectedName || $json.userName || '' }}"
                        }
                    ]
                }
            },
            "type": "n8n-nodes-base.httpRequest",
            "typeVersion": 4.3,
            "position": [3400, -200],
            "id": "update-name-attrs",
            "name": "Update Name Attributes"
        },
        # AHB3 - Personalized Greeting
        {
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
                            "value": "=Hello {{ $json.selectedName || $json.userName || 'there' }}. We have some cool guitars we would like you to see."
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
            "position": [3600, -200],
            "id": "personalized-greeting",
            "name": "AHB3 - Personalized Greeting"
        }
    ]

    # Add the new nodes
    workflow['nodes'].extend(new_nodes)

    # Update connections
    connections = workflow['connections']

    # Chain the check nodes: Is Features? -> Is Region Selected? -> Is Name Collected? -> Is Name Selected? -> Unknown
    if 'Is Features?' in connections:
        # Add check-region-selected to the chain
        connections['Is Features?']['main'][1] = [
            {"node": "Is Region Selected?", "type": "main", "index": 0}
        ]

    connections['Is Region Selected?'] = {
        "main": [
            [{"node": "AHB1 - Parse Form Response", "type": "main", "index": 0}],  # TRUE - placeholder, will trigger form
            [{"node": "Is Name Collected?", "type": "main", "index": 0}]  # FALSE
        ]
    }

    connections['Is Name Collected?'] = {
        "main": [
            [{"node": "AHB1 - Parse Form Response", "type": "main", "index": 0}],  # TRUE
            [{"node": "Is Name Selected?", "type": "main", "index": 0}]  # FALSE
        ]
    }

    connections['Is Name Selected?'] = {
        "main": [
            [{"node": "AHB2 - Select Name", "type": "main", "index": 0}],  # TRUE
            [{"node": "Unknown Route", "type": "main", "index": 0}]  # FALSE
        ]
    }

    # AHB1 flow: Parse Form -> Has Stage Name?
    connections['AHB1 - Parse Form Response'] = {
        "main": [[{"node": "Has Stage Name?", "type": "main", "index": 0}]]
    }

    # Has Stage Name: TRUE -> Ask Preference + QR, FALSE -> Go direct to greeting
    connections['Has Stage Name?'] = {
        "main": [
            [{"node": "AHB2 - Ask Name Preference", "type": "main", "index": 0}],  # TRUE
            [{"node": "Update Name Attributes", "type": "main", "index": 0}]  # FALSE - direct to greeting
        ]
    }

    # Ask Preference -> Name Selection QR
    connections['AHB2 - Ask Name Preference'] = {
        "main": [[{"node": "AHB2 - Name Selection Quick Reply", "type": "main", "index": 0}]]
    }

    # AHB2 - Select Name -> Update Attributes
    connections['AHB2 - Select Name'] = {
        "main": [[{"node": "Update Name Attributes", "type": "main", "index": 0}]]
    }

    # Update Attributes -> Personalized Greeting
    connections['Update Name Attributes'] = {
        "main": [[{"node": "AHB3 - Personalized Greeting", "type": "main", "index": 0}]]
    }

    # Personalized Greeting -> Guitar List
    connections['AHB3 - Personalized Greeting'] = {
        "main": [[{"node": "AMB Guitar List", "type": "main", "index": 0}]]
    }

    # Write updated workflow
    with open(workflow_path, 'w') as f:
        json.dump(workflow, f, indent=2)

    print("✅ Name Collection Flow added successfully!")
    print("\nAdded nodes:")
    print("  - Is Region Selected? (check node)")
    print("  - Is Name Collected? (check node)")
    print("  - Is Name Selected? (check node)")
    print("  - AHB1 - Parse Form Response")
    print("  - Has Stage Name? (check node)")
    print("  - AHB2 - Ask Name Preference")
    print("  - AHB2 - Name Selection Quick Reply")
    print("  - AHB2 - Select Name")
    print("  - AHB1_2 - Parse Text Name")
    print("  - Update Name Attributes")
    print("  - AHB3 - Personalized Greeting")
    print("\nConnections updated:")
    print("  - Router handles NAME_SELECTED route")
    print("  - Check chain: Features -> Region -> Name Collected -> Name Selected -> Unknown")
    print("  - Form path: Parse Form -> Has Stage Name? -> [Ask Preference + QR] or [Direct to Greeting]")
    print("  - Final path: Update Attributes -> Personalized Greeting -> Guitar List")

if __name__ == '__main__':
    workflow_path = '/Users/rhaps/LocalGit/chatwoot/n8n-flows/Acoustic-House-Bot-MIGRATED.json'
    add_name_collection_flow(workflow_path)
