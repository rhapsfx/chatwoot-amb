#!/usr/bin/env node

/**
 * Convert UUID-based connections to name-based connections
 *
 * This fixes the n8n import issue where connections use node IDs
 * instead of node names.
 */

const fs = require('fs');

const INPUT_FILE = './Acoustic-House-Bot-FINAL-v2-FIXED.json';
const OUTPUT_FILE = './Acoustic-House-Bot-FINAL-v2-NAME-BASED.json';

console.log('Reading workflow...');
const workflow = JSON.parse(fs.readFileSync(INPUT_FILE, 'utf8'));

// Build ID -> Name mapping
const idToName = {};
workflow.nodes.forEach(node => {
  idToName[node.id] = node.name;
});

console.log(`\nBuilt ID→Name mapping for ${Object.keys(idToName).length} nodes`);

// Convert connections from ID-based to name-based
const oldConnections = workflow.connections || {};
const newConnections = {};

let convertedCount = 0;
let totalConnections = 0;

for (const sourceId in oldConnections) {
  const sourceName = idToName[sourceId];

  if (!sourceName) {
    console.warn(`WARNING: Source node ID not found: ${sourceId}`);
    continue;
  }

  const outputs = oldConnections[sourceId];
  const newOutputs = {};

  for (const outputType in outputs) {
    const outputArray = outputs[outputType];

    newOutputs[outputType] = outputArray.map(connArray => {
      return connArray.map(conn => {
        totalConnections++;

        const targetName = idToName[conn.node];

        if (!targetName) {
          console.warn(`WARNING: Target node ID not found: ${conn.node}`);
          return conn;
        }

        convertedCount++;
        return {
          ...conn,
          node: targetName  // Convert ID to NAME
        };
      });
    });
  }

  // Use node NAME as key instead of ID
  newConnections[sourceName] = newOutputs;
}

workflow.connections = newConnections;

console.log(`\n=== CONVERSION RESULTS ===`);
console.log(`Total connections: ${totalConnections}`);
console.log(`Successfully converted: ${convertedCount}`);
console.log(`Success rate: ${((convertedCount/totalConnections) * 100).toFixed(1)}%`);
console.log('');
console.log(`Connection sources (ID-based): ${Object.keys(oldConnections).length}`);
console.log(`Connection sources (name-based): ${Object.keys(newConnections).length}`);
console.log('');

// Show first 3 conversions as examples
console.log('=== SAMPLE CONVERSIONS ===');
let count = 0;
for (const sourceName in newConnections) {
  if (count >= 3) break;

  const outputs = newConnections[sourceName];
  for (const outputType in outputs) {
    const outputArray = outputs[outputType];
    outputArray.forEach(connArray => {
      connArray.forEach(conn => {
        if (count < 3) {
          console.log(`  ${sourceName} → ${conn.node} (${outputType})`);
          count++;
        }
      });
    });
  }
}
console.log('');

// Write converted workflow
console.log(`Writing converted workflow to ${OUTPUT_FILE}...`);
fs.writeFileSync(OUTPUT_FILE, JSON.stringify(workflow, null, 2));

console.log('\n✅ Conversion complete!');
console.log('');
console.log('Next steps:');
console.log('1. Delete the UUID-based workflows from n8n');
console.log('2. Import this new name-based JSON via UI or API');
console.log('3. Connections should now work properly!');
