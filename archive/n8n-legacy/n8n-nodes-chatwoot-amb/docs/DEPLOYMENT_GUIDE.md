# Deployment Guide: Chatwoot AMB Template Message Node

**Version**: 1.0.0
**Last Updated**: 2025-01-07

This guide covers building, testing, and deploying the Chatwoot AMB Template Message node to npm and n8n community repository.

## Prerequisites

- Node.js >= 18.0.0
- npm or pnpm
- Git
- npm account (for publishing)
- Access to n8n-nodes-chatwoot-amb repository

## Development Setup

### 1. Clone Repository

```bash
cd /Users/rhaps/LocalGit/chatwoot/n8n-nodes-chatwoot-amb
```

### 2. Install Dependencies

```bash
npm install
```

### 3. Verify Structure

```bash
# Check new node file exists
ls -la nodes/ChatwootAMBFileAttachment/

# Should show:
# ChatwootAMBFileAttachment.node.ts
```

## Build Process

### 1. Compile TypeScript

```bash
npm run build
```

This will:
- Compile all `.ts` files to `.js`
- Generate `.d.ts` type definitions
- Copy icons to `dist/`
- Output to `dist/` directory

**Expected output:**
```
✓ TypeScript compilation successful
✓ Icons copied to dist/
✓ Build complete
```

### 2. Verify Build Output

```bash
ls -la dist/nodes/ChatwootAMBFileAttachment/

# Should show:
# ChatwootAMBFileAttachment.node.js
# ChatwootAMBFileAttachment.node.d.ts
```

### 3. Check for Errors

```bash
npm run lint
```

Fix any linting errors:
```bash
npm run lintfix
```

## Testing

### 1. Unit Testing (if tests exist)

```bash
npm test
```

### 2. Manual Testing with n8n

#### Option A: Link for Local Testing

```bash
# In package directory
npm link

# In n8n directory
cd ~/.n8n/custom
npm link n8n-nodes-chatwoot-amb

# Restart n8n
```

#### Option B: Install Locally in n8n

```bash
cd ~/.n8n/nodes
npm install /Users/rhaps/LocalGit/chatwoot/n8n-nodes-chatwoot-amb
```

### 3. Test in n8n UI

1. Start n8n: `n8n start`
2. Open browser: `http://localhost:5678`
3. Create new workflow
4. Search for "Chatwoot AMB Template Message"
5. Verify node appears with correct icon and parameters
6. Test execution with real Chatwoot instance

**Test Checklist:**
- [ ] Node appears in node list
- [ ] Icon displays correctly
- [ ] All parameters render correctly
- [ ] Credentials work
- [ ] Template ID selection works
- [ ] Template search works
- [ ] Parameters are passed correctly
- [ ] Response returns expected data
- [ ] Error handling works (Continue on Fail)
- [ ] Validation option works

## Pre-Publish Checklist

### 1. Version Update

Update version in `package.json`:

```json
{
  "version": "1.1.0"
}
```

Follow semantic versioning:
- **Major** (2.0.0): Breaking changes
- **Minor** (1.1.0): New features, backward compatible
- **Patch** (1.0.1): Bug fixes only

### 2. Update CHANGELOG

Create or update `CHANGELOG.md`:

```markdown
## [1.1.0] - 2025-01-07

### Added
- New Chatwoot AMB Template Message node
- Support for pre-uploaded template attachments
- Template search by name
- Parameter substitution
- Template validation option
- Enhanced response metadata

### Documentation
- Added TEMPLATE_MESSAGE_NODE.md
- Added QUICK_START_TEMPLATE_MESSAGE.md
- Added example workflows
```

### 3. Update README

Add to main README.md:

```markdown
## Features

This package provides custom n8n nodes for all Apple Messages for Business rich message types:

- **📋 List Picker** - Interactive lists with images and sections
- **📅 Time Picker** - Appointment scheduling with time slots
- **⚡ Quick Reply** - Quick action buttons
- **📝 Form** - Multi-field data collection forms
- **💳 Apple Pay** - Payment requests
- **🔗 Rich Link** - Web links with rich previews
- **📄 Template Message** - Pre-configured templates with attachments ✨ NEW
```

### 4. Documentation Review

Ensure all docs are complete:
- [ ] `/docs/TEMPLATE_MESSAGE_NODE.md` - Complete API reference
- [ ] `/docs/QUICK_START_TEMPLATE_MESSAGE.md` - Quick start guide
- [ ] `/examples/*.json` - Example workflows
- [ ] `README.md` - Updated with new node
- [ ] `CHANGELOG.md` - Version changes documented

### 5. Code Quality

```bash
# Run linter
npm run lint

# Format code
npm run format

# Run tests
npm test
```

### 6. Build Clean

```bash
# Clean previous build
rm -rf dist/

# Fresh build
npm run build
```

## Publishing to npm

### 1. Login to npm

```bash
npm login
```

