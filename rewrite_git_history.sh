#!/bin/bash
# Git History Rewrite Script
# Changes all commits from ducros.m@apple.com to rhaps@mac.com
# and commits pending changes to acoustic_house_bot_service.rb

set -e  # Exit on error

echo "========================================="
echo "Git History Rewrite Script"
echo "========================================="
echo ""

# Step 1: Handle unstaged changes
echo "Step 1: Committing unstaged changes..."
echo ""

if git diff --quiet; then
  echo "✓ No unstaged changes found"
else
  echo "Found unstaged changes in:"
  git status --short
  echo ""

  # Commit the acoustic_house_bot_service.rb changes
  echo "Committing acoustic_house_bot_service.rb changes..."
  git add app/services/apple_messages_for_business/acoustic_house_bot_service.rb

  git commit -m "$(cat <<'EOF'
fix: Refactor handlers to use visual flow architecture

- Refactor handle_form_or_name_prompt to route via condition node
- Update handle_text_name_input to collect stage name as second step
- Refactor handle_ar_introduction to return transition indicator
- Remove device capability checks from handlers (delegated to flow)
- Let visual flow condition nodes handle device capability routing

This allows the Bot Studio visual flow to control routing logic
instead of hardcoding it in handler methods.
EOF
)"

  echo "✓ Changes committed"
fi

echo ""
echo "Step 2: Backing up current state..."
echo ""

# Create backup branch
BACKUP_BRANCH="backup-before-rewrite-$(date +%Y%m%d-%H%M%S)"
git branch "$BACKUP_BRANCH"
echo "✓ Created backup branch: $BACKUP_BRANCH"

echo ""
echo "Step 3: Counting commits to rewrite..."
echo ""

COMMIT_COUNT=$(git log --all --format="%ae" | grep -c "ducros.m@apple.com" || true)
echo "Found $COMMIT_COUNT commits with ducros.m@apple.com"

echo ""
echo "Step 4: Rewriting Git history..."
echo "This may take a few minutes..."
echo ""

# Perform the rewrite
git filter-branch --force --env-filter '
OLD_EMAIL="ducros.m@apple.com"
CORRECT_NAME="Matthieu Ducros"
CORRECT_EMAIL="rhaps@mac.com"

if [ "$GIT_COMMITTER_EMAIL" = "$OLD_EMAIL" ]
then
    export GIT_COMMITTER_NAME="$CORRECT_NAME"
    export GIT_COMMITTER_EMAIL="$CORRECT_EMAIL"
fi
if [ "$GIT_AUTHOR_EMAIL" = "$OLD_EMAIL" ]
then
    export GIT_AUTHOR_NAME="$CORRECT_NAME"
    export GIT_AUTHOR_EMAIL="$CORRECT_EMAIL"
fi
' --tag-name-filter cat -- --branches --tags

echo ""
echo "✓ History rewrite complete!"

echo ""
echo "Step 5: Verifying changes..."
echo ""

# Verify no old emails remain
OLD_EMAIL_COUNT=$(git log --all --format="%ae" | grep -c "ducros.m@apple.com" || true)
if [ "$OLD_EMAIL_COUNT" -eq 0 ]; then
  echo "✓ Verification successful: No commits with ducros.m@apple.com found"
else
  echo "⚠️  Warning: Still found $OLD_EMAIL_COUNT commits with old email"
fi

# Show sample of recent commits
echo ""
echo "Recent commits (showing email addresses):"
git log --all --format="%h %an <%ae> - %s" --branches --tags | head -10

echo ""
echo "========================================="
echo "Rewrite Complete!"
echo "========================================="
echo ""
echo "Next steps:"
echo ""
echo "1. Review the changes above to ensure they look correct"
echo ""
echo "2. If everything looks good, force push to remote:"
echo "   git push --force --all origin"
echo "   git push --force --tags origin"
echo ""
echo "3. Clean up backup files:"
echo "   rm -rf .git/refs/original/"
echo "   git reflog expire --expire=now --all"
echo "   git gc --prune=now --aggressive"
echo ""
echo "4. If something went wrong, restore from backup:"
echo "   git checkout $BACKUP_BRANCH"
echo ""
echo "⚠️  WARNING: Force pushing will rewrite remote history!"
echo "   Only proceed if you're sure this is what you want."
echo ""
