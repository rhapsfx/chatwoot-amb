#!/usr/bin/env node

/**
 * Diagnose n8n Workflow Connections
 *
 * Fetches a workflow and displays detailed connection information
 * to understand why UI shows disconnected nodes despite API verification passing.
 *
 * Usage:
 *   export N8N_API_KEY="your-api-key"
 *   node diagnose-workflow.js gX2XKF4jZyRXnEOO
 */

const https = require('https');
const http = require('http');

const API_KEY = process.env.N8N_API_KEY;
const BASE_URL = process.env.N8N_BASE_URL || 'http://localhost:5678';
const WORKFLOW_ID = process.argv[2];

if (!API_KEY) {
  console.error('ERROR: N8N_API_KEY environment variable not set');
  process.exit(1);
}

if (!WORKFLOW_ID) {
  console.error('ERROR: Workflow ID required');
  console.error('Usage: node diagnose-workflow.js <workflow-id>');
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
    console.log(`Fetching workflow ${WORKFLOW_ID}...`);
    console.log('');

    const url = new URL(`/api/v1/workflows/${WORKFLOW_ID}`, BASE_URL);
    const options = {
      method: 'GET',
      headers: {
        'X-N8N-API-KEY': API_KEY
      }
    };

    const workflow = await makeRequest(url, options);

    console.log('=== WORKFLOW OVERVIEW ===');
    console.log('');
    console.log('ID:', workflow.id);
    console.log('Name:', workflow.name);
    console.log('Active:', workflow.active);
    console.log('');
    console.log('Total Nodes:', workflow.nodes.length);
    console.log('Connection Sources:', Object.keys(workflow.connections || {}).length);
    console.log('');

    // Analyze nodes
    console.log('=== NODE ANALYSIS ===');
    console.log('');

    // Create node ID to name mapping
    const nodeMap = {};
    workflow.nodes.forEach(node => {
      nodeMap[node.id] = node.name;
    });

    console.log('Sample nodes (first 10):');
    workflow.nodes.slice(0, 10).forEach((node, i) => {
      console.log(`  ${i + 1}. ${node.name}`);
      console.log(`     ID: ${node.id}`);
      console.log(`     Type: ${node.type}`);
    });
    console.log('');

    // Analyze connections in detail
    console.log('=== CONNECTION ANALYSIS ===');
    console.log('');

    const connections = workflow.connections || {};
    const connectionSources = Object.keys(connections);

    if (connectionSources.length === 0) {
      console.error('❌ CRITICAL: connections object is empty!');
      console.error('');
      console.error('This means n8n API returned the workflow without connections.');
      process.exit(1);
    }

    console.log(`Connection sources: ${connectionSources.length}`);
    console.log('');

    // Count total connections and analyze structure
    let totalConnections = 0;
    let invalidSourceCount = 0;
    let invalidTargetCount = 0;

    connectionSources.forEach(sourceId => {
      const sourceNode = nodeMap[sourceId];

      if (!sourceNode) {
        invalidSourceCount++;
        console.warn(`⚠️  Source node ID not found: ${sourceId}`);
      }

      const outputs = connections[sourceId];

      for (const outputType in outputs) {
        const outputArray = outputs[outputType];

        if (Array.isArray(outputArray)) {
          outputArray.forEach((connArray, outputIndex) => {
            connArray.forEach(conn => {
              totalConnections++;

              const targetNode = nodeMap[conn.node];

              if (!targetNode) {
                invalidTargetCount++;
                console.warn(`⚠️  Target node ID not found: ${conn.node}`);
              }
            });
          });
        }
      }
    });

    console.log(`Total connections: ${totalConnections}`);
    console.log(`Invalid source node IDs: ${invalidSourceCount}`);
    console.log(`Invalid target node IDs: ${invalidTargetCount}`);
    console.log('');

    if (invalidSourceCount > 0 || invalidTargetCount > 0) {
      console.error('❌ PROBLEM FOUND: Connection node IDs do not match actual node IDs!');
      console.error('');
      console.error('This is why n8n UI shows disconnected nodes:');
      console.error('The connections object references node IDs that do not exist.');
      console.error('');
    }

    // Show first 10 connections with node names
    console.log('=== FIRST 10 CONNECTIONS ===');
    console.log('');

    let count = 0;
    for (const sourceId in connections) {
      if (count >= 10) break;

      const sourceNode = nodeMap[sourceId] || `UNKNOWN (${sourceId.substring(0, 8)}...)`;
      const outputs = connections[sourceId];

      for (const outputType in outputs) {
        const outputArray = outputs[outputType];

        if (Array.isArray(outputArray)) {
          outputArray.forEach((connArray, outputIndex) => {
            connArray.forEach(conn => {
              if (count >= 10) return;

              const targetNode = nodeMap[conn.node] || `UNKNOWN (${conn.node.substring(0, 8)}...)`;

              console.log(`${count + 1}. ${sourceNode}`);
              console.log(`   → ${targetNode}`);
              console.log(`   Type: ${outputType}, Output: ${outputIndex}, Input: ${conn.type}/${conn.index}`);
              console.log('');

              count++;
            });
          });
        }
      }
    }

    // Check for node ID format issues
    console.log('=== NODE ID FORMAT ANALYSIS ===');
    console.log('');

    const nodeIds = workflow.nodes.map(n => n.id);
    const connectionNodeIds = new Set();

    for (const sourceId in connections) {
      connectionNodeIds.add(sourceId);

      const outputs = connections[sourceId];
      for (const outputType in outputs) {
        const outputArray = outputs[outputType];
        if (Array.isArray(outputArray)) {
          outputArray.forEach(connArray => {
            connArray.forEach(conn => {
              connectionNodeIds.add(conn.node);
            });
          });
        }
      }
    }

    console.log('Sample node IDs from nodes array:');
    nodeIds.slice(0, 5).forEach(id => {
      console.log(`  ${id} (length: ${id.length}, format: ${id.includes('-') ? 'UUID' : 'unknown'})`);
    });
    console.log('');

    console.log('Sample node IDs from connections object:');
    [...connectionNodeIds].slice(0, 5).forEach(id => {
      console.log(`  ${id} (length: ${id.length}, format: ${id.includes('-') ? 'UUID' : 'unknown'})`);
    });
    console.log('');

    // Check for ID matches
    const nodesSet = new Set(nodeIds);
    const matchingIds = [...connectionNodeIds].filter(id => nodesSet.has(id));

    console.log('=== ID MATCHING ===');
    console.log('');
    console.log(`Node IDs in nodes array: ${nodeIds.length}`);
    console.log(`Node IDs in connections: ${connectionNodeIds.size}`);
    console.log(`Matching IDs: ${matchingIds.length}`);
    console.log(`Match percentage: ${((matchingIds.length / connectionNodeIds.size) * 100).toFixed(1)}%`);
    console.log('');

    if (matchingIds.length < connectionNodeIds.size) {
      console.error('❌ ROOT CAUSE FOUND:');
      console.error('');
      console.error('The node IDs in the connections object DO NOT match the actual node IDs.');
      console.error('This is why n8n UI cannot draw the connection lines.');
      console.error('');

      // Show mismatched IDs
      const mismatched = [...connectionNodeIds].filter(id => !nodesSet.has(id));
      console.error(`Mismatched node IDs: ${mismatched.length}`);
      console.error('Sample mismatched IDs (from connections):');
      mismatched.slice(0, 5).forEach(id => {
        console.error(`  ${id}`);
      });
      console.error('');

      console.error('Sample actual node IDs (from nodes array):');
      nodeIds.slice(0, 5).forEach(id => {
        console.error(`  ${id}`);
      });
      console.error('');

      console.error('CONCLUSION:');
      console.error('n8n API created the workflow with NEW node IDs but kept the OLD IDs in connections.');
      console.error('This creates a mismatch that breaks the visual connections in the UI.');
    } else {
      console.log('✅ All connection node IDs match actual node IDs.');
      console.log('');
      console.log('This suggests a different issue. Possible causes:');
      console.log('- Workflow needs to be activated to render connections');
      console.log('- n8n UI cache issue (try refreshing)');
      console.log('- Connection data structure format issue');
    }

  } catch (error) {
    console.error('');
    console.error('❌ Error:', error.message);
    process.exit(1);
  }
}

main();
