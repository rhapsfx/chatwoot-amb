#!/usr/bin/env node

/**
 * Force n8n to Re-Index Workflow Connections
 *
 * Makes a minimal update to force n8n to rebuild internal indexes
 * and recognize the connections.
 */

const https = require('https');
const http = require('http');
const fs = require('fs');

const API_KEY = process.env.N8N_API_KEY;
const BASE_URL = process.env.N8N_BASE_URL || 'http://localhost:5678';
const WORKFLOW_ID = process.argv[2];

if (!WORKFLOW_ID) {
  console.error('Usage: node force-reindex.js <workflow-id>');
  process.exit(1);
}

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

async function main() {
  try {
    console.log('Fetching workflow:', WORKFLOW_ID);

    // Get workflow
    const getUrl = new URL(`/api/v1/workflows/${WORKFLOW_ID}`, BASE_URL);
    const getOptions = {
      method: 'GET',
      headers: { 'X-N8N-API-KEY': API_KEY }
    };

    const workflow = await makeRequest(getUrl, getOptions);

    console.log('Current workflow:');
    console.log('  Name:', workflow.name);
    console.log('  Nodes:', workflow.nodes.length);
    console.log('  Connections:', Object.keys(workflow.connections || {}).length);
    console.log('');

    // Strategy 1: Update with full workflow data to force reindex
    console.log('Strategy 1: Full workflow update (triggers reindex)...');

    const updatePayload = {
      name: workflow.name,
      nodes: workflow.nodes,
      connections: workflow.connections,
      settings: workflow.settings || {}
    };

    const putUrl = new URL(`/api/v1/workflows/${WORKFLOW_ID}`, BASE_URL);
    const putOptions = {
      method: 'PUT',
      headers: {
        'Content-Type': 'application/json',
        'X-N8N-API-KEY': API_KEY
      }
    };

    const updated = await makeRequest(putUrl, putOptions, updatePayload);

    console.log('✅ Workflow updated successfully');
    console.log('');

    // Verify connections are still there
    const verifyUrl = new URL(`/api/v1/workflows/${WORKFLOW_ID}`, BASE_URL);
    const verifyOptions = {
      method: 'GET',
      headers: { 'X-N8N-API-KEY': API_KEY }
    };

    const verified = await makeRequest(verifyUrl, verifyOptions);

    console.log('Verification:');
    console.log('  Nodes:', verified.nodes.length);
    console.log('  Connections:', Object.keys(verified.connections || {}).length);
    console.log('');

    console.log('✅ Re-indexing complete!');
    console.log('');
    console.log('Next steps:');
    console.log('1. Refresh n8n UI in browser (hard refresh: Cmd+Shift+R)');
    console.log('2. Check if connection lines now appear');
    console.log('3. Activate workflow');
    console.log('4. Test execution by triggering the webhook');
    console.log('');
    console.log('If connections still don\'t work, try:');
    console.log('1. Stop n8n server');
    console.log('2. Start n8n server');
    console.log('3. Open workflow');

  } catch (error) {
    console.error('❌ Error:', error.message);
    process.exit(1);
  }
}

main();
