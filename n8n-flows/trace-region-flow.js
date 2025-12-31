#!/usr/bin/env node

const wf = require('./Acoustic-House-Bot-FINAL-v2-NAME-BASED.json');

// Find all If nodes in the cascade
const cascade = [
  'Is Welcome?',
  'Is Menu?',
  'Is Region Selected?',
  'Is Form?',
  'Is Guitar?',
  'Is Time?',
  'Is Payment?'
];

console.log('=== If Node Cascade from "Should Process?" ===\n');

cascade.forEach(nodeName => {
  const node = wf.nodes.find(n => n.name === nodeName);
  if (node) {
    const condition = node.parameters.conditions.conditions[0];
    console.log(`${nodeName}:`);
    console.log(`  Condition: ${condition.leftValue} === ${condition.rightValue}`);

    const conns = wf.connections[nodeName];
    if (conns && conns.main) {
      const trueNode = conns.main[0]?.[0]?.node || 'NONE';
      const falseNode = conns.main[1]?.[0]?.node || 'NONE';
      console.log(`  ✅ TRUE  → ${trueNode}`);
      console.log(`  ❌ FALSE → ${falseNode}`);
    }
    console.log();
  }
});

// Trace the FALSE path from Is Welcome?
console.log('\n=== FALSE Path Chain (when not welcome) ===\n');
let current = 'Is Welcome?';
let depth = 0;
const visited = new Set();

while (current && depth < 15) {
  if (visited.has(current)) {
    console.log('  [LOOP DETECTED]');
    break;
  }
  visited.add(current);

  const indent = '  '.repeat(depth);
  console.log(`${indent}${current}`);

  const conns = wf.connections[current];
  if (conns && conns.main && conns.main[1] && conns.main[1][0]) {
    current = conns.main[1][0].node;
    depth++;
  } else {
    console.log(`${indent}  → [END]`);
    break;
  }
}

console.log('\n=== Analysis ===');
console.log('When user selects region (quick reply):');
console.log('  - route = "REGION_SELECTED"');
console.log('  - isRegionSelected = true');
console.log('  - isWelcome = false');
console.log('\nExpected path:');
console.log('  Router → Should Process? → Is Welcome? (FALSE) → Is Menu? (FALSE) → Is Region Selected? (TRUE) → ???');
