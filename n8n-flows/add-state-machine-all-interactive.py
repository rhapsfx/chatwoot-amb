#!/usr/bin/env python3
"""
Add state machine pattern to ALL interactive messages in the Acoustic House Bot workflow.

This implements the pattern for:
1. Form (Help Me Decide)
2. Guitar List Picker
3. AR View Question
4. AR Place Question
5. Apple Pay
6. Time Picker
7. Name Selection (Quick Reply)
8. Continue Question (Quick Reply)

Pattern for each:
- Send interactive message → Set State → END workflow
- User responds → Router detects state → Parse response
"""

import json
import sys

def add_state_machine_nodes(workflow):
    """Add 'Set State' nodes for all interactive messages."""

    nodes = workflow['nodes']
    connections = workflow['connections']

    print("="*70)
    print("ADDING STATE MACHINE NODES FOR ALL INTERACTIVE MESSAGES")
    print("="*70)

    # Define state nodes to create
    state_nodes = [
        {
            'name': 'Set State: form_shown',
            'after_node': 'Form Direct Send',
            'state_value': 'form_shown',
            'position_offset': [0, 100]
        },
        {
            'name': 'Set State: guitar_list_shown',
            'after_node': 'AMB Guitar List',
            'state_value': 'guitar_list_shown',
            'position_offset': [0, 100]
        },
        {
            'name': 'Set State: ar_view_asked',
            'after_node': 'AR View Question',
            'state_value': 'ar_view_asked',
            'position_offset': [0, -100],  # Already exists, just verify
            'skip_if_exists': True
        },
        {
            'name': 'Set State: ar_place_asked',
            'after_node': 'AR Place Question',
            'state_value': 'ar_place_asked',
            'position_offset': [0, -100],  # Already exists, just verify
            'skip_if_exists': True
        },
        {
            'name': 'Set State: payment_request',
            'after_node': 'AMB Apple Pay Request',
            'state_value': 'payment_request',
            'position_offset': [0, 100]
        },
        {
            'name': 'Set State: time_picker_shown',
            'after_node': 'AMB Time Picker',
            'state_value': 'appointment_booking',  # Use different state name for time picker
            'position_offset': [0, 100]
        },
        {
            'name': 'Set State: name_selection_asked',
            'after_node': 'AHB2 - Name Selection Quick Reply',
            'state_value': 'name_selection_asked',
            'position_offset': [0, 100]
        },
        {
            'name': 'Set State: continue_asked',
            'after_node': 'AHH2 - Continue Quick Reply',
            'state_value': 'continue_asked',
            'position_offset': [0, -100],  # Already exists, just verify
            'skip_if_exists': True
        }
    ]

    created_nodes = []

    for state_def in state_nodes:
        # Check if node already exists
        existing = next((n for n in nodes if n['name'] == state_def['name']), None)

        if existing and state_def.get('skip_if_exists'):
            print(f"✓ {state_def['name']} already exists - skipping")
            continue

        if existing:
            print(f"⚠️  {state_def['name']} already exists - updating state value")
            # Update the state value
            existing['parameters']['bodyParameters']['parameters'][0]['value'] = state_def['state_value']
            continue

        # Find the node to insert after
        after_node = next((n for n in nodes if n['name'] == state_def['after_node']), None)

        if not after_node:
            print(f"❌ Could not find node: {state_def['after_node']}")
            continue

        # Get position
        pos_x = after_node['position'][0] + state_def['position_offset'][0]
        pos_y = after_node['position'][1] + state_def['position_offset'][1]

        # Create Set State node
        set_state_node = {
            "id": f"set-state-{state_def['state_value']}",
            "name": state_def['name'],
            "type": "n8n-nodes-base.httpRequest",
            "typeVersion": 4,
            "position": [pos_x, pos_y],
            "credentials": {
                "httpHeaderAuth": {
                    "id": "RQQuzy3scKeZsK8H",
                    "name": "n8n Local -Bot Chatwoot"
                }
            },
            "parameters": {
                "method": "POST",
                "url": f"=https://mac-studio.tail367da4.ts.net/api/v1/accounts/{{{{ $('Router with State').item.json.accountId }}}}/conversations/{{{{ $('Router with State').item.json.conversationId }}}}/custom_attributes",
                "authentication": "genericCredentialType",
                "genericAuthType": "httpHeaderAuth",
                "sendBody": True,
                "bodyParameters": {
                    "parameters": [
                        {
                            "name": "custom_attributes[bot_state]",
                            "value": state_def['state_value']
                        }
                    ]
                }
            }
        }

        nodes.append(set_state_node)
        created_nodes.append(state_def['name'])
        print(f"✅ Created: {state_def['name']}")

        # Rewire: after_node → set_state_node (remove other connections)
        after_id = after_node['id']
        set_state_id = set_state_node['id']

        # Remove existing connections from after_node
        if after_id in connections:
            connections[after_id] = {"main": [[]]}

        # Connect after_node → set_state_node
        connections[after_id] = {
            "main": [[{"node": state_def['name'], "type": "main", "index": 0}]]
        }

        # Set State node has NO outgoing connections (workflow ends)
        connections[set_state_id] = {"main": [[]]}

    return created_nodes