Enter credentials for npm account.

### 2. Dry Run

Test publish without actually publishing:

```bash
npm publish --dry-run
```

Review output:
- Check included files
- Verify dist/ folder is included
- Ensure no sensitive files (secrets, .env, etc.)

### 3. Publish

```bash
npm publish
```

**Output:**
```
+ n8n-nodes-chatwoot-amb@1.1.0
```

### 4. Verify on npm

Visit: https://www.npmjs.com/package/n8n-nodes-chatwoot-amb

Check:
- Version is updated
- Files are included
- README displays correctly

## Post-Publish Steps

### 1. Tag Release in Git

```bash
git tag v1.1.0
git push origin v1.1.0
```

### 2. Create GitHub Release

1. Go to: https://github.com/chatwoot/n8n-nodes-chatwoot-amb/releases
2. Click "Draft a new release"
3. Choose tag: `v1.1.0`
4. Title: `v1.1.0 - Template Message Node`
5. Description: Copy from CHANGELOG.md
6. Attach built package (optional)
7. Click "Publish release"

### 3. Update Documentation

Update external documentation:
- Chatwoot docs
- Blog post (if applicable)
- Community announcements

### 4. Notify Users

Announce in:
- Chatwoot Discord/Slack
- n8n Community forum
- GitHub Discussions
- Twitter/LinkedIn

## Updating Existing Installation

Users can update to new version:

```bash
# Via n8n Community Nodes UI
# 1. Go to Settings → Community Nodes
# 2. Click "Update" next to n8n-nodes-chatwoot-amb

# Or via npm (self-hosted)
cd ~/.n8n/nodes
npm update n8n-nodes-chatwoot-amb
```

## Rollback (if needed)

If critical issues found after publish:

### 1. Deprecate Bad Version

```bash
npm deprecate n8n-nodes-chatwoot-amb@1.1.0 "Critical bug, use 1.0.0 instead"
```

### 2. Publish Fixed Version

```bash
# Fix issues
# Update version to 1.1.1
npm publish
```

### 3. Notify Users

Post announcement about the issue and fix.

## Maintenance Releases

For bug fixes or minor updates:

1. Create branch: `git checkout -b fix/template-node-bug`
2. Make fixes
3. Test thoroughly
4. Update version (patch)
5. Update CHANGELOG
6. Create PR
7. Merge to main
8. Publish new version
9. Tag release

## Troubleshooting Build Issues

### TypeScript Compilation Errors

```bash
# Check tsconfig.json is correct
cat tsconfig.json

# Ensure all imports are correct
# Check for missing type definitions
npm install --save-dev @types/node
```

### Missing Files in Build

Check `package.json` files field:

```json
{
  "files": [
    "dist"
  ]
}
```

### Icon Not Showing

Verify icon is copied to dist:

```bash
ls -la dist/nodes/ChatwootAMBFileAttachment/
# Should see amb.svg or similar
```

Check gulpfile.js includes icon copy task.

### Node Not Appearing in n8n

1. Check `package.json` n8n section:
```json
{
  "n8n": {
    "nodes": [
      "dist/nodes/ChatwootAMBFileAttachment/ChatwootAMBFileAttachment.node.js"
    ]
  }
}
```

2. Restart n8n completely
3. Clear n8n cache: `rm -rf ~/.n8n/cache`

## Support After Release

Monitor for issues:
- GitHub Issues
- npm download stats
- User feedback
- Bug reports

Respond to:
- Support requests
- Feature requests
- Bug reports
- Documentation clarifications

## Release Schedule

Suggested release cadence:
- **Major versions**: Every 6-12 months
- **Minor versions**: Every 1-2 months (new features)
- **Patch versions**: As needed (bug fixes)

## Security Considerations

Before publishing:
- [ ] No hardcoded credentials
- [ ] No API tokens in code
- [ ] No sensitive data in examples
- [ ] Dependencies are up-to-date
- [ ] No known security vulnerabilities

Run security audit:
```bash
npm audit
npm audit fix
```

## Checklist Summary

**Pre-Build:**
- [ ] Code complete and tested
- [ ] Version updated
- [ ] CHANGELOG updated
- [ ] README updated
- [ ] Documentation complete
- [ ] Linting passed
- [ ] Tests passed

**Build:**
- [ ] Clean build successful
- [ ] Dist files generated
- [ ] Icons copied
- [ ] No build errors

**Pre-Publish:**
- [ ] Dry run successful
- [ ] Files list verified
- [ ] npm login successful
- [ ] No sensitive files included

**Publish:**
- [ ] npm publish successful
- [ ] Package visible on npm
- [ ] Version correct
- [ ] README displays

**Post-Publish:**
- [ ] Git tag created
- [ ] GitHub release created
- [ ] Documentation updated
- [ ] Users notified
- [ ] Monitoring setup

---

**Questions or issues? Open an issue on GitHub or reach out to the maintainers.**
