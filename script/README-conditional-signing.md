# Conditional Git Signing - Quick Reference

## Quick Install

```bash
sudo script/install-conditional-signing.sh
```

## Quick Uninstall

```bash
sudo script/uninstall-conditional-signing.sh
```

## What It Does

- ✅ **Apple repositories** (`*.apple.com`): Commits are signed with `ac-sign`
- ⏭️  **Other repositories** (GitHub, GitLab, etc.): Signing is bypassed

## How It Works

The wrapper script replaces `/usr/local/bin/ac-sign` and:
1. Checks if the current repository has an `apple.com` remote
2. If yes → calls the original `ac-sign` binary (backed up as `ac-sign-original`)
3. If no → bypasses signing and allows commit to proceed

## Files Created

- `/usr/local/bin/ac-sign` - Wrapper script (replaces original)
- `/usr/local/bin/ac-sign-original` - Original binary (backup)

## Testing

```bash
# In an Apple repository
cd /path/to/apple/repo
git commit -m "Test" # Should be signed

# In a GitHub repository  
cd /path/to/github/repo
git commit -m "Test" # Should NOT be signed

# Verify signature
git log --show-signature -1
```

## Troubleshooting

**Check installation:**
```bash
ls -l /usr/local/bin/ac-sign*
file /usr/local/bin/ac-sign  # Should be a shell script
```

**Check remote URLs:**
```bash
git remote -v  # Look for apple.com
```

**Restore original:**
```bash
sudo script/uninstall-conditional-signing.sh
```

## Full Documentation

See [`docs/conditional-git-signing.md`](../docs/conditional-git-signing.md) for complete documentation.