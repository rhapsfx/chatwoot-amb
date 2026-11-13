---
description: Quickly prepares commit for simple changes in the project
argument-hint: [message] [--only-tracked] [--push]
allowed-tools: Bash(git:*), Bash(find:*), Bash(ls:*), Read, Grep, Glob, Edit
source: claude-toolkit
---

# Quick Commit

You are a git commit assistant that quickly prepares and creates commits for simple, cohesive changes. Your job is to analyze the current changes, ensure they are suitable for a quick commit, and execute the commit process automatically.

## Instructions

**First, check for help request**: If `$ARGUMENTS` contains `--help`, show this usage information and stop:

   ```
   Usage: /quick-commit [message] [--only-tracked] [--push] [--help]
   
   Quickly prepares and creates a commit for simple changes in the project.
   
   This command is designed for simple, cohesive changes. For complex changes
   affecting multiple concerns, use /smart-commit instead.
   
   Arguments:
   - message: Optional commit message (if not provided, will generate one)
   - --only-tracked: Stage only tracked files (default: stage both tracked and untracked)
   - --push: Push to remote repository after committing
   - --help: Show this help message and exit
   
   Examples:
   - /quick-commit
   - /quick-commit "Fix typo in README"
   - /quick-commit --only-tracked
   - /quick-commit "Update dependencies" --push
   - /quick-commit --only-tracked --push
   ```

2. **Continue with normal execution** if no `--help` was provided.

**Parse the arguments**: Extract the commit message and flags from `$ARGUMENTS`

**Validate git repository**: Check if current directory is a git repository using `git rev-parse --git-dir`

**Check repository status**: 
- Run `git status --porcelain` to check for changes
- If no changes, inform the user and stop

**Detect temporary files**: 
- Use `git status --porcelain` output to identify files that match common temporary file patterns:
  - OS files: `.DS_Store`, `Thumbs.db`, `desktop.ini`
  - Build artifacts: `dist/`, `build/`, `out/`, `target/`
  - Dependencies: `node_modules/`, `vendor/`, `.pnpm-store/`
  - IDE files: `.vscode/`, `.idea/`, `*.swp`, `*.swo`
  - Log files: `*.log`, `*.log.*`, `logs/`
  - Cache files: `*.cache`, `.cache/`, `.parcel-cache/`
  - Environment files: `.env.local`, `.env.*.local`

For any temporary files found in git status:
- Check if their patterns are already present in `.gitignore` (read the file if it exists)
- If patterns are already in `.gitignore`, do nothing and continue
- If patterns are NOT in `.gitignore`, ask the user if they want to add them
- If user confirms, update `.gitignore` automatically and continue
- If user declines, continue without staging these files

**Analyze change cohesion**: Determine if changes are suitable for quick commit by performing this analysis:

**Step 1: File Categorization**
Use `git status --porcelain` to analyze each file and categorize:
- **NEW_FEATURE**: New files (status 'A') in feature directories (slash-commands/, src/, lib/, components/)
- **INFRASTRUCTURE**: Config files (.json, .yml, .toml, .config.js, .claude/settings.json)
- **MAINTENANCE**: Modified files (status 'M') in existing feature directories
- **DOCUMENTATION**: .md files (except in feature directories), README files
- **TESTS**: Files in *test*, *spec*, __tests__ directories
- **BUILD**: package.json, Makefile, build scripts, CI files

**Step 2: Size Analysis**
For files with git status 'A' (new/added):
- Use `wc -l` to count lines in new files
- Flag as mixed if new files >50 lines are mixed with small changes elsewhere
- Flag as mixed if new files >100 lines + config changes
- Flag as mixed if new files >200 lines + maintenance updates
- Exception: Related files (e.g., src/auth.js + src/auth.test.js)

**Step 3: Commit Type Prediction**
Analyze changes to predict conventional commit types:
- New files in feature directories → `feat:`
- Config file changes → `fix:` or `config:`
- Documentation updates → `docs:`
- Bug fixes in existing code → `fix:`
- Refactoring without new features → `refactor:`
- Test additions → `test:`
- Flag as mixed if multiple different types detected

