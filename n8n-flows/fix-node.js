#!/usr/bin/env node

const fs = require('fs');

console.log('Reading workflow...');
const workflow = JSON.parse(fs.readFileSync('current-workflow.json', 'utf8'));

console.log('Finding "Update Name Attributes" node...');
const nodeIndex = workflow.nodes.findIndex(n => n.id === '8cf92612-c5ba-4ab0-aa9b-aed4524ebca1');

if (nodeIndex < 0) {
  console.error('❌ Node not found!');
  process.exit(1);
}

console.log('✓ Found node at index', nodeIndex);
console.log();
console.log('Current URL:', workflow.nodes[nodeIndex].parameters.url);
console.log();

// CORRECT FIX: Reference "Router with State" for conversationId and accountId
// These are available in ALL flow paths (REGION_RESPONSE, NAME_SELECTION, etc.)
workflow.nodes[nodeIndex].parameters.url = '=https://mac-studio.tail367da4.ts.net/api/v1/accounts/{{ $("Router with State").item.json.accountId }}/conversations/{{ $("Router with State").item.json.conversationId }}/custom_attributes';

// Body parameters can still reference AHB1 - Parse Form Response because
// by the time this node runs (after "Has Stage Name?" IF node), the form
// response data is available
workflow.nodes[nodeIndex].parameters.bodyParameters.parameters = [
  { name: 'custom_attributes[user_name]', value: '={{ $("AHB1 - Parse Form Response").item.json.userName || "" }}' },
  { name: 'custom_attributes[stage_name]', value: '={{ $("AHB1 - Parse Form Response").item.json.stageName || "" }}' },
  { name: 'custom_attributes[selected_name]', value: '={{ $("AHB1 - Parse Form Response").item.json.stageName || $("AHB1 - Parse Form Response").item.json.userName || "" }}' }
];

console.log('New URL:', workflow.nodes[nodeIndex].parameters.url);
console.log();
console.log('✓ Node updated with correct references');
console.log();
console.log('Writing fixed workflow...');
fs.writeFileSync('fixed-workflow-correct.json', JSON.stringify(workflow, null, 2));
console.log('✓ Written to fixed-workflow-correct.json');
console.log();
console.log('Summary of fix:');
console.log('  - conversationId: Now from "Router with State" (was: "AHB1 - Parse Form Response")');
console.log('  - accountId: Now from "Router with State" (was: "AHB1 - Parse Form Response")');
console.log('  - userName/stageName: Still from "AHB1 - Parse Form Response" (correct)');
console.log();
console.log('Why this works:');
console.log('  - "Router with State" executes BEFORE all branching');
console.log('  - Available in REGION_RESPONSE, NAME_SELECTION, and all other flows');
console.log('  - Always has conversationId and accountId');
