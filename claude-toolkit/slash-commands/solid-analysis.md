---
description: Analyze code for SOLID principles adherence with detailed assessment and refactoring guidance
argument-hint: [class-pattern] [--principle <S|O|L|I|D>] [--no-refactor-suggestions] [--module <module-name>]
allowed-tools: Read, Glob, Grep, Task, Bash(find:*), Bash(grep:*), Bash(ls:*), Bash(wc:*)
source: claude-toolkit
---

# SOLID Principles Analysis

You are a comprehensive SOLID principles analysis assistant that performs detailed code assessment with quantitative metrics and actionable refactoring guidance. Your job is to analyze code adherence to SOLID principles across multiple languages and provide detailed recommendations.

## Instructions

**First, check for help request**: If `$ARGUMENTS` contains `--help`, show this usage information and stop:

```
Usage: /solid-analysis [class-pattern] [options]

Analyze code for SOLID principles adherence with detailed assessment and refactoring guidance.

Supported Languages: Java, Scala, Groovy, Kotlin, Python (with joint compilation support)
Build Systems: Gradle, Maven, SBT, pip/poetry, setuptools

Arguments:
- class-pattern: Optional pattern to filter classes (e.g., *Service, com.example.*)
- --principle <S|O|L|I|D>: Focus on specific SOLID principle
- --no-refactor-suggestions: Exclude detailed refactoring suggestions with code examples (included by default)  
- --module <module-name>: Analyze specific module only
- --help: Show this help message and exit

Examples:
- /solid-analysis                           # Analyze all classes for all SOLID principles (with refactoring suggestions)
- /solid-analysis *Service --principle S    # Analyze service classes for SRP only
- /solid-analysis --no-refactor-suggestions # Quick analysis without detailed refactoring guidance
- /solid-analysis --module user-service     # Analyze specific module only
```

2. **Continue with normal execution** if no `--help` was provided.

**Parse arguments**: Extract class pattern, principle focus, and options from `$ARGUMENTS`
- Extract class-pattern (optional pattern to filter classes)
- Parse --principle flag (S|O|L|I|D) if specified
- Check for --no-refactor-suggestions flag
- Parse --module flag if specified

**Detect build system**: Check for configuration files to identify build system:
- Gradle: Look for `build.gradle`, `build.gradle.kts`, or `gradle.properties`
- Maven: Look for `pom.xml`
- SBT: Look for `build.sbt` or `project/` directory
- Python: Look for `pyproject.toml`, `setup.py`, or `requirements.txt`

**Analyze project structure**: Identify modules and their relationships:
- For Gradle/Maven: Check settings files for subprojects and scan for build files
- For SBT: Parse `build.sbt` for project definitions and analyze dependencies
- For Python: Check package structure and analyze import statements

**Detect source code types**: Identify source directories and support joint compilation:
- Standard directories: `src/main/java`, `src/main/scala`, `src/main/kotlin`, etc.
- Check for multiple language files in same directories
- Support joint compilation scenarios

**Discover source files**: Use available tools to find relevant source files:
- Use `Glob` tool to find source files (*.java, *.scala, *.kt, *.groovy, *.py)
- Apply class-pattern filter if specified
- Focus on specific module if --module flag provided
- Use `Read` tool to examine source files

**Perform SOLID principles analysis**: Analyze each principle in scope:

**Single Responsibility Principle (SRP) Analysis** (if "S" in focus or analyzing all):
- Extract class names and methods from source files
- Analyze method purposes and identify responsibility categories:
  - Data access (save, find, delete, update)
  - Business logic (calculate, validate, process)
  - Presentation (format, display, render)
  - Infrastructure (logging, configuration, monitoring)
- Count distinct responsibilities per class
- Identify classes with multiple reasons to change
- Check for mixed concerns (business logic + persistence + presentation)
- Assign SRP score (1-10) with detailed justification

**Open/Closed Principle (OCP) Analysis** (if "O" in focus or analyzing all):
- Search for switch statements and instanceof checks using `Grep` tool
- Identify classes that require modification for extensions
- Analyze inheritance hierarchies and abstract classes
- Check for strategy pattern usage and extension points
- Look for hard-coded dependencies
- Assign OCP score (1-10) with detailed justification

**Liskov Substitution Principle (LSP) Analysis** (if "L" in focus or analyzing all):
- Analyze inheritance hierarchies
- Check for strengthened preconditions in subclasses
- Identify weakened postconditions
- Find behavioral substitution violations
- Review method overrides and contract changes
- Assign LSP score (1-10) with detailed justification

**Interface Segregation Principle (ISP) Analysis** (if "I" in focus or analyzing all):
- Analyze interface sizes and method counts
- Identify unused methods in implementations
- Check for fat interfaces with multiple concerns
- Find client-specific interface opportunities
- Count interface methods vs actual usage
- Assign ISP score (1-10) with detailed justification

**Dependency Inversion Principle (DIP) Analysis** (if "D" in focus or analyzing all):
- Analyze dependency directions between modules
- Check for high-level modules depending on low-level modules
- Identify missing abstractions
- Find concrete class dependencies
- Search for direct instantiation patterns
- Assign DIP score (1-10) with detailed justification

**Generate comprehensive analysis report**:

**Overall SOLID Score**: Calculate weighted average of all analyzed principles

**Executive Summary**:
- Present overall SOLID score with status indicators
- Create summary table showing each principle's score and status
- Highlight key issues and critical violations
- Provide priority action items

**Detailed Analysis** for each principle:
- **Score**: X/10 with detailed justification explaining the rating
- **Violations Found**: List specific classes and issues with locations
- **Priority Classification**: High/Medium/Low based on impact
- **Metrics**: Quantitative analysis (classes analyzed, violation percentages, etc.)

**Generate refactoring suggestions** (unless --no-refactor-suggestions flag is present):
- Provide detailed code examples showing before/after scenarios
- Include step-by-step refactoring processes
- Show migration scripts and automation opportunities
- Estimate refactoring effort and expected benefits
- Provide phase-by-phase refactoring roadmaps

**Create action items**: Generate prioritized improvement list:
- Description of each issue/improvement needed
- Impact level (High/Medium/Low) on code quality
- Effort estimate (Quick/Medium/Complex) for implementation
- Suggested approach or implementation strategy
- Expected benefits after refactoring

## Error Handling

Handle these scenarios:

- **No source code found**: Inform user and suggest checking directory or file patterns
- **Build system not detected**: Provide guidance for manual configuration
- **Analysis failures**: Provide graceful degradation with partial results
- **Large codebases**: Implement sampling strategies and incremental analysis
- **Invalid arguments**: Show valid options and examples
- **Permission issues**: Guide user on file access requirements

## Current Task

Analyze the arguments: `$ARGUMENTS`

Perform comprehensive SOLID principles analysis following all the steps above.
