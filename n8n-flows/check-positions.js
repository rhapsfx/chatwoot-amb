#!/usr/bin/env node

/**
 * Check Node Positions in n8n Workflow
 *
 * n8n UI requires nodes to have position coordinates to render connections.
 * This script checks if position data exists and is valid.
 */

const https = require('https');
const http = require('http');

const API_KEY = process.env.N8N_API_KEY;
const BASE_URL = process.env.N8N_BASE_URL || 'http://localhost:5678';
const WORKFLOW_ID = process.argv[2];

if (!WORKFLOW_ID) {
  console.error('Usage: node check-positions.js <workflow-id>');
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

async function main() {
  try {
    const url = new URL(`/api/v1/workflows/${WORKFLOW_ID}`, BASE_URL);
    const options = {
      method: 'GET',
      headers: { 'X-N8N-API-KEY': API_KEY }
    };

    const workflow = await makeRequest(url, options);

    console.log('=== POSITION DATA ANALYSIS ===');
    console.log('');

    let nodesWithPosition = 0;
    let nodesWithoutPosition = 0;
    let nodesAtOrigin = 0;

    const positionStats = {
      minX: Infinity,
      maxX: -Infinity,
      minY: Infinity,
      maxY: -Infinity
    };

    workflow.nodes.forEach(node => {
      if (node.position && Array.isArray(node.position) && node.position.length === 2) {
        nodesWithPosition++;

        const [x, y] = node.position;

        if (x === 0 && y === 0) {
          nodesAtOrigin++;
        }

        positionStats.minX = Math.min(positionStats.minX, x);
        positionStats.maxX = Math.max(positionStats.maxX, x);
        positionStats.minY = Math.min(positionStats.minY, y);
        positionStats.maxY = Math.max(positionStats.maxY, y);
      } else {
        nodesWithoutPosition++;
        console.log(`⚠️  Node without position: ${node.name} (${node.id})`);
      }
    });

    console.log(`Total nodes: ${workflow.nodes.length}`);
    console.log(`Nodes with position data: ${nodesWithPosition}`);
    console.log(`Nodes without position data: ${nodesWithoutPosition}`);
    console.log(`Nodes at origin (0, 0): ${nodesAtOrigin}`);
    console.log('');

    if (nodesWithoutPosition > 0) {
      console.error('❌ PROBLEM: Some nodes are missing position data!');
      console.error('n8n UI cannot render nodes without positions.');
      console.error('');
    } else if (nodesAtOrigin > 10) {
      console.warn('⚠️  WARNING: Many nodes are at origin (0, 0)');
      console.warn('This might cause nodes to overlap in the UI.');
      console.warn('');
    }

    if (nodesWithPosition > 0) {
      console.log('Position boundaries:');
      console.log(`  X: ${positionStats.minX} to ${positionStats.maxX} (width: ${positionStats.maxX - positionStats.minX})`);
      console.log(`  Y: ${positionStats.minY} to ${positionStats.maxY} (height: ${positionStats.maxY - positionStats.minY})`);
      console.log('');
    }

    console.log('Sample node positions (first 10):');
    workflow.nodes.slice(0, 10).forEach((node, i) => {
      const pos = node.position || ['N/A', 'N/A'];
      console.log(`  ${i + 1}. ${node.name}`);
      console.log(`     Position: [${pos[0]}, ${pos[1]}]`);
    });
    console.log('');

    // Check if this is a UI rendering issue
    console.log('=== UI RENDERING DIAGNOSIS ===');
    console.log('');

    if (nodesWithPosition === workflow.nodes.length) {
      console.log('✅ All nodes have position data.');
      console.log('');
      console.log('Possible causes of UI not showing connections:');
      console.log('1. Browser cache - Try hard refresh (Ctrl+Shift+R / Cmd+Shift+R)');
      console.log('2. Workflow needs activation - Try activating the workflow');
      console.log('3. n8n UI bug - Try opening in different browser');
      console.log('4. Canvas zoom/pan issue - Try zooming to fit all nodes');
      console.log('');
      console.log('Recommended actions:');
      console.log('1. In n8n UI, press "Activate" button');
      console.log('2. Zoom to fit all nodes (Ctrl+0 / Cmd+0)');
      console.log('3. Hard refresh the browser');
      console.log('4. Check browser console for errors (F12)');
    }

  } catch (error) {
    console.error('❌ Error:', error.message);
    process.exit(1);
  }
}

main();
