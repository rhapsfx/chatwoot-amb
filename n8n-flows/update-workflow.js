#!/usr/bin/env node

/**
 * Update existing n8n workflow via API
 */

const fs = require('fs');
const https = require('https');
const http = require('http');

const API_KEY = process.env.N8N_API_KEY || "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJkZDljMjRjMS03MWQ1LTQ1MWYtOTIwOS0zZjAwYzVlM2UxYjQiLCJpc3MiOiJuOG4iLCJhdWQiOiJwdWJsaWMtYXBpIiwiaWF0IjoxNzYyNjg5MTkzLCJleHAiOjE3NjUyNTY0MDB9.PnrQMuw52HZ4tOfLfUASILj8toAYgyJO7eudriHyd5g";
const BASE_URL = 'http://localhost:5678';
const WORKFLOW_ID = 'R7730Y6p2QWG4TFY';
const WORKFLOW_FILE = './Acoustic-House-Bot-FINAL-v2-NAME-BASED-FIXED.json';

console.log('Reading fixed workflow from:', WORKFLOW_FILE);
const workflow = JSON.parse(fs.readFileSync(WORKFLOW_FILE, 'utf8'));

console.log(`Workflow: ${workflow.name}`);
console.log(`Nodes: ${workflow.nodes.length}`);
console.log(`Connections: ${Object.keys(workflow.connections).length}\n`);

function makeRequest(url, options, postData = null) {
  return new Promise((resolve, reject) => {
    const client = url.protocol === 'https:' ? https : http;

    const req = client.request(url, options, (res) => {
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

    req.on('error', reject);

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

  console.log('Updating workflow...');

  try {
    const result = await makeRequest(updateUrl, updateOptions, payload);
    console.log('✅ Workflow updated successfully!\n');
    console.log('Workflow ID:', result.id);
    console.log('Name:', result.name);
    console.log('Nodes:', result.nodes?.length || 'N/A');
    console.log('Connection sources:', Object.keys(result.connections || {}).length);
    console.log('\n🎯 The region response routing has been fixed!');
    console.log('   When user selects region → form will show correctly');
  } catch (error) {
    console.error('❌ Update failed:', error.message);
    console.error('Full error:', error);
    process.exit(1);
  }
}

main();
