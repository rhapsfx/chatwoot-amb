#!/usr/bin/env node

/**
 * Import n8n Workflow via API with Connection Verification
 *
 * This script uses n8n's REST API to create a workflow programmatically,
 * then verifies that all connections were preserved.
 *
 * Prerequisites:
 * 1. Set N8N_API_KEY environment variable
 * 2. Set N8N_BASE_URL (default: http://localhost:5678)
 *
 * Usage:
 *   export N8N_API_KEY="your-api-key-here"
 *   node import-via-api.js
 */

const fs = require('fs');
const https = require('https');
const http = require('http');

// Configuration
const API_KEY = process.env.N8N_API_KEY;
const BASE_URL = process.env.N8N_BASE_URL || 'http://localhost:5678';
const WORKFLOW_FILE = './Acoustic-House-Bot-FINAL-v2-NAME-BASED-FIXED.json';

if (!API_KEY) {
  console.error('ERROR: N8N_API_KEY environment variable not set');
  console.error('');
  console.error('Set it with:');
  console.error('  export N8N_API_KEY="your-api-key-here"');
  console.error('');
  console.error('You can get your API key from n8n:');
  console.error('  Settings → API → Create new API key');
  process.exit(1);
}

console.log('Reading workflow from:', WORKFLOW_FILE);
const workflow = JSON.parse(fs.readFileSync(WORKFLOW_FILE, 'utf8'));

console.log(`Workflow: ${workflow.name}`);
console.log(`Nodes: ${workflow.nodes.length}`);
console.log(`Connections: ${Object.keys(workflow.connections).length}`);
console.log('');

// Helper function to make HTTP requests
function makeRequest(url, options, postData = null) {
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

    if (postData) {
      req.write(JSON.stringify(postData));
    }
    req.end();
  });
}

// Helper function to count connections
function countConnections(connectionsObj) {
  let count = 0;
  for (const sourceId in connectionsObj) {
    const outputs = connectionsObj[sourceId];
    for (const outputType in outputs) {
      const outputArray = outputs[outputType];
      if (Array.isArray(outputArray)) {
        for (const connections of outputArray) {
          count += connections.length;
        }
      }
    }
  }
  return count;
}

// Helper function to get detailed connection info
function getConnectionDetails(connectionsObj) {
  const details = [];
  for (const sourceId in connectionsObj) {
    const outputs = connectionsObj[sourceId];
    for (const outputType in outputs) {
      const outputArray = outputs[outputType];
      if (Array.isArray(outputArray)) {
        outputArray.forEach((connections, index) => {
          connections.forEach(conn => {
            details.push({
              source: sourceId,
              target: conn.node,
              type: outputType,
              index: index
            });
          });
        });
      }
    }
  }
  return details;
}

async function main() {
  try {
    // Prepare the workflow payload
    const payload = {
      name: workflow.name,
      nodes: workflow.nodes,
      connections: workflow.connections,
      settings: workflow.settings || {},
      staticData: workflow.staticData || null
    };

    // Create workflow
    console.log('Creating workflow via API...');
    const createUrl = new URL('/api/v1/workflows', BASE_URL);
    const createOptions = {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-N8N-API-KEY': API_KEY
      }
    };

    const result = await makeRequest(createUrl, createOptions, payload);

    console.log('✅ Workflow created successfully!');
    console.log('');
    console.log('Workflow ID:', result.id);
    console.log('Name:', result.name);
    console.log('');

    // Verify workflow by fetching it back
    console.log('Verifying workflow connections...');
    const verifyUrl = new URL(`/api/v1/workflows/${result.id}`, BASE_URL);
    const verifyOptions = {
      method: 'GET',
      headers: {
        'X-N8N-API-KEY': API_KEY
      }
    };

    const verified = await makeRequest(verifyUrl, verifyOptions);

    // Count connections
    const expectedConnections = countConnections(workflow.connections);
    const actualConnections = countConnections(verified.connections || {});

    console.log('');
    console.log('=== VERIFICATION RESULTS ===');
    console.log('');
    console.log('Nodes:');
    console.log(`  Expected: ${workflow.nodes.length}`);
    console.log(`  Actual:   ${verified.nodes.length}`);
    console.log(`  Status:   ${workflow.nodes.length === verified.nodes.length ? '✅ MATCH' : '❌ MISMATCH'}`);
    console.log('');
    console.log('Connections:');
    console.log(`  Expected: ${expectedConnections}`);
    console.log(`  Actual:   ${actualConnections}`);
    console.log(`  Status:   ${expectedConnections === actualConnections ? '✅ MATCH' : '❌ MISMATCH'}`);
    console.log('');

    if (actualConnections === 0 && expectedConnections > 0) {
      console.error('❌ CRITICAL: All connections were lost during import!');
      console.error('');
      console.error('This means n8n API is still regenerating node IDs.');
      console.error('');
      console.error('Expected connection sources:', Object.keys(workflow.connections).length);
      console.error('Actual connection sources:', Object.keys(verified.connections || {}).length);
      console.error('');

      // Show first 5 expected connections
      const expectedDetails = getConnectionDetails(workflow.connections);
      console.error('First 5 expected connections:');
      expectedDetails.slice(0, 5).forEach((conn, i) => {
        console.error(`  ${i + 1}. ${conn.source.substring(0, 8)}... → ${conn.target.substring(0, 8)}...`);
      });
      console.error('');

      // Check if any node IDs match
      const expectedNodeIds = new Set(workflow.nodes.map(n => n.id));
      const actualNodeIds = new Set(verified.nodes.map(n => n.id));
      const matchingIds = [...expectedNodeIds].filter(id => actualNodeIds.has(id));

      console.error('Node ID preservation:');
      console.error(`  Matching IDs: ${matchingIds.length} / ${expectedNodeIds.size}`);

      if (matchingIds.length === 0) {
        console.error('');
        console.error('❌ CONFIRMED: n8n API regenerated ALL node IDs');
        console.error('');
        console.error('Sample expected node IDs:');
        [...expectedNodeIds].slice(0, 3).forEach(id => {
          console.error(`  - ${id}`);
        });
        console.error('');
        console.error('Sample actual node IDs:');
        [...actualNodeIds].slice(0, 3).forEach(id => {
          console.error(`  - ${id}`);
        });
      }

      process.exit(1);
    } else if (actualConnections < expectedConnections) {
      console.warn('⚠️  WARNING: Some connections were lost during import!');
      console.warn('');

      // Show missing connections
      const expectedDetails = getConnectionDetails(workflow.connections);
      const actualDetails = getConnectionDetails(verified.connections || {});

      const actualSet = new Set(actualDetails.map(c => `${c.source}→${c.target}`));
      const missing = expectedDetails.filter(c => !actualSet.has(`${c.source}→${c.target}`));

      console.warn(`Missing connections: ${missing.length}`);
      console.warn('First 10 missing:');
      missing.slice(0, 10).forEach((conn, i) => {
        console.warn(`  ${i + 1}. ${conn.source.substring(0, 8)}... → ${conn.target.substring(0, 8)}...`);
      });

      process.exit(1);
    } else {
      console.log('✅ All connections preserved successfully!');
      console.log('');
      console.log('Next steps:');
      console.log('1. Open n8n and verify the workflow visually');
      console.log('2. Activate the workflow');
      console.log('3. Test form submission → guitar list flow');
    }

  } catch (error) {
    console.error('');
    console.error('❌ Error:', error.message);
    process.exit(1);
  }
}

main();
