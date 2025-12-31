#!/usr/bin/env python3
"""
Add Parse nodes for Payment Response and Time Response.

These nodes extract data from interactive message responses received via webhook.
"""

import json
import sys

def add_parse_payment_node(workflow):
    """Add Parse Payment Response node."""

    parse_payment_code = """// Parse Apple Pay Response
const data = $json.body || $json;
const contentAttrs = data.content_attributes || {};
const applePayData = contentAttrs.interactive_data?.data?.['apple-pay'] || {};

console.log('=== Parse Payment Response ===');
console.log('Apple Pay Data:', applePayData);

// Extract payment status
const paymentStatus = applePayData.status || 'unknown';
const transactionId = applePayData.transactionIdentifier || '';

// Extract billing/shipping info if present
const billingContact = applePayData.billingContact || {};
const shippingContact = applePayData.shippingContact || {};

console.log('Payment Status:', paymentStatus);
console.log('Transaction ID:', transactionId);

return {
  json: {
    ...($json || {}),
    paymentStatus: paymentStatus,
    transactionId: transactionId,
    billingContact: billingContact,
    shippingContact: shippingContact,
    conversationId: data.conversation?.id,
    accountId: data.account?.id || 1
  }
};"""

    parse_payment_node = {
        "parameters": {
            "jsCode": parse_payment_code
        },
        "type": "n8n-nodes-base.code",
        "typeVersion": 2,
        "position": [4000, 300],  # After Is Payment Response?
        "id": "parse-payment-response",
        "name": "Parse Payment Response"
    }

    workflow['nodes'].append(parse_payment_node)
    print("✅ Created Parse Payment Response node")

    return parse_payment_node

def add_parse_time_node(workflow):
    """Add Parse Time Response node."""

    parse_time_code = """// Parse Time Picker Response
const data = $json.body || $json;
const contentAttrs = data.content_attributes || {};
const timePickerData = contentAttrs.interactive_data?.data?.['time-picker'] || {};

console.log('=== Parse Time Response ===');
console.log('Time Picker Data:', timePickerData);

// Extract selected time slot
const selectedSlot = timePickerData.selectedItem || {};
const eventIdentifier = selectedSlot.identifier || '';
const eventTitle = selectedSlot.title || '';

// Parse the time from identifier or title
let selectedTime = '';
let selectedDate = '';

if (eventIdentifier) {
  // Format: "slot_YYYYMMDD_HHMM"
  const parts = eventIdentifier.split('_');
  if (parts.length >= 3) {
    selectedDate = parts[1];  // YYYYMMDD
    selectedTime = parts[2];  // HHMM
  }
}

console.log('Selected Date:', selectedDate);
console.log('Selected Time:', selectedTime);
console.log('Event Title:', eventTitle);

return {
  json: {
    ...($json || {}),
    selectedDate: selectedDate,
    selectedTime: selectedTime,
    eventTitle: eventTitle,
    eventIdentifier: eventIdentifier,
    conversationId: data.conversation?.id,
    accountId: data.account?.id || 1
  }
};"""

    parse_time_node = {
        "parameters": {
            "jsCode": parse_time_code
        },
        "type": "n8n-nodes-base.code",
        "typeVersion": 2,
        "position": [4000, 500],  # After Is Time Response?
        "id": "parse-time-response",
        "name": "Parse Time Response"
    }

    workflow['nodes'].append(parse_time_node)
    print("✅ Created Parse Time Response node")

    return parse_time_node

def add_connections(workflow, parse_payment_node, parse_time_node):
    """Add connections from conditional checks to parse nodes."""

    # Find the conditional check nodes
    payment_check_node = next((n for n in workflow['nodes'] if n['name'] == 'Is Payment Response?'), None)
    time_check_node = next((n for n in workflow['nodes'] if n['name'] == 'Is Time Response?'), None)

    if not payment_check_node or not time_check_node:
        print("⚠️  Could not find conditional check nodes")
        return

    # Add connection: Is Payment Response? [true] → Parse Payment Response
    if 'check-payment_response' not in workflow['connections']:
        workflow['connections']['check-payment_response'] = {"main": [[], []]}

    workflow['connections']['check-payment_response']['main'][0] = [
        {
            "node": "Parse Payment Response",
            "type": "main",
            "index": 0
        }
    ]

    # Add connection: Is Time Response? [true] → Parse Time Response
    if 'check-time_response' not in workflow['connections']:
        workflow['connections']['check-time_response'] = {"main": [[], []]}

    workflow['connections']['check-time_response']['main'][0] = [
        {
            "node": "Parse Time Response",
            "type": "main",
            "index": 0
        }
    ]

    print("✅ Added connections from conditional checks to parse nodes")

def main(input_path, output_path=None):
    """Add parse nodes to workflow."""

    with open(input_path, 'r') as f:
        workflow = json.load(f)

    print("=" * 70)
    print("ADDING PARSE NODES FOR INTERACTIVE RESPONSES")
    print("=" * 70)

    # Add parse nodes
    parse_payment_node = add_parse_payment_node(workflow)
    parse_time_node = add_parse_time_node(workflow)

    # Add connections
    add_connections(workflow, parse_payment_node, parse_time_node)

    # Save
    if not output_path:
        output_path = input_path.replace('.json', '-PARSE-NODES.json')

    with open(output_path, 'w') as f:
        json.dump(workflow, f, indent=2)

    print("\n" + "=" * 70)
    print("✅ PARSE NODES ADDED SUCCESSFULLY")
    print("=" * 70)
    print(f"\n📝 Summary:")
    print(f"   • Created Parse Payment Response node")
    print(f"   • Created Parse Time Response node")
    print(f"   • Connected conditional checks to parse nodes")

    print(f"\n💾 Saved to: {output_path}")
    print("=" * 70 + "\n")

    return output_path

if __name__ == '__main__':
    input_file = sys.argv[1] if len(sys.argv) > 1 else 'Acoustic-House-Bot-FINAL-v2.json'
    output_file = sys.argv[2] if len(sys.argv) > 2 else None

    main(input_file, output_file)