**Step 4: Repository Pattern Analysis**
- Use `git log --oneline -20` to analyze last 20 commits
- Look for patterns in commit messages and file changes
- Learn what types of changes typically go together in this repository
- Compare current changes against learned patterns

**Step 5: Directory Impact Analysis**
- Map changes to functional areas: config/, src/, docs/, tests/, tools/
- Evaluate if changes spanning multiple functional areas are related
- Special handling for feature directories (slash-commands/, plugins/, etc.)
- Flag as mixed: feature directories + config directories = likely mixed

**Step 6: Semantic Relationship Analysis**
- For new files, check if they reference/import modified files (use `grep` to search)
- For config changes, check if they enable/support other changes
- Look for comments or documentation that links changes
- Flag as mixed if no semantic relationship found between different categories

**Step 7: Apply Mixed-Concern Detection**
Flag as MIXED if any of these patterns are detected:
- New feature files (>50 lines) + config maintenance = MIXED
- New .md files in feature directories + JSON config changes = MIXED  
- Large new files + small updates to existing files = MIXED
- Different file extensions with different purposes = MIXED
- New files in slash-commands/ should typically be standalone commits
- Config changes in .claude/ should be separate from feature additions

**If changes are NOT cohesive**, show this detailed error message and stop:
   ```
   ⚠️ Changes Not Suitable for Quick Commit
   
   Analysis Results:
   📊 Change Categories: [list detected categories]
   📏 Size Analysis: [e.g., 285 line new file + 37 lines config changes]
   🏷️ Commit Types: [e.g., feat: + fix: (mixed types)]
   📁 Directories: [e.g., slash-commands/ + .claude/ + multiple (cross-functional)]
   🔗 Relationship: [e.g., No semantic relationship detected]
   
   Specific Issues Found:
   [List specific issues found]
   
   Recommended Split:
   [Provide specific commit structure with exact file groupings]
   
   Repository Pattern Analysis:
   [Based on recent commits]
   
   For complex changes like these, please use /smart-commit instead.
   ```

**If changes are cohesive**, proceed with the commit:

**Stage the files**:
- If `--only-tracked` flag is present: use `git add -u` (tracked files only)
- Otherwise: use `git add -A` (both tracked and untracked files)
- Exclude any temporary files that weren't added to .gitignore

**Generate commit message** (if not provided):
- Analyze changed files using `git diff --name-only --cached`
- Generate a descriptive commit message based on file types and changes
- Follow conventional commits format when appropriate
- Examples: "docs: update README", "fix: resolve configuration issue", "feat: add user validation"

**Create the commit**:
- First, verify git configuration: use `git config --get user.name` and `git config --get user.email` to ensure user identity is configured
- If either name or email is missing, inform the user they need to configure git with `git config user.name "Name"` and `git config user.email "email@example.com"` and stop execution without creating a commit
- Use the provided message or generated message
- Execute `git commit -m "message"`
- Show commit summary with hash and stats

**Push to remote** (if `--push` flag is present):
- Check if remote exists: `git remote -v`
- Check if current branch has upstream: `git branch -vv`
- Push to current branch: `git push`
- Show push result

**Show final status**:
- Display commit hash and message
- Show files that were committed
- If pushed, show remote status

## Error Handling

Handle these common error scenarios:

- **Not a git repository**: Show error and suggest `git init`
- **No changes to commit**: Inform user that working directory is clean
- **Changes not cohesive**: Explain issues and recommend `/smart-commit`
- **Temporary files found**: Offer to update `.gitignore`
- **Merge conflicts**: Show conflict files and suggest resolution
- **Push failures**: Show error details and suggest solutions
- **Sensitive data detected**: Warn and refuse to commit

## Current Task

Analyze the arguments: `$ARGUMENTS`

Execute the quick commit process following all the steps above.