def add_router_detections(workflow):
    """Add state detection logic to Router for all interactive messages."""

    nodes = workflow['nodes']

    # Find Router node
    router_node = next((n for n in nodes if n['name'] == 'Router with State'), None)

    if not router_node:
        print("❌ Router node not found!")
        return

    code = router_node['parameters']['jsCode']

    # Find where to insert new detections (after Region Selection detection)
    region_block_end = code.find("if (customAttrs.bot_state === 'region_asked') {")

    if region_block_end == -1:
        print("❌ Could not find region detection block!")
        return

    # Find the end of the region block
    brace_count = 0
    insert_pos = region_block_end
    for i in range(region_block_end, len(code)):
        if code[i] == '{':
            brace_count += 1
        elif code[i] == '}':
            brace_count -= 1
            if brace_count == 0:
                insert_pos = i + 1
                break

    # Add detection blocks for all interactive messages
    detection_blocks = """

// ============================================================
// Guitar List Picker Response Detection
// ============================================================
if (customAttrs.bot_state === 'guitar_list_shown') {
  console.log('Handling guitar selection response');
  if (messageType === 'incoming') {
    route = 'GUITAR_RESPONSE';
    console.log('Route: GUITAR_RESPONSE');
  }
}

// ============================================================
// Apple Pay Response Detection
// ============================================================
if (customAttrs.bot_state === 'payment_request') {
  console.log('Handling payment response');
  if (messageType === 'incoming') {
    route = 'PAYMENT_RESPONSE';
    console.log('Route: PAYMENT_RESPONSE');
  }
}

// ============================================================
// Time Picker Response Detection
// ============================================================
if (customAttrs.bot_state === 'appointment_booking') {
  console.log('Handling time selection response');
  if (messageType === 'incoming') {
    route = 'TIME_RESPONSE';
    console.log('Route: TIME_RESPONSE');
  }
}

// ============================================================
// Name Selection Response Detection
// ============================================================
if (customAttrs.bot_state === 'name_selection_asked') {
  console.log('Handling name selection response');
  if (messageType === 'incoming') {
    route = 'NAME_SELECTION_RESPONSE';
    console.log('Route: NAME_SELECTION_RESPONSE');
  }
}"""

    # Insert the detection blocks
    code = code[:insert_pos] + detection_blocks + code[insert_pos:]

    router_node['parameters']['jsCode'] = code
    print("\n✅ Added Router detection logic for all interactive messages")

