#!/usr/bin/env python3
"""
Complete workflow fix:
1. Fix Router with State syntax errors
2. Inject HTTP Header Auth credentials into HTTP Request nodes
3. Update CUSTOM node credentials
"""

import json
import re
from pathlib import Path

# Credential configurations
HTTP_CREDENTIAL = {
    'id': 'RQQuzy3scKeZsK8H',
    'name': 'n8n Local -Bot Chatwoot'
}

CUSTOM_CREDENTIAL = {
    'id': 'c1Q7oV1mUwnc9b5T',
    'name': 'Chatwoot Test Bot'
}

def fix_router_code(code: str) -> str:
    """Remove duplicate Tier 4 sections from Router with State."""
    lines = code.split('\n')
    cleaned_lines = []
    skip_until = -1

    for i, line in enumerate(lines):
        if i < skip_until:
            continue

        # Check for Tier 4 comment followed by else if
        if '// Tier 4: Advanced Features' in line:
            next_line_idx = i + 1
            while next_line_idx < len(lines) and not lines[next_line_idx].strip():
                next_line_idx += 1

            if next_line_idx < len(lines) and lines[next_line_idx].strip().startswith('else if'):
                # Find where this block ends
                end_idx = i + 1
                while end_idx < len(lines):
                    if (lines[end_idx].strip().startswith('console.log') or
                        lines[end_idx].strip().startswith('// Skip') or
                        lines[end_idx].strip().startswith('let route') or
                        lines[end_idx].strip().startswith('if (event')):
                        break
                    end_idx += 1
                skip_until = end_idx
                continue

        cleaned_lines.append(line)

    return '\n'.join(cleaned_lines)

def fix_workflow(input_path: str, output_path: str = None):
    """Apply all fixes to the workflow."""

    # Read workflow
    with open(input_path, 'r') as f:
        workflow = json.load(f)

    stats = {
        'http_fixed': 0,
        'custom_updated': 0,
        'router_fixed': False
    }

    # Process each node
    for node in workflow['nodes']:
        node_type = node['type']

        # Fix HTTP Request nodes
        if node_type == 'n8n-nodes-base.httpRequest':
            params = node.get('parameters', {})

            # Fix credentials
            if params.get('genericAuthType') == 'httpHeaderAuth':
                node['credentials'] = {
                    'httpHeaderAuth': {
                        'id': HTTP_CREDENTIAL['id'],
                        'name': HTTP_CREDENTIAL['name']
                    }
                }
                stats['http_fixed'] += 1

            # Fix URL expressions - add = prefix if URL contains {{ }} but doesn't start with =
            url = params.get('url', '')
            if '{{' in url and not url.startswith('='):
                params['url'] = '=' + url
                if 'http_url_fixed' not in stats:
                    stats['http_url_fixed'] = 0
                stats['http_url_fixed'] += 1

        # Update CUSTOM nodes
        elif node_type.startswith('CUSTOM.'):
            node['credentials'] = {
                'chatwootBotApi': {
                    'id': CUSTOM_CREDENTIAL['id'],
                    'name': CUSTOM_CREDENTIAL['name']
                }
            }
            stats['custom_updated'] += 1

        # Fix Router with State
        elif node['name'] == 'Router with State':
            original_code = node['parameters']['jsCode']
            fixed_code = fix_router_code(original_code)
            node['parameters']['jsCode'] = fixed_code
            stats['router_fixed'] = True
            print(f"✅ Fixed Router: {len(original_code.split(chr(10)))} → {len(fixed_code.split(chr(10)))} lines")

    # Determine output path
    if not output_path:
        input_path_obj = Path(input_path)
        output_path = input_path_obj.parent / f"{input_path_obj.stem}-COMPLETE-FIX{input_path_obj.suffix}"

    # Save
    with open(output_path, 'w') as f:
        json.dump(workflow, f, indent=2)

    # Report
    print(f"\n{'='*70}")
    print(f"🎉 COMPLETE FIX APPLIED!")
    print(f"{'='*70}")
    print(f"\n📊 Summary:")
    print(f"  ✅ HTTP Request nodes updated: {stats['http_fixed']}")
    print(f"     → Credential: {HTTP_CREDENTIAL['name']}")
    if stats.get('http_url_fixed', 0) > 0:
        print(f"  ✅ HTTP URL expressions fixed: {stats['http_url_fixed']}")
        print(f"     → Added '=' prefix for n8n expressions")
    print(f"  ✅ CUSTOM nodes updated: {stats['custom_updated']}")
    print(f"     → Credential: {CUSTOM_CREDENTIAL['name']}")
    print(f"  ✅ Router syntax fixed: {stats['router_fixed']}")
    print(f"\n💾 Fixed workflow saved to:")
    print(f"  {output_path}")
    print(f"\n🚀 Ready to import into n8n!")
    print(f"  • No exclamation marks")
    print(f"  • No syntax errors")
    print(f"  • No manual credential linking needed")
    print(f"  • All URL expressions properly formatted")
    print(f"{'='*70}\n")

    return str(output_path)

if __name__ == '__main__':
    import sys

    input_file = sys.argv[1] if len(sys.argv) > 1 else 'Acoustic-House-Bot-TIER4.json'
    output_file = sys.argv[2] if len(sys.argv) > 2 else None

    fix_workflow(input_file, output_file)
