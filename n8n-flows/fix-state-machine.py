#!/usr/bin/env python3
"""
Fix the state machine pattern for Region Selection (and all interactive messages).

PROBLEM:
  AHA2 (send Quick Reply) → Parse Region Selection → Update → etc.
  This runs immediately without waiting for user response!

SOLUTION:
  1. AHA2 (send Quick Reply) → Set State: region_asked → END
  2. User responds → Webhook triggers
  3. Router detects state="region_asked" → Parse Region Selection
  4. Parse → Update → Confirmation → Set state → Form
"""

import json

def fix_state_machine(input_path: str, output_path: str = None):
    """Fix the state machine pattern for interactive messages."""

    with open(input_path, 'r') as f:
        workflow = json.load(f)

    print("="*70)
    print("FIXING STATE MACHINE PATTERN")
    print("="*70)

    connections = workflow['connections']

    # 1. Add "Set State: region_asked" node after Region Selection
    set_state_node = {
        "id": "set-state-region",
        "name": "Set State: region_asked",
        "type": "n8n-nodes-base.httpRequest",
        "typeVersion": 4,
        "position": [1400, 500],
        "credentials": {
            "httpHeaderAuth": {
                "id": "RQQuzy3scKeZsK8H",
                "name": "n8n Local -Bot Chatwoot"
            }
        },
        "parameters": {
            "method": "POST",
            "url": "=https://mac-studio.tail367da4.ts.net/api/v1/accounts/{{ $('Router with State').item.json.accountId }}/conversations/{{ $('Router with State').item.json.conversationId }}/custom_attributes",
            "authentication": "genericCredentialType",
            "genericAuthType": "httpHeaderAuth",
            "sendBody": True,
            "bodyParameters": {
                "parameters": [
                    {
                        "name": "custom_attributes[bot_state]",
                        "value": "region_asked"
                    }
                ]
            }
        }
    }

    workflow['nodes'].append(set_state_node)
    print("\n1️⃣  Added: Set State: region_asked")

    # 2. Rewire: AHA2 → Set State (not Parse Region)
    connections['AHA2 - Region Selection'] = {
        'main': [[{'node': 'Set State: region_asked', 'type': 'main', 'index': 0}]]
    }
    print("   ✅ AHA2 - Region Selection → Set State: region_asked → END")

    # 3. Set State has no output (workflow ends here)
    connections['Set State: region_asked'] = {
        'main': [[]]  # Empty - workflow ends
    }

    # 4. Update Router to detect "region_asked" state and route to Parse Region
    router_node = next((n for n in workflow['nodes'] if n['name'] == 'Router with State'), None)
    if router_node:
        code = router_node['parameters']['jsCode']

        # Add region response detection logic
        region_detection = """
// ============================================================
// Region Selection Response (after AHA2)
// ============================================================
if (customAttrs.bot_state === 'region_asked') {
  console.log('Handling region selection response');

  // Check if this is a Quick Reply response
  if (messageType === 'incoming') {
    route = 'REGION_RESPONSE';
    // Don't change state here - Parse Region will handle it
    console.log('Route: REGION_RESPONSE');
  }
}

"""

        # Insert after the console.log section (around line 15)
        lines = code.split('\n')
        insert_pos = None
        for i, line in enumerate(lines):
            if "console.log('==========================================');" in line and i > 10:
                insert_pos = i + 1
                break

        if insert_pos:
            lines.insert(insert_pos, region_detection)
            router_node['parameters']['jsCode'] = '\n'.join(lines)
            print("\n2️⃣  Updated Router with region response detection")

    # 5. Add "Is Region Response?" node after Router
    is_region_node = {
        "id": "is-region-response",
        "name": "Is Region Response?",
        "type": "n8n-nodes-base.if",
        "typeVersion": 2,
        "position": [800, 600],
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
                        "id": "region-route",
                        "leftValue": "={{ $json.route }}",
                        "rightValue": "REGION_RESPONSE",
                        "operator": {
                            "type": "string",
                            "operation": "equals"
                        }
                    }
                ]
            }
        }
    }

    workflow['nodes'].append(is_region_node)
    print("   ✅ Added: Is Region Response? node")

    # 6. Connect Router → Is Region Response?
    # Find current Router connections
    router_connections = connections.get('Router with State', {}).get('main', [[]])

    # Add Is Region Response? to Router's output
    if router_connections and len(router_connections) > 0:
        # Insert at the beginning of the first branch
        router_connections[0].insert(0, {'node': 'Is Region Response?', 'type': 'main', 'index': 0})
    else:
        router_connections = [[{'node': 'Is Region Response?', 'type': 'main', 'index': 0}]]

    connections['Router with State']['main'] = router_connections

    # 7. Connect Is Region Response? → Parse Region Selection (TRUE)
    connections['Is Region Response?'] = {
        'main': [
            [{'node': 'Parse Region Selection', 'type': 'main', 'index': 0}],  # TRUE
            []  # FALSE - continue to next check
        ]
    }
    print("   ✅ Router → Is Region Response? → Parse Region Selection")

    # 8. Update Parse Region Selection to handle both Quick Reply response formats
    parse_region_node = next((n for n in workflow['nodes'] if n['name'] == 'Parse Region Selection'), None)
    if parse_region_node:
        parse_region_node['parameters']['jsCode'] = """// Parse region selection from Quick Reply response
const data = $json.body || $json;
const content = (data.content || '').toLowerCase().trim();
const contentAttrs = data.content_attributes || {};
const interactive = contentAttrs.interactive_data?.data?.['quick-reply'] || {};

console.log('Parsing region selection...');
console.log('Content:', content);
console.log('Interactive data:', JSON.stringify(interactive));

// Map region selection from either content or interactive data
let region = 'unknown';

// Check interactive data first (more reliable)
if (interactive.value) {
  const value = interactive.value.toLowerCase();
  if (value === 'americas') region = 'Americas';
  else if (value === 'emea') region = 'EMEA';
  else if (value === 'apac') region = 'APAC';
}
// Fallback to content text
else if (content.includes('americas') || content === 'americas') {
  region = 'Americas';
} else if (content.includes('emea') || content === 'emea') {
  region = 'EMEA';
} else if (content.includes('apac') || content === 'apac') {
  region = 'APAC';
}

console.log('Region parsed:', region);

return {
  json: {
    accountId: data.conversation?.account_id,
    conversationId: data.conversation?.id,
    region: region,
    userId: data.sender?.id
  }
};"""
        print("   ✅ Updated Parse Region Selection to handle interactive data")

    # Save
    if not output_path:
        output_path = input_path.replace('.json', '-STATE-FIXED.json')

    with open(output_path, 'w') as f:
        json.dump(workflow, f, indent=2)

    print("\n" + "="*70)
    print("✅ STATE MACHINE FIXED!")
    print("="*70)
    print(f"\n🎯 Correct Flow Now:")
    print(f"  1. User: 'start'")
    print(f"  2. Router → Welcome → Region Selection (Quick Reply)")
    print(f"  3. Set State: region_asked → END WORKFLOW ⭐")
    print(f"  4. User selects region")
    print(f"  5. Webhook triggers again ⭐")
    print(f"  6. Router detects state='region_asked' → REGION_RESPONSE")
    print(f"  7. Is Region Response? → Parse Region Selection")
    print(f"  8. Update Region → Confirmation → Form")

    print(f"\n💾 Saved to: {output_path}")
    print("="*70 + "\n")

    return output_path

if __name__ == '__main__':
    import sys

    input_file = sys.argv[1] if len(sys.argv) > 1 else 'Acoustic-House-Bot-FINAL.json'
    output_file = sys.argv[2] if len(sys.argv) > 2 else None

    fix_state_machine(input_file, output_file)
