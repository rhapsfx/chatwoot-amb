#!/usr/bin/env node

/**
 * Fix n8n Workflow IDs
 *
 * This script:
 * 1. Reads the source JSON workflow file
 * 2. Generates proper UUIDs for all nodes
 * 3. Updates all connection references to use new UUIDs
 * 4. Writes a new JSON file that n8n can properly import
 *
 * Usage: node fix-workflow-ids.js
 */

const fs = require('fs');
const crypto = require('crypto');

// Generate UUID v4
function generateUUID() {
  return crypto.randomUUID();
}

// Read source workflow
const sourceFile = './Acoustic-House-Bot-FINAL-v2.json';
const outputFile = './Acoustic-House-Bot-FINAL-v2-FIXED.json';

console.log('Reading source workflow...');
const workflow = JSON.parse(fs.readFileSync(sourceFile, 'utf8'));

// Create ID mappings:
// 1. old ID → new UUID (for node updates)
// 2. node name → new UUID (for connection lookups)
const idMapping = {};
const nameMapping = {};

console.log(`\nProcessing ${workflow.nodes.length} nodes...`);

// Step 1: Generate new UUIDs for all nodes
workflow.nodes.forEach((node, index) => {
  const oldId = node.id;
  const nodeName = node.name;
  const newId = generateUUID();

  idMapping[oldId] = newId;
  nameMapping[nodeName] = newId;
  node.id = newId;

  if (index < 10) {
    console.log(`  ${oldId} (${nodeName}) → ${newId}`);
  } else if (index === 10) {
    console.log(`  ... (${workflow.nodes.length - 10} more nodes)`);
  }
});

console.log(`\nID mapping created for ${Object.keys(idMapping).length} nodes`);
console.log(`Name mapping created for ${Object.keys(nameMapping).length} nodes`);

// Step 2: Update all connections to use new UUIDs
console.log('\nUpdating connections...');
const oldConnections = workflow.connections || {};
const newConnections = {};

let connectionCount = 0;
let updatedCount = 0;

Object.entries(oldConnections).forEach(([sourceId, outputs]) => {
  // Try both ID lookup and name lookup
  const newSourceId = idMapping[sourceId] || nameMapping[sourceId];

  if (!newSourceId) {
    console.warn(`  WARNING: Source node "${sourceId}" not found in mappings`);
    return;
  }

  // Update each output connection
  const updatedOutputs = {};

  Object.entries(outputs).forEach(([outputType, connections]) => {
    updatedOutputs[outputType] = connections.map(connArray => {
      return connArray.map(conn => {
        connectionCount++;
        // Try both ID lookup and name lookup for target
        const newTargetId = idMapping[conn.node] || nameMapping[conn.node];

        if (!newTargetId) {
          console.warn(`  WARNING: Target node "${conn.node}" not found in mappings`);
          return conn;
        }

        updatedCount++;
        return {
          ...conn,
          node: newTargetId
        };
      });
    });
  });

  newConnections[newSourceId] = updatedOutputs;
});

workflow.connections = newConnections;

console.log(`\nConnections processed: ${connectionCount}`);
console.log(`Connections updated: ${updatedCount}`);
console.log(`Success rate: ${((updatedCount/connectionCount) * 100).toFixed(1)}%`);

// Step 3: Write fixed workflow
console.log(`\nWriting fixed workflow to ${outputFile}...`);
fs.writeFileSync(outputFile, JSON.stringify(workflow, null, 2));

console.log('\n✅ Workflow fixed successfully!');
console.log('\nNext steps:');
console.log('1. Delete the existing workflow in n8n');
console.log(`2. Import the new file: ${outputFile}`);
console.log('3. Activate and test');

// Generate summary report
console.log('\n=== Summary Report ===');
console.log(`Total nodes: ${workflow.nodes.length}`);
console.log(`Total connections: ${updatedCount}`);
console.log(`Connection sources: ${Object.keys(newConnections).length}`);

// List some key nodes to verify
console.log('\n=== Key Nodes (Form Response Flow) ===');
const keyNodes = [
  'Is Form Response?',
  'AHB1 - Parse Form Response',
  'Has Stage Name?',
  'Update Name Attributes',
  'AHB3 - Personalized Greeting',
  'AMB Guitar List'
];

workflow.nodes.forEach(node => {
  if (keyNodes.includes(node.name)) {
    console.log(`  ${node.name}: ${node.id}`);
  }
});
