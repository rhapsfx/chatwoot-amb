const http = require('http');
const fs = require('fs');

const API_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJkZDljMjRjMS03MWQ1LTQ1MWYtOTIwOS0zZjAwYzVlM2UxYjQiLCJpc3MiOiJuOG4iLCJhdWQiOiJwdWJsaWMtYXBpIiwiaWF0IjoxNzYyNjg5MTkzLCJleHAiOjE3NjUyNTY0MDB9.PnrQMuw52HZ4tOfLfUASILj8toAYgyJO7eudriHyd5g";
const WORKFLOW_ID = "R7730Y6p2QWG4TFY";
const EXECUTION_ID = "1520";

function makeRequest(url, options) {
  return new Promise((resolve, reject) => {
    const req = http.request(url, options, (res) => {
      let data = '';
      res.on('data', (chunk) => { data += chunk; });
      res.on('end', () => {
        if (res.statusCode >= 200 && res.statusCode < 300) {
          try {
            resolve(JSON.parse(data));
          } catch (e) {
            reject(new Error(`Parse error: ${e.message}`));
          }
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
  console.log('=== FETCHING WORKFLOW STRUCTURE ===\n');
  
  const workflowUrl = new URL(`/api/v1/workflows/${WORKFLOW_ID}`, 'http://localhost:5678');
  const options = {
    method: 'GET',
    headers: { 'X-N8N-API-KEY': API_KEY }
  };

  try {
    const workflow = await makeRequest(workflowUrl, options);
    
    console.log(`Workflow Name: ${workflow.name}`);
    console.log(`Total Nodes: ${workflow.nodes.length}\n`);
    
    const hasStageNameNode = workflow.nodes.find(n => n.name === 'Has Stage Name ?');
    const updateNameNode = workflow.nodes.find(n => n.name === 'Update Name Attributes');
    
    if (hasStageNameNode) {
      console.log('=== HAS STAGE NAME ? NODE ===');
      console.log(`Type: ${hasStageNameNode.type}`);
      console.log(`Parameters:`, JSON.stringify(hasStageNameNode.parameters, null, 2));
      console.log();
    }
    
    if (updateNameNode) {
      console.log('=== UPDATE NAME ATTRIBUTES NODE ===');
      console.log(`Type: ${updateNameNode.type}`);
      console.log(`Parameters:`, JSON.stringify(updateNameNode.parameters, null, 2));
      console.log();
    }
    
    if (workflow.connections['Has Stage Name ?']) {
      console.log('=== CONNECTIONS FROM "Has Stage Name ?" ===');
      console.log(JSON.stringify(workflow.connections['Has Stage Name ?'], null, 2));
      console.log();
    }
    
    fs.writeFileSync('./tmp/workflow-structure.json', JSON.stringify(workflow, null, 2));
    console.log('✅ Workflow structure saved to ./tmp/workflow-structure.json\n');
    
  } catch (error) {
    console.error('❌ Failed to fetch workflow:', error.message);
  }
  
  console.log('=== FETCHING EXECUTION DETAILS ===\n');
  
  const executionUrl = new URL(`/api/v1/executions/${EXECUTION_ID}`, 'http://localhost:5678');
  
  try {
    const execution = await makeRequest(executionUrl, options);
    
    console.log(`Status: ${execution.status}`);
    console.log(`Started: ${execution.startedAt}`);
    console.log(`Finished: ${execution.finishedAt}`);
    console.log(`Mode: ${execution.mode}\n`);
    
    if (execution.data && execution.data.resultData) {
      const runData = execution.data.resultData.runData;
      
      if (runData['Has Stage Name ?']) {
        console.log('=== DATA FROM "Has Stage Name ?" NODE ===\n');
        const nodeData = runData['Has Stage Name ?'];
        
        nodeData.forEach((run, idx) => {
          console.log(`Run ${idx}:`);
          if (run.data && run.data.main && run.data.main[0]) {
            console.log('Output data:');
            run.data.main[0].forEach((item, i) => {
              console.log(`  Item ${i}:`, JSON.stringify(item.json, null, 2));
            });
          }
        });
        console.log();
      }
      
      if (runData['Update Name Attributes']) {
        console.log('=== ERROR FROM "Update Name Attributes" NODE ===\n');
        const nodeData = runData['Update Name Attributes'];
        
        nodeData.forEach((run, idx) => {
          if (run.error) {
            console.log(`Error:`, JSON.stringify(run.error, null, 2));
          }
        });
        console.log();
      }
    }
    
    fs.writeFileSync('./tmp/execution-details.json', JSON.stringify(execution, null, 2));
    console.log('✅ Execution details saved to ./tmp/execution-details.json\n');
    
  } catch (error) {
    console.error('❌ Failed to fetch execution:', error.message);
  }
}

main();
