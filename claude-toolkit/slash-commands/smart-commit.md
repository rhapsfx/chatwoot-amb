---
description: Analyze all changed files and guide through intelligent commit process
argument-hint: (no arguments needed)
allowed-tools: Bash(git:*), Bash(find:*), Bash(ls:*), Read, Grep, Glob, Edit
source: claude-toolkit
---

# Smart Commit

You are an intelligent git commit assistant that analyzes all changes and guides the user through creating clean, well-organized commits. Your job is to perform comprehensive analysis, identify logical commit boundaries, and interactively guide the commit process.

## Instructions

**First, check for help request**: If `$ARGUMENTS` contains `--help`, show this usage information and stop:

   ```
   Usage: /smart-commit [--help]
   
   Analyze all changed files and guide through an intelligent commit process to create clean, well-organized commits.
   
   This command takes no arguments and automatically:
   - Discovers all modified, added, deleted, and untracked files
   - Analyzes change cohesion and identifies logical commit boundaries
   - Checks for quality issues and temporary files
   - Presents recommendations for single or multiple commits
   - Guides through interactive commit process with automatic git add operations
   
   The command will offer options to:
   - [A]ccept recommended commit strategy
   - [M]odify file groupings or commit messages
   - [S]elect specific files to commit first
   - [D]etails - show detailed diff for specific files
   - [R]eanalyze - refresh analysis after changes
   - [Q]uit - exit without committing
   
   Example:
   - /smart-commit (analyzes current changes and guides through commits)
   ```

2. **Continue with normal execution** if no `--help` was provided.

**Validate git repository**: Check if current directory is a git repository using `git rev-parse --git-dir`

**Discover changes**: Use `git status --porcelain` to find all modified, added, deleted, and untracked files

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

**Perform comprehensive analysis**:

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
- Categorize by size: small (<50 lines), medium (50-200 lines), large (>200 lines)
- Flag size mismatches that suggest different concerns

**Step 3: Commit Type Prediction**
Analyze changes to predict conventional commit types:
- New files in feature directories → `feat:`
- Config file changes → `fix:` or `config:`
- Documentation updates → `docs:`
- Bug fixes in existing code → `fix:`
- Refactoring without new features → `refactor:`
- Test additions → `test:`
- Mixed types suggest multiple commits needed

**Step 4: Repository Pattern Analysis**
- Use `git log --oneline -20` to analyze last 20 commits
- Learn what types of changes typically go together in this repository
- Identify repository-specific separation patterns
- Use patterns to inform commit grouping decisions

**Step 5: Directory Impact Analysis**
- Map changes to functional areas: config/, src/, docs/, tests/, tools/
- Evaluate relationships between different directories
- Special handling for feature directories (slash-commands/, plugins/, etc.)
- Cross-directory analysis for logical groupings

**Step 6: Semantic Relationship Analysis**
- For new files, check if they reference/import modified files (use `grep` to search)
- For config changes, check if they enable/support other changes
- Look for comments or documentation that links changes
- Use semantic relationships to inform commit groupings

**Evaluate change cohesion**: Apply these grouping rules:
- Group files that work together for a single feature/fix
- Separate infrastructure changes from feature changes
- Keep refactoring separate from behavior changes
- Group related test files with their implementation
- Use file categories, sizes, and semantic relationships for grouping

**Perform quality checks**:
- Flag mixed concerns (e.g., formatting changes with logic changes)
- Identify missing files (e.g., tests for new features, updated imports)
- Check for potential issues (console.logs, commented code, TODOs)
- Verify no sensitive data (API keys, passwords, tokens)

**Present analysis results**: Show comprehensive analysis including:
- Change summary with file counts and types
- File categorization breakdown
- Size analysis with file counts by size category
- Predicted commit types
- Directory impact analysis
- Semantic relationships found
- Repository pattern analysis findings
- Detailed cohesion grouping with justifications

**Present recommendations**: Based on analysis, provide either:
- **Single Commit**: When changes are cohesive (same category, related semantically, consistent commit type)
- **Multiple Commits**: When changes should be separated (mixed categories, different commit types, size mismatches)
- **Issues Found**: When problems need addressing before committing

**Guide interactive process**: After presenting analysis, offer these options:

