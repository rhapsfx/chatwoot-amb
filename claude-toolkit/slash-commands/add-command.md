---
description: Create a new Claude Code slash command
argument-hint: scope command-name [--namespace <namespace>] [--description "<description>"] [--template <type>]
allowed-tools: Read, Edit, Glob, Grep, Task, Write, Bash(find:*), Bash(ls:*), Bash(test:*)
source: claude-toolkit
---

# Add Command Helper

You are helping me create a new Claude Code slash command. Follow these step-by-step instructions to parse arguments and create the command file.

## Step-by-Step Instructions

### Step 1: Parse Arguments (ALWAYS FIRST)

Arguments provided by the user: `$ARGUMENTS`

**Parse the arguments immediately.** Expected format: `<scope> <name> [options]`

- `<scope>`: Must be either `project` or `user` 
- `<name>`: Command name (alphanumeric, hyphens allowed)
- Options: `--namespace <namespace>`, `--description "<description>"`, `--template <type>`

**If parsing fails or arguments are invalid:**
- Display usage information (see Step 2)
- STOP - do not proceed further

### Step 2: Handle Help Requests or Missing Arguments

**If arguments is empty or contains `--help`:**
- Display the following usage information
- STOP - do not proceed further

**Usage information to display:**
```
Usage: /add-command <scope> <name> [options]

Arguments:
- <scope>: Either 'project' or 'user'
- <name>: The command name (alphanumeric, hyphens allowed)

Options:
- --namespace <namespace>: For organizing commands in subdirectories
- --description "<description>": Brief description of the command
- --template <type>: Use a predefined template

Available Templates:
- code-review: For reviewing code with focus areas specified in arguments
- bug-report: For generating structured bug reports  
- documentation: For creating or updating documentation
- security-audit: For security-focused code analysis
- optimization: For performance and optimization suggestions
- test-generation: For generating test cases

Examples:
- /add-command project my-review --template code-review
- /add-command user helper --namespace tools --description "Personal helper"
- /add-command project deploy --namespace ci --template documentation
```

### Step 3: Determine Template Path

**Based on parsed arguments:**

**If `--template` was specified:**
- Jump to Step 6 (Create Command File) 
- Use the corresponding template content from the Templates section below

**If NO `--template` was specified:**
- Proceed to Step 4 (Custom Command Creation)
- User wants a custom command, not a template

### Step 4: Custom Command Creation (NO Template)

**When no template is specified, you MUST gather requirements from the user.**

ASK the user these questions in sequence, one question at a time. Do not proceed until answered.

SKIP question 1 and proceed to question 2, if command description was given through arguments.

1. **"What should this command do? Provide a brief description."**
2. **"What arguments should this command accept? (e.g., file paths, options, etc.)"**  
3. **"What tools will this command need to use?"** (e.g., `Bash`, `Read`, `Write`, `Grep`, `Glob`, etc.)
4. **"Do you need any dynamic content in the command?"**
   - **Bash commands**: Use `&#33;` prefix for command output (e.g., `&#33;git status`)
   - **File references**: Use `&#64;` prefix for file contents (e.g., `&#64;src/file.js`)

**After receiving all answers:**
- Proceed to Step 5 (Create Custom Command Structure)

### Step 5: Create Custom Command Structure

**Use the user's responses from Step 4 to create a command file structure:**

1. **YAML Frontmatter** (required):
   ```yaml
   ---
   description: [User-provided description from question 1]
   argument-hint: [Based on user's argument requirements from question 2]
   allowed-tools: [Only if tools are needed from question 3]
   source: claude-toolkit
   ---
   ```

