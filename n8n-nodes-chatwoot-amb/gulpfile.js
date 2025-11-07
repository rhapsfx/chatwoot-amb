const { src, dest, parallel } = require('gulp');

// Copy icons to dist/icons (for package distribution)
function buildIconsMain() {
  return src('icons/**/*')
    .pipe(dest('dist/icons'));
}

// Copy icons to each node directory (required for n8n to load them)
function buildIconsNodes() {
  return src('icons/**/*')
    .pipe(dest('dist/nodes/ChatwootAMBListPicker'))
    .pipe(dest('dist/nodes/ChatwootAMBTimePicker'))
    .pipe(dest('dist/nodes/ChatwootAMBQuickReply'))
    .pipe(dest('dist/nodes/ChatwootAMBForm'))
    .pipe(dest('dist/nodes/ChatwootAMBApplePay'))
    .pipe(dest('dist/nodes/ChatwootAMBRichLink'))
    .pipe(dest('dist/nodes/ChatwootAMBTemplateMessage'));
}

// Run both tasks in parallel
const buildIcons = parallel(buildIconsMain, buildIconsNodes);

exports['build:icons'] = buildIcons;
exports.default = buildIcons;
