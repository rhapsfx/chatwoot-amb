#!/usr/bin/env node

const http = require('http');

const API_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJkZDljMjRjMS03MWQ1LTQ1MWYtOTIwOS0zZjAwYzVlM2UxYjQiLCJpc3MiOiJuOG4iLCJhdWQiOiJwdWJsaWMtYXBpIiwiaWF0IjoxNzYyNjg5MTkzLCJleHAiOjE3NjUyNTY0MDB9.PnrQMuw52HZ4tOfLfUASILj8toAYgyJO7eudriHyd5g";
const WORKFLOW_ID = "R7730Y6p2QWG4TFY";

const url = new URL(`/api/v1/workflows/${WORKFLOW_ID}`, 'http://localhost:5678');
const options = {
  method: 'GET',
  headers: { 'X-N8N-API-KEY': API_KEY }
};

const req = http.request(url, options, (res) => {
  let data = '';
  res.on('data', (chunk) => { data += chunk; });
  res.on('end', () => {
    const workflow = JSON.parse(data);

    console.log('=== WORKFLOW STRUCTURE ===\n');
    console.log(`Name: ${workflow.name}`);
    console.log(`Nodes: ${workflow.nodes.length}`);
    console.log(`Connection Sources: ${Object.keys(workflow.connections || {}).length}\n`);

    // Check if connections use names or IDs
    const connKeys = Object.keys(workflow.connections || {});
    const nodeIds = workflow.nodes.map(n => n.id);
    const nodeNames = workflow.nodes.map(n => n.name);

    console.log('=== CONNECTION FORMAT ===\n');
    console.log('Sample connection keys (first 5):');
    connKeys.slice(0, 5).forEach(key => {
      console.log(`  "${key}"`);
    });
    console.log();

    // Check if using names or IDs
    const usingNames = connKeys.some(key => nodeNames.includes(key));
    const usingIds = connKeys.some(key => nodeIds.includes(key));

    console.log(`Using node NAMES in connections: ${usingNames ? '✅' : '❌'}`);
    console.log(`Using node IDs in connections: ${usingIds ? '✅' : '❌'}\n`);

    // Find disconnected nodes
    console.log('=== DISCONNECTED NODES ===\n');
    const connectedNodeNames = new Set();

    for (const [sourceName, outputs] of Object.entries(workflow.connections || {})) {
      connectedNodeNames.add(sourceName);
      for (const outputType in outputs) {
        const outputArray = outputs[outputType];
        outputArray.forEach(connArray => {
          connArray.forEach(conn => {
            connectedNodeNames.add(conn.node);
          });
        });
      }
    }

    const disconnectedNodes = workflow.nodes.filter(n => !connectedNodeNames.has(n.name));

    if (disconnectedNodes.length > 0) {
      console.log(`Found ${disconnectedNodes.length} disconnected nodes:\n`);
      disconnectedNodes.forEach((node, i) => {
        console.log(`  ${i + 1}. ${node.name} (${node.type})`);
      });
    } else {
      console.log('✅ All nodes are connected!');
    }
  });
});

req.on('error', (err) => {
  console.error('Request Error:', err);
  process.exit(1);
});

req.end();
