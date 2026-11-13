# Claude Code Custom Slash Commands: `allowed-tools` Syntax and Command Types

## YAML Frontmatter for Custom Commands

In Claude Code, custom slash commands are defined as Markdown files (with .md extension) in either the project’s `.claude/commands/` directory or the user’s `~/.claude/commands/` directory. The filename (minus .md) becomes the command name (e.g. a file `fix-issue.md` defines a `/fix-issue` command). These command files can include a YAML front-matter section (between --- lines at the top) to specify metadata such as allowed tools, description, and argument hints. For example, a command file might begin like this:

```yaml
---
allowed-tools: Bash(git add:*), Bash(git status:*), Bash(git commit:*)
description: Create a git commit
argument-hint: <issue-number>  # optional hint for expected arguments
---
```

In this snippet, the YAML front-matter defines three fields:
* `allowed-tools` – A list of tools that the command is permitted to use (with optional filters, described below).
* `description` – A brief description of the command’s purpose (displayed in help or UI).
* `argument-hint` – A hint string showing the expected arguments format, which helps when auto-completing the command.

Other than the front-matter, the rest of the file contains the actual prompt or instructions for Claude. You can include dynamic content in the prompt using special prefixes (for instance, using `!` to run shell commands or `@` to include file contents) as needed.

## Correct Syntax for the `allowed-tools` Field

The `allowed-tools` field in the command’s YAML front-matter defines which tools Claude is allowed to invoke while executing that custom command. According to Anthropic’s official documentation, `allowed-tools` should be a list of tool permissions that the command can use. In practice, this is typically written as a single line with comma-separated entries, where each entry specifies a tool name and an optional filter in parentheses. The correct syntax is:
* Tool Name – The name of a Claude Code tool (e.g. Bash, Edit, Write, etc.).
* Optional filter in parentheses – A way to restrict the tool’s usage to specific commands or patterns.

Examples: The official docs show the following example for a slash command that will run some Git-related shell commands before executing:

```yaml
---
allowed-tools: Bash(git add:*), Bash(git status:*), Bash(git commit:*)
description: Create a git commit
---
```

This means the custom command is allowed to use the Bash tool, but only for running the specific Git commands listed – namely `git add ...`, `git status ...`, and `git commit ...` (the `*` acts as a wildcard to allow any arguments after those commands). If the command’s Markdown content includes lines like `!git status` or other shell commands (using the `!`prefix), you must include `allowed-tools` for the Bash tool in this way; otherwise Claude will not run them (it would normally prompt for permission).

In general, each entry in `allowed-tools` can be one of:
* A bare tool name (which would allow that tool with no restrictions). For example, `allowed-tools: Edit` would permit using the Edit tool without restriction (useful if the command may auto-edit files).
* A tool name followed by `(*)` – this explicitly allows all actions of that tool (equivalent to no restrictions). For instance, `Bash(*)` would allow any Bash command (though this is risky and usually not recommended).
* A tool name with a specific filter in parentheses – this restricts the tool to certain commands or paths. For example, `Bash(ls *)` would allow only ls commands, `Write(src/*)` could restrict the Write tool to files in the `src/` directory, etc. ￼. The filter syntax typically matches command prefixes or file path patterns as applicable.

Multiple tools can be allowed by separating them with commas in the `allowed-tools` line (as shown in the Git example above). You can also format them as a YAML list if preferred, for example:

```yaml
allowed-tools:
  - Bash(git push)     # allow only 'git push' command via Bash
  - WebFetch           # allow using the WebFetch tool
```

Under the hood, Claude Code’s permission system uses these rules to decide if a tool action is permitted. If a tool action isn’t whitelisted by your `allowed-tools` (and isn’t inherently safe/always allowed), Claude will either ask for confirmation or refuse to execute that part of the command. In summary, use the `allowed-tools` field to whitelist the exact tools and operations your custom command may perform, using the `ToolName(filter)` syntax for fine-grained control.

## Officially Supported Command Types (Tools)

Claude Code comes with a set of built-in tools (sometimes referred to as command types or actions) that it can use to interact with your code and environment. These are the tool names you would use in the `allowed-tools` field or see when Claude requests permission. According to the official documentation, the full list of supported tools (as of 2025) includes:
* Bash – Executes shell commands in your environment (e.g. running terminal commands). Permission required: Yes.
* Edit – Makes targeted edits to specific files (like an in-place file modification). Permission required: Yes.
* Glob – Finds files based on a pattern (filename matching). Permission required: No.
* Grep – Searches for text patterns within file contents. Permission required: No.
* LS – Lists files and directories (basic directory listing). Permission required: No.
* MultiEdit – Performs multiple edits in a single file atomically (batch edits). Permission required: Yes.
* NotebookEdit – Modifies Jupyter Notebook cells. Permission required: Yes.
* NotebookRead – Reads and displays Jupyter Notebook content. Permission required: No.
* Read – Reads the contents of files (essentially file viewing). Permission required: No.
* Task – Runs a sub-agent to handle a complex multi-step task (essentially delegating to a specialized agent). Permission required: No.
* TodoWrite – Creates or updates structured TODO lists (task list management). Permission required: No.
* WebFetch – Fetches content from a URL (makes an HTTP GET request to retrieve data). Permission required: Yes.
* WebSearch – Performs web searches (with certain domain restrictions). Permission required: Yes.
* Write – Creates or overwrites files (write file content). Permission required: Yes.

These are the official tool names recognized by Claude Code for agent actions. When writing `allowed-tools` in a slash command’s front-matter, you should use these names (and not informal aliases) to whitelist tools. For instance, to let your command modify files you might include Edit or Write in the `allowed-tools` list; to allow shell execution you’d include Bash(...) (possibly restricted to specific commands as discussed).

Note that some tools do not require permission by default (marked “No” above) – those are generally read-only or safe operations (like reading files, listing directories, searching text, etc.). Tools that can alter your system or external state (like running shell commands, editing/writing files, or accessing the web) require explicit permission – hence those must be listed in `allowed-tools` if you want the custom command to run them without prompting.

In summary, Claude Code’s supported command tools include everything from file operations (Read, Write, Edit), to shell execution (Bash), search utilities (Glob, Grep, WebSearch), networking (WebFetch), and even sub-agent orchestration (Task, TodoWrite). To properly structure a custom slash command, ensure your command’s YAML front-matter uses the exact `allowed-tools` syntax with the appropriate tool names and filters, and provides a description and argument hint if needed. This will allow Claude to execute your custom command safely and effectively, leveraging the allowed tools as intended by the official Claude Code protocol.