2. **Command Content** (markdown format):
   
   **CRITICAL: Write imperative instructions, not specifications or descriptions.**
   
   **Writing Style Requirements:**
   - **Address "you" directly** - Write instructions that speak to the AI assistant reading the command
   - **Use active voice only** - Never use passive voice for instructions 
   - **Make every instruction actionable** - Each sentence should tell the AI assistant what to do
   - **Use command verbs** - Start instructions with action words: "Parse", "Check", "Create", "Analyze", "Generate"
   - **Be specific and concrete** - Avoid vague language like "should be done" or "might need to"
   - **Write step-by-step tasks** - Break complex operations into numbered steps
   
   **Content Structure:**
   - Brief imperative introduction telling the AI assistant what to do (1-2 sentences)
   - Fixed instruction: "Arguments provided by the user: `&#36;ARGUMENTS`"
   - Clear parsing instructions: "Parse the arguments to extract..."
   - Specific task instructions: "You must..." or "Follow these steps:"
   - Any dynamic content using `&#33;`, `&#64;` from question 4
   
   **Variable Reference Convention:**
   - Use HTML entity encoding for exclamation sign when referring to `&#33;` literally: `\&\#33;`
   - Use HTML entity encoding for at sign when referring to `&#64;` literally: `\&\#64;`
   - Use HTML entity encoding for dollar sign when referring to `&#36;ARGUMENTS` literally: `\&\#36;ARGUMENTS`
   - Use without encoding when you want actual substitution: `&#36;ARGUMENTS`
   
   **Good Examples:**
   - ✅ "Parse the file path from `&#36;ARGUMENTS` and validate it exists"
   - ✅ "Check the current git status: &#33;git status"
   - ✅ "Read the configuration file: &#64;config.json"
   - ✅ "Generate a summary of the changes and create a commit message"
   
   **Bad Examples:**
   - ❌ "The file path should be parsed from arguments"
   - ❌ "Git status can be checked"
   - ❌ "A summary might be generated"
   - ❌ "Configuration should be reviewed"

**Validation Checklist - Ensure:**
- [ ] YAML frontmatter is properly formatted with required fields
- [ ] `description` field is concise but descriptive  
- [ ] `argument-hint` matches the expected usage pattern
- [ ] `allowed-tools` includes only necessary tools
- [ ] `source` is present and equals to `claude-toolkit`
- [ ] Dynamic content uses proper prefixes (`&#33;`, `&#64;`, `&#36;ARGUMENTS`)
- [ ] Instructions are clear for Claude to execute

**Then proceed to Step 6.**

### Step 6: Determine File Path and Check Repository

**Calculate the target file path based on scope and namespace:**

- **For `project` scope**: `.claude/commands/[namespace/]<name>.md`
- **For `user` scope**: `~/.claude/commands/[namespace/]<name>.md`

**SPECIAL CHECK for claude-code-toolkit Repository:**

**Use the `Bash` tool to check if current directory is claude-code-toolkit:**
```bash
test -L .claude/commands && readlink .claude/commands
```

**If `.claude/commands` is a symbolic link to `slash-commands`:**
- Display this warning to the user
- WAIT for user confirmation before proceeding

```
WARNING: You are in the claude-code-toolkit repository where .claude/commands is a symbolic link to slash-commands/.

Creating a 'project' scope command here will add it to the slash-commands/ directory.

Recommendations:
- **For `user` scope instead: /add-command user <name> [options]**  
- Or work in a different project directory

Continue anyway? (This will create the file in slash-commands/)
```

**If user says NO:** STOP - do not create the file
**If user says YES:** Continue to Step 7

### Step 7: Create Directory Structure

**Use the `Bash` tool to create the directory structure if needed:**

- For project scope: `mkdir -p .claude/commands/[namespace]` (if namespace provided)
- For user scope: `mkdir -p ~/.claude/commands/[namespace]` (if namespace provided)

**If directory creation fails:** 
- Report the error to the user
- STOP - do not proceed further

### Step 8: Create Command File

**Use the `Write` tool to create the command file with appropriate content:**

**If using a template:**
- Use the exact template content from the Templates section below
- Replace `<scope>`, `<namespace>`, `<name>` placeholders in usage examples

**If creating custom command:**
- Use the structure created in Step 5
- Include the YAML frontmatter and markdown content

