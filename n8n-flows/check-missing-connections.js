#!/usr/bin/env node

const fs = require('fs');

const sourceFile = './Acoustic-House-Bot-FINAL-v2-NAME-BASED.json';
const workflow = JSON.parse(fs.readFileSync(sourceFile, 'utf8'));

const disconnected = [
  'Location Request',
  'AHB1_2 - Parse Text Name',
  'AHC1 - Guitar Picker Catcher',
  'AHC1 - Increment Retry Count',
  'AHC1 - Should Prompt?',
  'AHF1 - Apple Pay Catcher',
  'AHH1 - Time Picker Catcher',
  'Store Locator - Geocoding',
  'Is Guitar Response?',
  'Is Name Selection Response?'
];

console.log('=== CHECKING SOURCE FILE CONNECTIONS ===\n');
console.log(`Source: ${sourceFile}\n`);

disconnected.forEach(nodeName => {
  const hasOutgoing = workflow.connections[nodeName] !== undefined;

  let hasIncoming = false;
  for (const [source, outputs] of Object.entries(workflow.connections)) {
    for (const outputType in outputs) {
      const outputArray = outputs[outputType];
      for (const connArray of outputArray) {
        for (const conn of connArray) {
          if (conn.node === nodeName) {
            hasIncoming = true;
            console.log(`  ← Connected FROM: "${source}" (${outputType} output)`);
          }
        }
      }
    }
  }

  console.log(`"${nodeName}":`);
  console.log(`  Outgoing connections: ${hasOutgoing ? '✅ YES' : '❌ NO'}`);
  console.log(`  Incoming connections: ${hasIncoming ? '✅ YES' : '❌ NO'}`);

  if (hasOutgoing) {
    const outputs = workflow.connections[nodeName];
    for (const outputType in outputs) {
      const outputArray = outputs[outputType];
      for (const connArray of outputArray) {
        for (const conn of connArray) {
          console.log(`  → Connects TO: "${conn.node}" (${outputType} output)`);
        }
      }
    }
  }

  console.log();
});

console.log('\n=== SUMMARY ===');
console.log(`Total connection sources in file: ${Object.keys(workflow.connections).length}`);
console.log(`Total nodes in file: ${workflow.nodes.length}`);
