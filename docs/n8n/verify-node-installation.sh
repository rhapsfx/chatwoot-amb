#\!/bin/bash

echo "========================================="
echo "n8n Custom Node Installation Verification"
echo "========================================="
echo

# Check 1: Node package exists
echo "1. Checking node package..."
if [ -d "/Users/rhaps/LocalGit/chatwoot/n8n-nodes-chatwoot-amb" ]; then
    echo "   ✅ Package directory exists"
else
    echo "   ❌ Package directory NOT found"
fi

# Check 2: Package is built
echo
echo "2. Checking compiled nodes..."
if [ -f "/Users/rhaps/LocalGit/chatwoot/n8n-nodes-chatwoot-amb/dist/nodes/ChatwootAMBListPicker/ChatwootAMBListPicker.node.js" ]; then
    echo "   ✅ ListPicker node compiled"
else
    echo "   ❌ ListPicker node NOT compiled"
fi

# Check 3: Symlink exists
echo
echo "3. Checking n8n symlink..."
if [ -L "/Users/rhaps/.n8n/custom/node_modules/n8n-nodes-chatwoot-amb" ]; then
    echo "   ✅ Symlink exists"
    echo "   → $(readlink /Users/rhaps/.n8n/custom/node_modules/n8n-nodes-chatwoot-amb)"
else
    echo "   ❌ Symlink NOT found"
fi

# Check 4: Package.json has dependency
echo
echo "4. Checking package.json..."
if grep -q "n8n-nodes-chatwoot-amb" /Users/rhaps/.n8n/custom/package.json; then
    echo "   ✅ Dependency declared in package.json"
else
    echo "   ❌ Dependency NOT in package.json"
fi

# Check 5: Show all available nodes
echo
echo "5. Available custom nodes:"
ls -1 /Users/rhaps/LocalGit/chatwoot/n8n-nodes-chatwoot-amb/dist/nodes/ | while read node; do
    echo "   - $node"
done

echo
echo "========================================="
echo "Verification complete\!"
echo "========================================="
