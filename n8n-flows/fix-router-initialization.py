#!/usr/bin/env python3
"""
Fix Router variable initialization order.

The region detection code runs BEFORE route is declared.
We need to move it AFTER the route declaration.
"""

import json

def fix_router_initialization(input_path: str, output_path: str = None):
    """Fix the Router variable initialization order."""

    with open(input_path, 'r') as f:
        workflow = json.load(f)

    print("="*70)
    print("FIXING ROUTER VARIABLE INITIALIZATION")
    print("="*70)

    # Find Router node
    router_node = next((n for n in workflow['nodes'] if n['name'] == 'Router with State'), None)

    if not router_node:
        print("❌ Router node not found!")
        return

    code = router_node['parameters']['jsCode']

    # Split into lines
    lines = code.split('\n')

    # Find the region detection block (starts with "// ============================================================")
    region_block_start = None
    region_block_end = None

    for i, line in enumerate(lines):
        if '// Region Selection Response (after AHA2)' in line:
            # Find the start (previous line with ====)
            region_block_start = i - 1
        elif region_block_start and 'if (customAttrs.bot_state' in line and 'region_asked' in line:
            # Find the end of this block
            brace_count = 0
            for j in range(i, len(lines)):
                if '{' in lines[j]:
                    brace_count += lines[j].count('{')
                if '}' in lines[j]:
                    brace_count -= lines[j].count('}')
                if brace_count == 0 and '}' in lines[j]:
                    region_block_end = j + 1
                    break
            break

    if region_block_start is None or region_block_end is None:
        print("❌ Could not find region detection block!")
        return

    # Extract the region detection block
    region_block = lines[region_block_start:region_block_end]

    # Remove the region block from its current position
    lines = lines[:region_block_start] + lines[region_block_end:]

    # Find where "let route = 'UNKNOWN';" is declared
    route_declaration_line = None
    for i, line in enumerate(lines):
        if "let route = 'UNKNOWN';" in line:
            route_declaration_line = i
            break

    if route_declaration_line is None:
        print("❌ Could not find route declaration!")
        return

    print(f"\n1️⃣  Found region block at lines {region_block_start}-{region_block_end}")
    print(f"2️⃣  Found route declaration at line {route_declaration_line}")

    # Insert the region block AFTER route declaration (after nextState line)
    insert_position = route_declaration_line + 2  # After "let nextState = ..."

    # Add blank line before region block
    lines.insert(insert_position, '')
    lines[insert_position+1:insert_position+1] = region_block

    # Update the router code
    router_node['parameters']['jsCode'] = '\n'.join(lines)

    print(f"3️⃣  Moved region block to line {insert_position}")
    print(f"   ✅ Now AFTER route variable declaration")

    # Save
    if not output_path:
        output_path = input_path.replace('.json', '-ROUTER-FIXED.json')

    with open(output_path, 'w') as f:
        json.dump(workflow, f, indent=2)

    print("\n" + "="*70)
    print("✅ ROUTER INITIALIZATION FIXED!")
    print("="*70)
    print(f"\n🔧 Code execution order now:")
    print(f"  1. Declare variables")
    print(f"  2. Skip outgoing messages")
    print(f"  3. let route = 'UNKNOWN';")
    print(f"  4. let nextState = ...;")
    print(f"  5. Check region_asked state ⭐ NOW HERE")
    print(f"  6. Handle list picker selections")
    print(f"  7. Handle other routes")

    print(f"\n💾 Saved to: {output_path}")
    print("="*70 + "\n")

    return output_path

if __name__ == '__main__':
    import sys

    input_file = sys.argv[1] if len(sys.argv) > 1 else 'Acoustic-House-Bot-FINAL-v2.json'
    output_file = sys.argv[2] if len(sys.argv) > 2 else None

    fix_router_initialization(input_file, output_file)