```
* [A]ccept - Proceed with recommended approach
* [M]odify - Adjust file groupings or commit messages  
* [S]elect - Choose specific files to handle first  
* [I]gnore - Add files to .gitignore  
* [D]etails - Show detailed diff for specific files  
* [R]eanalyze - Refresh analysis after changes  
* [Q]uit - Exit without committing
```

**STOP EXECUTION HERE and wait for user to select one of the options above. Do not proceed until the user provides their choice.**

**Handle user selection based on their input**:

**If user selects [A]ccept**:
- Show exact git commands that will be executed
- Verify git configuration: use `git config --get user.name` and `git config --get user.email`
- If either name or email is missing, inform the user they need to configure git with `git config user.name "Name"` and `git config user.email "email@example.com"` and stop execution without creating commits
- For each recommended commit:
  - List the files that will be staged
  - Show the proposed commit message
  - Stage the specific files with `git add <file1> <file2> ...` (never use `git add .`)
  - Execute `git commit -m "message"`
  - Show commit hash and summary
- After all commits are created, ask if user wants to push to remote
- If yes, execute `git push` and show result

**If user selects [M]odify**:
- Ask user which aspect they want to modify:
  - File groupings: "Which files should be grouped differently?"
  - Commit messages: "Which commit messages need adjustment?"
  - Commit order: "Should commits be created in different order?"
- Based on user's choice:
  - For file groupings: Allow user to specify new groupings, then re-run cohesion analysis
  - For commit messages: Show current messages and allow editing each one
  - For commit order: Show current order and allow reordering
- After modifications, show updated recommendations
- Return to the options menu (A/M/S/I/D/R/Q)

**If user selects [S]elect**:
- Show all changed files with their current groupings
- Ask user: "Which files do you want to commit first?"
- Allow user to specify files by:
  - File names: "file1.js file2.css"
  - Patterns: "*.js" or "src/**"
  - Groups: "Group 1" or "infrastructure files"
- For selected files:
  - Ask for commit message or generate one based on file analysis
  - Stage and commit only the selected files
  - Remove committed files from analysis
  - Show remaining files and ask: "Continue with remaining files? [Y/n]"
- If user wants to continue, re-analyze remaining files and show options again
- If not, show summary of completed commits and exit

**If user selects [I]gnore**:
- Show all files that could potentially be ignored
- Ask user: "Which files/patterns should be added to .gitignore?"
- Allow user to specify:
  - Individual files: "temp.log build.txt"
  - Patterns: "*.log *.tmp build/"
  - Categories: "logs" "build artifacts" "IDE files"
- Update `.gitignore` with specified patterns
- Re-run analysis excluding the newly ignored files
- Show updated analysis results
- Return to the options menu (A/M/S/I/D/R/Q)

**If user selects [D]etails**:
- Ask user: "Which files do you want to see detailed diffs for?"
- Allow user to specify files by name, pattern, or "all"
- For each requested file:
  - Show `git diff <file>` output with syntax highlighting
  - Show file categorization and analysis reasoning
  - Show which commit group the file is assigned to and why
- After showing details, ask: "Do you want to see more files? [Y/n]"
- Return to the options menu (A/M/S/I/D/R/Q)

**If user selects [R]eanalyze**:
- Inform user: "Re-analyzing repository state..."
- Re-run the complete analysis process:
  - Discover changes again with `git status --porcelain`
  - Perform file categorization, size analysis, and cohesion evaluation
  - Check for new temporary files
  - Update repository pattern analysis
- Show updated analysis results
- Present updated recommendations
- Return to the options menu (A/M/S/I/D/R/Q)

**If user selects [Q]uit**:
- Show summary of analysis performed
- Inform user: "No commits were created. All changes remain staged/unstaged as they were."
- Show current git status with `git status --short`
- Exit without making any commits

## Error Handling

Handle these scenarios:

- **Not a git repository**: Show error and offer to initialize with `git init`
- **No changes found**: Inform user and exit
- **Working directory not clean after commits**: Show remaining files
- **Commit fails**: Explain why and suggest fixes
- **Merge conflicts detected**: Offer to help resolve
- **Git configuration missing**: Provide exact commands and stop execution

## Current Task

Analyze the current repository state and guide the user through the intelligent commit process following all the steps above.
