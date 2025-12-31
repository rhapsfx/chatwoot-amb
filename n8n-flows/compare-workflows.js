#!/usr/bin/env node

/**
 * Compare Source JSON vs n8n Stored Workflow
 *
 * Checks if connections structure matches between source file and stored workflow
 */

const fs = require('fs');
const https = require('https');
const http = require('http');

const API_KEY = process.env.N8N_API_KEY;
const BASE_URL = process.env.N8N_BASE_URL || 'http://localhost:5678';
const SOURCE_FILE = './Acoustic-House-Bot-FINAL-v2-FIXED.json';
const WORKFLOW_ID = process.argv[2];

if (!WORKFLOW_ID) {
  console.error('Usage: node compare-workflows.js <workflow-id>');
  process.exit(1);
}

function makeRequest(url, options) {
  return new Promise((resolve, reject) => {
    const client = url.protocol === 'https:' ? https : http;
    const req = client.request(url, options, (res) => {
      let data = '';
      res.on('data', (chunk) => { data += chunk; });
      res.on('end', () => {
        if (res.statusCode >= 200 && res.statusCode < 300) {
          resolve(JSON.parse(data));
        } else {
          reject(new Error(`HTTP ${res.statusCode}: ${data}`));
        }
      });
    });
    req.on('error', reject);
    req.end();
  });
}

function analyzeConnectionStructure(connections, label) {
  console.log(`\n=== ${label} CONNECTION STRUCTURE ===\n`);

  let totalEdges = 0;
  const sample = [];

  for (const sourceId in connections) {
    const outputs = connections[sourceId];

    // Show structure of first connection source
    if (sample.length === 0) {
      console.log('First connection source structure:');
      console.log(`  Source ID: ${sourceId}`);
      console.log(`  Outputs object keys: ${Object.keys(outputs).join(', ')}`);

      for (const outputType in outputs) {
        const outputArray = outputs[outputType];
        console.log(`\n  Output type: "${outputType}"`);
        console.log(`  Is array: ${Array.isArray(outputArray)}`);
        console.log(`  Array length: ${outputArray ? outputArray.length : 'N/A'}`);

        if (Array.isArray(outputArray) && outputArray.length > 0) {
          console.log(`  First element: ${JSON.stringify(outputArray[0], null, 2)}`);
        }
      }
    }

    // Count edges
    for (const outputType in outputs) {
      const outputArray = outputs[outputType];
      if (Array.isArray(outputArray)) {
        outputArray.forEach(connArray => {
          totalEdges += connArray.length;

          if (sample.length < 3) {
            connArray.forEach(conn => {
              sample.push({
                source: sourceId.substring(0, 8),
                target: conn.node.substring(0, 8),
                outputType,
                inputType: conn.type,
                inputIndex: conn.index
              });
            });
          }
        });
      }
    }
  }

  console.log(`\nTotal connection edges: ${totalEdges}`);
  console.log(`Connection sources: ${Object.keys(connections).length}`);
  console.log(`\nFirst 3 connections:`);
  sample.slice(0, 3).forEach((conn, i) => {
    console.log(`  ${i + 1}. ${conn.source}... → ${conn.target}... (${conn.outputType}/${conn.inputType}[${conn.inputIndex}])`);
  });
}

async function main() {
  try {
    // Read source file
    console.log('Reading source file:', SOURCE_FILE);
    const source = JSON.parse(fs.readFileSync(SOURCE_FILE, 'utf8'));

    // Fetch stored workflow
    console.log('Fetching stored workflow:', WORKFLOW_ID);
    const url = new URL(`/api/v1/workflows/${WORKFLOW_ID}`, BASE_URL);
    const options = {
      method: 'GET',
      headers: { 'X-N8N-API-KEY': API_KEY }
    };
    const stored = await makeRequest(url, options);

    // Analyze source connections
    analyzeConnectionStructure(source.connections, 'SOURCE FILE');

    // Analyze stored connections
    analyzeConnectionStructure(stored.connections || {}, 'STORED WORKFLOW');

    // Deep comparison
    console.log('\n=== DEEP COMPARISON ===\n');

    const sourceJSON = JSON.stringify(source.connections, null, 2);
    const storedJSON = JSON.stringify(stored.connections, null, 2);

    if (sourceJSON === storedJSON) {
      console.log('✅ Connections are IDENTICAL (byte-for-byte match)');
      console.log('\nThis means n8n stored the connections correctly in the database.');
      console.log('The problem must be in n8n\'s runtime execution engine.');
      console.log('\nPossible causes:');
      console.log('1. Workflow needs to be saved/activated differently');
      console.log('2. n8n has internal indexes that weren\'t updated');
      console.log('3. Database transaction issue');
    } else {
      console.log('❌ Connections are DIFFERENT');
      console.log('\nn8n modified the connections structure during storage.');
      console.log('Analyzing differences...\n');

      // Check if connections object is empty
      if (!stored.connections || Object.keys(stored.connections).length === 0) {
        console.error('❌ CRITICAL: Stored workflow has EMPTY connections object!');
        console.error('\nThis means n8n API did NOT actually store the connections.');
        console.error('The GET response was showing the connections from the payload,');
        console.error('not from the database.');
      }

      // Show first difference
      const sourceKeys = Object.keys(source.connections).sort();
      const storedKeys = Object.keys(stored.connections || {}).sort();

      console.log('Source connection sources:', sourceKeys.length);
      console.log('Stored connection sources:', storedKeys.length);

      if (sourceKeys.length !== storedKeys.length) {
        console.log('\n❌ Different number of connection sources!');

        const missingInStored = sourceKeys.filter(k => !storedKeys.includes(k));
        const extraInStored = storedKeys.filter(k => !sourceKeys.includes(k));

        if (missingInStored.length > 0) {
          console.log(`\nMissing in stored (first 5):`);
          missingInStored.slice(0, 5).forEach(k => {
            console.log(`  ${k.substring(0, 8)}...`);
          });
        }

        if (extraInStored.length > 0) {
          console.log(`\nExtra in stored (first 5):`);
          extraInStored.slice(0, 5).forEach(k => {
            console.log(`  ${k.substring(0, 8)}...`);
          });
        }
      }
    }

  } catch (error) {
    console.error('\n❌ Error:', error.message);
    process.exit(1);
  }
}

main();
