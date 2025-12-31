#!/usr/bin/env node

const fs = require('fs');

const workflowFile = './Acoustic-House-Bot-FINAL-v2-NAME-BASED.json';
const workflow = JSON.parse(fs.readFileSync(workflowFile, 'utf8'));

// Find the Router with State node
const routerNode = workflow.nodes.find(n => n.name === 'Router with State');

if (!routerNode) {
  console.error('❌ Could not find "Router with State" node');
  process.exit(1);
}

console.log('✅ Found Router with State node\n');

// The fix: Change the quick reply handler for region to set REGION_RESPONSE instead of REGION_SELECTED
const oldCode = routerNode.parameters.jsCode;

// Replace the region handler in quick_reply section
const fixedCode = oldCode.replace(
  /if \(reply\.includes\('region_'\)\) \{\s*route = 'REGION_SELECTED';/g,
  `if (reply.includes('region_')) {
    route = 'REGION_RESPONSE';  // Fixed: Use same route as state-based handler`
);

// Also update the isRegionSelected flag to check for REGION_RESPONSE
const finalCode = fixedCode.replace(
  /isRegionSelected: route === 'REGION_SELECTED',/g,
  `isRegionSelected: route === 'REGION_RESPONSE',  // Fixed: Match the route name`
);

routerNode.parameters.jsCode = finalCode;

// Save the fixed workflow
const outputFile = './Acoustic-House-Bot-FINAL-v2-NAME-BASED-FIXED.json';
fs.writeFileSync(outputFile, JSON.stringify(workflow, null, 2));

console.log('✅ Fixed region response routing');
console.log('✅ Updated isRegionSelected flag');
console.log(`✅ Saved to: ${outputFile}\n`);

console.log('Changes made:');
console.log('1. Quick reply "region_*" now sets route = "REGION_RESPONSE"');
console.log('2. isRegionSelected flag now checks for "REGION_RESPONSE"');
console.log('\nThis ensures the workflow takes the correct path:');
console.log('  Router → Is Region Response? → Parse Region → ... → Form Direct Send');
