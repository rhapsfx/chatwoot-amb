#!/usr/bin/env node

const fs = require('fs');

console.log('Reading fixed workflow...');
const workflow = JSON.parse(fs.readFileSync('fixed-workflow-correct.json', 'utf8'));

console.log('Extracting only required fields for n8n API...');
const payload = {
  name: workflow.name,
  nodes: workflow.nodes,
  connections: workflow.connections,
  settings: workflow.settings || {},
  staticData: workflow.staticData || null
};

console.log('Writing deployment payload...');
fs.writeFileSync('deploy-payload.json', JSON.stringify(payload, null, 2));

console.log('✓ Deployment payload ready');
console.log('  - name:', payload.name);
console.log('  - nodes:', payload.nodes.length);
console.log('  - connections:', Object.keys(payload.connections).length);
