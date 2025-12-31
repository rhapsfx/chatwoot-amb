#!/usr/bin/env node

const fs = require('fs');
const http = require('http');

const API_KEY = process.env.N8N_API_KEY || "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJkZDljMjRjMS03MWQ1LTQ1MWYtOTIwOS0zZjAwYzVlM2UxYjQiLCJpc3MiOiJuOG4iLCJhdWQiOiJwdWJsaWMtYXBpIiwiaWF0IjoxNzYyNjg5MTkzLCJleHAiOjE3NjUyNTY0MDB9.PnrQMuw52HZ4tOfLfUASILj8toAYgyJO7eudriHyd5g";
const BASE_URL = 'http://localhost:5678';
const WORKFLOW_ID = 'R7730Y6p2QWG4TFY';
const WORKFLOW_FILE = './Acoustic-House-Bot-FINAL-v2-NAME-BASED-FIXED-v2.json';

console.log('='.repeat(80));
console.log('DEPLOYING FIX FOR EXECUTION 1520');
console.log('='.repeat(80));
console.log();

console.log('Issue: "Update Name Attributes" node failed');
console.log('Root Cause: {{ $json.conversationId }} not available from IF node');
console.log('Solution: Reference upstream node explicitly');
console.log();

console.log('Reading fixed workflow from:', WORKFLOW_FILE);
const workflow = JSON.parse(fs.readFileSync(WORKFLOW_FILE, 'utf8'));

console.log(`Workflow: ${workflow.name}`);
console.log(`Nodes: ${workflow.nodes.length}`);
console.log(`Connections: ${Object.keys(workflow.connections).length}`);
console.log();

// Verify the fix
const updateNode = workflow.nodes.find(n => n.name === 'Update Name Attributes');
if (!updateNode) {
  console.error('ERROR: Could not find "Update Name Attributes" node');
  process.exit(1);
}

console.log('Verifying fix...');
console.log('-'.repeat(80));
const url = updateNode.parameters.url;
if (url.includes('$("AHB1 - Parse Form Response")')) {
  console.log('✅ URL references upstream node explicitly');
} else {
  console.error('❌ Fix not applied - URL still uses $json');
  process.exit(1);
}

const params = updateNode.parameters.bodyParameters.parameters;
const allFixed = params.every(p => p.value.includes('$("AHB1 - Parse Form Response")'));
if (allFixed) {
  console.log('✅ All body parameters reference upstream node');
} else {
  console.error('❌ Some parameters still use $json');
  process.exit(1);
}

console.log();
console.log('Fix verification passed!');
console.log();

function makeRequest(url, options, postData = null) {
  return new Promise((resolve, reject) => {
    const req = http.request(url, options, (res) => {
      let data = '';
      res.on('data', (chunk) => { data += chunk; });
      res.on('end', () => {
        if (res.statusCode >= 200 && res.statusCode < 300) {
          try {
            resolve(JSON.parse(data));
          } catch (e) {
            resolve(data);
          }
        } else {
          reject(new Error(`HTTP ${res.statusCode}: ${data}`));
        }
      });
    });

    req.on('error', (err) => {
      reject(new Error(`Request failed: ${err.message}`));
    });

    if (postData) {
      req.write(JSON.stringify(postData));
    }

    req.end();
  });
}

async function main() {
  const updateUrl = new URL(`/api/v1/workflows/${WORKFLOW_ID}`, BASE_URL);
  const updateOptions = {
    method: 'PUT',
    headers: {
      'X-N8N-API-KEY': API_KEY,
      'Content-Type': 'application/json'
    }
  };

  const payload = {
    name: workflow.name,
    nodes: workflow.nodes,
    connections: workflow.connections,
    settings: workflow.settings || {},
    staticData: workflow.staticData || null
  };

  console.log('Deploying to n8n...');
  console.log();

  try {
    const result = await makeRequest(updateUrl, updateOptions, payload);
    console.log('='.repeat(80));
    console.log('✅ WORKFLOW UPDATED SUCCESSFULLY!');
    console.log('='.repeat(80));
    console.log();
    console.log('Workflow ID:', result.id);
    console.log('Name:', result.name);
    console.log('Nodes:', result.nodes?.length || 'N/A');
    console.log();
    console.log('='.repeat(80));
    console.log('WHAT WAS FIXED:');
    console.log('='.repeat(80));
    console.log();
    console.log('The "Update Name Attributes" node now explicitly references');
    console.log('the "AHB1 - Parse Form Response" node instead of relying on');
    console.log('$json data from the IF node.');
    console.log();
    console.log('Changed from:');
    console.log('  {{ $json.conversationId }}');
    console.log('  {{ $json.accountId }}');
    console.log();
    console.log('Changed to:');
    console.log('  {{ $("AHB1 - Parse Form Response").item.json.conversationId }}');
    console.log('  {{ $("AHB1 - Parse Form Response").item.json.accountId }}');
    console.log();
    console.log('This ensures the data is always available regardless of how');
    console.log('the IF node "Has Stage Name?" passes data through.');
    console.log();
  } catch (error) {
    console.error('='.repeat(80));
    console.error('❌ UPDATE FAILED');
    console.error('='.repeat(80));
    console.error();
    console.error('Error:', error.message);
    console.error('Stack:', error.stack);
    console.error();
    process.exit(1);
  }
}

main();
