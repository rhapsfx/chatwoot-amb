#!/usr/bin/env python3
"""
Fix form response interactive_type detection.

Problem: Apple Messages for Business sends form responses with
interactive_type = 'apple_form_response', but the Router checks for 'form'.

Fix: Update the check to handle both 'form' and 'apple_form_response'.
"""

import json
import sys

def fix_interactive_type(workflow):
    """Fix interactive_type detection in Router with State node."""

    # Find Router with State node
    router_node = next((n for n in workflow['nodes']
                       if n['name'] == 'Router with State'), None)

    if not router_node:
        print("❌ Could not find 'Router with State' node")
        return False

    print("✅ Found 'Router with State' node")

    # Get current code
    current_code = router_node['parameters']['jsCode']

    # Find the form interactive_type check
    old_check = "else if (contentAttrs.interactive_type === 'form') {"

    # New check that handles both values
    new_check = "else if (contentAttrs.interactive_type === 'form' || contentAttrs.interactive_type === 'apple_form_response') {"

    if old_check not in current_code:
        print("❌ Could not find expected interactive_type check")
        print("   The code may have already been modified")
        return False

    # Apply fix
    updated_code = current_code.replace(old_check, new_check)
    router_node['parameters']['jsCode'] = updated_code

    print("✅ Updated interactive_type detection:")
    print("   - Before: contentAttrs.interactive_type === 'form'")
    print("   - After:  contentAttrs.interactive_type === 'form' || contentAttrs.interactive_type === 'apple_form_response'")

    return True

def main(input_path, output_path=None):
    """Fix interactive_type detection for Apple form responses."""

    with open(input_path, 'r') as f:
        workflow = json.load(f)

    print("=" * 70)
    print("FIXING FORM INTERACTIVE_TYPE DETECTION")
    print("=" * 70)
    print()

    success = fix_interactive_type(workflow)

    if not success:
        print("\n❌ Fix failed - see errors above")
        return None

    # Save
    if not output_path:
        output_path = input_path.replace('.json', '-INTERACTIVE-TYPE.json')

    with open(output_path, 'w') as f:
        json.dump(workflow, f, indent=2)

    print("\n" + "=" * 70)
    print("✅ INTERACTIVE_TYPE FIX APPLIED")
    print("=" * 70)
    print("\n📋 What changed:")
    print("   Router with State → Form Interactive Type Detection")
    print("   - Now detects both:")
    print("     • 'form' (legacy/generic)")
    print("     • 'apple_form_response' (Apple Messages for Business)")
    print("\n🔄 This ensures Apple form responses are properly routed")
    print(f"\n💾 Saved to: {output_path}")
    print("=" * 70 + "\n")

    return output_path

if __name__ == '__main__':
    input_file = sys.argv[1] if len(sys.argv) > 1 else 'Acoustic-House-Bot-FINAL-v2.json'
    output_file = sys.argv[2] if len(sys.argv) > 2 else None

    main(input_file, output_file)
