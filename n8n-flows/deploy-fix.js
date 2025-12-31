#!/usr/bin/env node

const http = require('http');

const API_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJkZDljMjRjMS03MWQ1LTQ1MWYtOTIwOS0zZjAwYzVlM2UxYjQiLCJpc3MiOiJuOG4iLCJhdWQiOiJwdWJsaWMtYXBpIiwiaWF0IjoxNzYyNjg5MTkzLCJleHAiOjE3NjUyNTY0MDB9.PnrQMuw52HZ4tOfLfUASILj8toAYgyJO7eudriHyd5g";
const WORKFLOW_ID = 'R7730Y6p2QWG4TFY';

// Bypass proxy for localhost
delete process.env.http_proxy;
delete process.env.HTTP_PROXY;

console.log('Fetching current workflow...');

const getOptions = {
  hostname: 'localhost',
  port: 5678,
  path: `/api/v1/workflows/${WORKFLOW_ID}`,
  method: 'GET',
  headers: { 'X-N8N-API-KEY': API_KEY }
};

http.get(getOptions, (res) => {
  let data = '';
  res.on('data', chunk => { data += chunk; });
  res.on('end', () => {
    if (res.statusCode !== 200) {
      console.error(`❌ HTTP ${res.statusCode}: ${data}`);
      process.exit(1);
    }

    const workflow = JSON.parse(data);

    // Find and update the node
    const nodeIndex = workflow.nodes.findIndex(n => n.id === '8cf92612-c5ba-4ab0-aa9b-aed4524ebca1');
    if (nodeIndex < 0) {
      console.error('Error: Node "Update Name Attributes" not found');
      process.exit(1);
    }

    console.log('Updating node parameters...');
    workflow.nodes[nodeIndex].parameters.url = '=https://liquid-m3-pro.tail367da4.ts.net/api/v1/accounts/{{ $("AHB1 - Parse Form Response").item.json.accountId }}/conversations/{{ $("AHB1 - Parse Form Response").item.json.conversationId }}/custom_attributes';
    workflow.nodes[nodeIndex].parameters.bodyParameters.parameters = [
      { name: 'custom_attributes[user_name]', value: '={{ $("AHB1 - Parse Form Response").item.json.userName || "" }}' },
      { name: 'custom_attributes[stage_name]', value: '={{ $("AHB1 - Parse Form Response").item.json.stageName || "" }}' },
      { name: 'custom_attributes[selected_name]', value: '={{ $("AHB1 - Parse Form Response").item.json.stageName || $("AHB1 - Parse Form Response").item.json.userName || "" }}' }
    ];

    console.log('Deploying updated workflow...');
    const payload = JSON.stringify({
      name: workflow.name,
      nodes: workflow.nodes,
      connections: workflow.connections,
      settings: workflow.settings,
      staticData: workflow.staticData
    });

    const putOptions = {
      hostname: 'localhost',
      port: 5678,
      path: `/api/v1/workflows/${WORKFLOW_ID}`,
      method: 'PUT',
      headers: {
        'X-N8N-API-KEY': API_KEY,
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(payload)
      }
    };

    const putReq = http.request(putOptions, (putRes) => {
      let putData = '';
      putRes.on('data', chunk => { putData += chunk; });
      putRes.on('end', () => {
        if (putRes.statusCode === 200) {
          console.log('\n✅ SUCCESS! Workflow updated.');
          console.log('\nFixed: "Update Name Attributes" node now explicitly references');
          console.log('       $("AHB1 - Parse Form Response").item.json.*');
          console.log('\nThe conversationId and accountId will now be available reliably.');
        } else {
          console.error('\n❌ Error:', putRes.statusCode, putData);
          process.exit(1);
        }
      });
    });

    putReq.on('error', err => {
      console.error('❌ Request failed:', err.message);
      process.exit(1);
    });

    putReq.write(payload);
    putReq.end();
  });
}).on('error', err => {
  console.error('❌ Failed to fetch workflow:', err.message);
  process.exit(1);
});
