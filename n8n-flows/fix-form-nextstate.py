#!/usr/bin/env python3
"""
Fix form response nextState issue.

Problem: When bot_state is 'form_shown' and a form response comes in,
the state-based detection sets route but doesn't set nextState.

Fix: Add nextState = 'form_submitted' to the state-based form detection.
"""

import json
import sys

def fix_form_nextstate(workflow):
    """Fix form response nextState in Router with State node."""

    # Find Router with State node
    router_node = next((n for n in workflow['nodes']
                       if n['name'] == 'Router with State'), None)

    if not router_node:
        print("❌ Could not find 'Router with State' node")
        return False

    print("✅ Found 'Router with State' node")

    # Get current code
    current_code = router_node['parameters']['jsCode']

    # Find the form response detection block
    form_block = """if (customAttrs.bot_state === 'form_shown') {
  console.log('Handling form response');

  // Check if this is an incoming message (form submission)
  if (messageType === 'incoming') {
    route = 'FORM_RESPONSE';
    // Don't change state here - Parse Form will handle it
    console.log('Route: FORM_RESPONSE');
  }
}"""

    # Replace with fixed version
    fixed_block = """if (customAttrs.bot_state === 'form_shown') {
  console.log('Handling form response');

  // Check if this is an incoming message (form submission)
  if (messageType === 'incoming') {
    route = 'FORM_RESPONSE';
    nextState = 'form_submitted';  // Set nextState for form responses
    console.log('Route: FORM_RESPONSE');
  }
}"""

    if form_block not in current_code:
        print("❌ Could not find expected form detection block")
        print("   The code may have already been modified")
        return False

    # Apply fix
    updated_code = current_code.replace(form_block, fixed_block)
    router_node['parameters']['jsCode'] = updated_code

    print("✅ Updated form response detection:")
    print("   - Added: nextState = 'form_submitted'")

    return True

def main(input_path, output_path=None):
    """Fix form response nextState issue."""

    with open(input_path, 'r') as f:
        workflow = json.load(f)

    print("=" * 70)
    print("FIXING FORM RESPONSE NEXTSTATE")
    print("=" * 70)
    print()

    success = fix_form_nextstate(workflow)

    if not success:
        print("\n❌ Fix failed - see errors above")
        return None

    # Save
    if not output_path:
        output_path = input_path.replace('.json', '-FORM-NEXTSTATE.json')

    with open(output_path, 'w') as f:
        json.dump(workflow, f, indent=2)

    print("\n" + "=" * 70)
    print("✅ FORM NEXTSTATE FIX APPLIED")
    print("=" * 70)
    print("\n📋 What changed:")
    print("   Router with State → Form Response Detection")
    print("   - Before: route = 'FORM_RESPONSE' (nextState undefined)")
    print("   - After:  route = 'FORM_RESPONSE', nextState = 'form_submitted'")
    print("\n🔄 This ensures form responses always have a valid nextState")
    print(f"\n💾 Saved to: {output_path}")
    print("=" * 70 + "\n")

    return output_path

if __name__ == '__main__':
    input_file = sys.argv[1] if len(sys.argv) > 1 else 'Acoustic-House-Bot-FINAL-v2.json'
    output_file = sys.argv[2] if len(sys.argv) > 2 else None

    main(input_file, output_file)