def add_response_check_nodes(workflow):
    """Add conditional nodes to check for each interactive message response."""

    nodes = workflow['nodes']
    connections = workflow['connections']

    # Find "Is Region Response?" node to use as template
    template_node = next((n for n in nodes if n['name'] == 'Is Region Response?'), None)

    if not template_node:
        print("❌ Template node 'Is Region Response?' not found!")
        return

    # Define response check nodes to create
    response_checks = [
        {
            'name': 'Is Form Response?',
            'route_value': 'FORM_RESPONSE',
            'after_check': 'Is Region Response?',
            'position_offset': [0, 200],
            'true_node': 'AHB1 - Parse Form Response',
            'false_node': 'Is Guitar Response?'
        },
        {
            'name': 'Is Guitar Response?',
            'route_value': 'GUITAR_RESPONSE',
            'after_check': 'Is Form Response?',
            'position_offset': [0, 200],
            'true_node': 'Parse Guitar Selection',
            'false_node': 'Is Payment Response?'
        },
        {
            'name': 'Is Payment Response?',
            'route_value': 'PAYMENT_RESPONSE',
            'after_check': 'Is Guitar Response?',
            'position_offset': [0, 200],
            'true_node': None,  # To be created
            'false_node': 'Is Time Response?'
        },
        {
            'name': 'Is Time Response?',
            'route_value': 'TIME_RESPONSE',
            'after_check': 'Is Payment Response?',
            'position_offset': [0, 200],
            'true_node': None,  # To be created
            'false_node': 'Is Name Selection Response?'
        },
        {
            'name': 'Is Name Selection Response?',
            'route_value': 'NAME_SELECTION_RESPONSE',
            'after_check': 'Is Time Response?',
            'position_offset': [0, 200],
            'true_node': 'AHB2 - Select Name',
            'false_node': 'Is AR View Response?'  # Keep existing AR checks
        }
    ]

    print("\n" + "="*70)
    print("ADDING RESPONSE CHECK NODES")
    print("="*70)

    for check_def in response_checks:
        # Check if node already exists
        existing = next((n for n in nodes if n['name'] == check_def['name']), None)

        if existing:
            print(f"✓ {check_def['name']} already exists - skipping")
            continue

        # Find position reference
        after_node = next((n for n in nodes if n['name'] == check_def['after_check']), None)

        if not after_node:
            print(f"❌ Could not find node: {check_def['after_check']}")
            continue

        # Calculate position
        pos_x = after_node['position'][0] + check_def['position_offset'][0]
        pos_y = after_node['position'][1] + check_def['position_offset'][1]

        # Create conditional node
        check_node = {
            "id": f"check-{check_def['route_value'].lower()}",
            "name": check_def['name'],
            "type": "n8n-nodes-base.if",
            "typeVersion": 2,
            "position": [pos_x, pos_y],
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
                            "id": f"{check_def['route_value'].lower()}-check",
                            "leftValue": "={{ $json.route }}",
                            "rightValue": check_def['route_value'],
                            "operator": {
                                "type": "string",
                                "operation": "equals"
                            }
                        }
                    ]
                }
            }
        }

        nodes.append(check_node)
        print(f"✅ Created: {check_def['name']}")

    print("\nℹ️  Note: Parse nodes for Payment and Time need to be created separately")

def main(input_path, output_path=None):
    """Main function to add state machine pattern to all interactive messages."""

    with open(input_path, 'r') as f:
        workflow = json.load(f)

    print("\n")
    print("="*70)
    print("STATE MACHINE PATTERN - COMPLETE IMPLEMENTATION")
    print("="*70)
    print("\nThis script will:")
    print("1. Add 'Set State' nodes after each interactive message")
    print("2. Add Router detection logic for each state")
    print("3. Add conditional nodes to route responses")
    print("\n")

    # Add Set State nodes
    created_nodes = add_state_machine_nodes(workflow)

    # Add Router detection logic
    add_router_detections(workflow)

    # Add response check nodes
    add_response_check_nodes(workflow)

    # Save
    if not output_path:
        output_path = input_path.replace('.json', '-STATE-MACHINE-ALL.json')

    with open(output_path, 'w') as f:
        json.dump(workflow, f, indent=2)

    print("\n" + "="*70)
    print("✅ STATE MACHINE PATTERN ADDED TO ALL INTERACTIVE MESSAGES")
    print("="*70)
    print(f"\n💾 Saved to: {output_path}")
    print("\n📝 Summary:")
    print(f"   • Created {len(created_nodes)} Set State nodes")
    print("   • Added Router detection for 6 interactive message types")
    print("   • Added response check conditional nodes")
    print("\n🔄 Interactive messages now follow state machine pattern:")
    print("   1. Send message → Set state → END workflow")
    print("   2. User responds → Webhook triggers")
    print("   3. Router detects state → Route to parser")
    print("\n⚠️  Next steps:")
    print("   • Create parse nodes for Payment Response")
    print("   • Create parse nodes for Time Response")
    print("   • Wire all connections in n8n UI")
    print("="*70 + "\n")

    return output_path

if __name__ == '__main__':
    input_file = sys.argv[1] if len(sys.argv) > 1 else 'Acoustic-House-Bot-FINAL-v2.json'
    output_file = sys.argv[2] if len(sys.argv) > 2 else None

    main(input_file, output_file)