**If file creation fails:**
- Report the error to the user  
- STOP - do not proceed further

### Step 9: Confirm Creation and Provide Instructions

**Display confirmation information:**

1. **File location**: Show the exact file path where the command was created
2. **Command name**: Show what the resulting slash command will be called
   - Project with namespace: `/namespace:name`
   - Project without namespace: `/name` 
   - User with namespace: `/namespace:name`
   - User without namespace: `/name`
3. **Usage instructions**: Explain how to use the new command
4. **RESTART REMINDER**: **CRITICAL** - Remind the user that they must restart Claude Code for the new command to become effective

**Example confirmation:**
```
✅ Command created successfully!

File: ~/.claude/commands/tools/my-helper.md
Command: /tools:my-helper
Usage: /tools:my-helper [your-arguments]

⚠️  IMPORTANT: You must restart Claude Code for this command to become available.
```

## Templates Available

### code-review
For reviewing code with focus areas specified in arguments.

### bug-report  
For generating structured bug reports.

### documentation
For creating or updating documentation. 

### security-audit
For security-focused code analysis.

### optimization
For performance and optimization suggestions.

### test-generation
For generating test cases.

## Template Content

### code-review template:
```markdown
---
description: Review code with specific focus areas
argument-hint: <focus-areas>
---

# Code Review Command

Review code with specific focus areas. Usage: `/scope:namespace:name <focus-areas>`

## Focus Areas
- security: Check for security vulnerabilities
- performance: Analyze performance implications
- maintainability: Assess code maintainability
- best-practices: Verify adherence to best practices
- tests: Evaluate test coverage and quality

Provide a structured review addressing the specified focus areas.
```

### bug-report template:
```markdown
---
description: Generate a structured bug report
argument-hint: <issue-description>
---

# Bug Report Generator

Generate a structured bug report. Usage: `/scope:namespace:name <issue-description>`

## Bug Report Template

### Issue Summary
Brief description of the problem.

### Steps to Reproduce
1. Step one
2. Step two
3. Step three

### Expected Behavior
What should happen.

### Actual Behavior
What actually happens.

### Environment
- OS: 
- Version: 
- Browser (if applicable): 

### Additional Context
Any other relevant information.
```

### documentation template:
```markdown
---
description: Create or update documentation
argument-hint: <content-type>
---

# Documentation Command

Create or update documentation. Usage: `/scope:namespace:name <content-type>`

## Content Types
- api: API documentation
- setup: Setup/installation instructions
- usage: Usage examples and guides
- troubleshooting: Common issues and solutions

Generate comprehensive documentation for the specified content type.
```

### security-audit template:
```markdown
---
description: Perform security-focused code analysis
argument-hint: <audit-type>
---

# Security Audit Command

Perform security-focused code analysis. Usage: `/scope:namespace:name <audit-type>`

## Audit Types
- dependencies: Check for vulnerable dependencies
- authentication: Review authentication mechanisms
- authorization: Analyze access controls
- data-protection: Assess data handling and encryption
- injection: Look for injection vulnerabilities
- comprehensive: Full security review

Provide detailed security findings and recommendations.
```

### optimization template:
```markdown
---
description: Analyze code for performance improvements
argument-hint: <optimization-type>
---

# Optimization Command

Analyze code for performance improvements. Usage: `/scope:namespace:name <optimization-type>`

## Optimization Types
- performance: Runtime performance improvements
- memory: Memory usage optimization
- database: Database query optimization
- network: Network call optimization
- bundle: Bundle size optimization

Provide specific optimization recommendations with examples.
```

### test-generation template:
```markdown
---
description: Generate test cases for code
argument-hint: <test-type>
---

# Test Generation Command

Generate test cases for code. Usage: `/scope:namespace:name <test-type>`

## Test Types
- unit: Unit tests for individual functions/classes
- integration: Integration tests for component interactions
- e2e: End-to-end tests for user workflows
- edge-cases: Edge case and error condition tests

Generate comprehensive test cases with proper assertions and mock data.
```
