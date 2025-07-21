# Spec

# Design Goals

## Aesthetics

- No emojis in output

## Prefer Requirements Gathering

- When possible have commands gather requirements up front from the user so that there is less chance of partial failure/success states.
- For example attempt to gather the issue data before running system side effects so that if issue request fails the user doesn't have to deal with some partial state.

## Succinct Spec Driven

- Description:
  - This document is a source of truth for Flo behavior.
  - This document should be concise, clear, and easy to read.
  - This document is hand written and thus ease of writing/updating must be prioritized.

## Contextual Over Explicit

- Description:
  - We want contextual commands instead of many explicit commands.
  - When exceptions happen we want to prompt with logical next options if possible, instead of exiting.
- Motivation:
  - This allows users to recall a small set of commands that just do the right thing optimized relative to their workspace context which either way is going to be there so why not leverage it.

## Prompt Flag Pattern

- Description:
  - Many commands will necessarily prompt user in response to context.
  - Each such prompt should have a corresponding optional flag on the command to preload the answer and thus skip the prompt.
  - Each prompt should have an indicator about what the flag name for it is displayed somehow in dim subtle text.
  - In some command cases, an argument will also serve as an alias for the flag e.g. imagine `flo foo bar 1` is equivalent to `flo foo bar --thing 1`.
- Motivation:
  - The presence of flags at all allow for a faster execution (if user really knows what they want then prompts go from helpful to annoying)
  - The presence of flags allows scripting where there is no interactive opportunity.
  - Perfect consistent symmetry means easier for users to learn and use... 'learn once use everywhere' vibe

# Reading This Spec

- This spec uses compact notation for readability and maintainability. See below.

## Context Symbols

| Symbol | Means in Context | Example                     |
| ------ | ---------------- | --------------------------- |
| `@g`   | Global Context   | `@g` -> select project      |
| `@p`   | Project Context  | `@p` -> sync -> create      |
| `@f`   | Flow Context     | `@f` -> prompt(close\|keep) |

## Abbreviations

| Symbol | Meaning      | Example      |
| ------ | ------------ | ------------ |
| `wt`   | Worktree     | create `wt`  |
| `br`   | Branch       | create `br`  |
| `pr`   | Pull request | close `pr`   |
| `iss`  | Issue        | select `iss` |

# Definitions

## Project

- A Git repository
- Has a name which is the parent directory name that contains the `.git` directory
- On local disk under root directory `$PROJECTS_DIR/<namespace>/*`
- `<namespace>` typically matches a GitHub organization or user which helps keep projects on disk organized.

## Flow

- Its name is its Git Branch name
- Always a branch directly off of trunk
- Has 1 Git Worktree
- Has 1 Git Branch
- Always branches from main (flows never branch from other flows)
- May have exactly 1 GitHub Issue
- May have exactly 1 GitHub Pull Request

## Slug

- a name that conforms to the following rules:
  - Converting to lowercase
  - Replacing spaces and special characters with hyphens
  - Removing consecutive hyphens
  - Trimming hyphens from start/end

## Step

A unit of command execution. Each step is either a Prompt or an Action.

### Prompt

- An interactive step that collects user input
- Uses gum toolkit (bound by its capabilities)
- Design goals:
  - Display validation rules in dim text when applicable
  - Show preview for transformed inputs (e.g., slugified branch names)
- Specific prompt text and validation rules are defined per command/pattern
- **Ctrl+C behavior**: Always immediately terminates the process

### Action

- An execution step that produces side effects
- Progresses toward the command's goal
- Displays the action name during execution
- Shows success/failure confirmation after completion

### Contextual Command

- A command that supports one or more contexts

### Context Target

- An expression to target @f @p
- There is no expression to target @g
- Relative Flow target
  - Valid within @p @f
  - `<flow_issue_number>`
    - target a Flow that is associated with this issue number
    - if the issue number exists but has no assoicated flow then it is not valid
  - `<flow_name>`
    - target a Flow by its name
- Absolute Flow target
  - Valid in any context
  - `<project_name>@<flow_target>`

# Variable Defaults

| Variable              | Default Value              |
| --------------------- | -------------------------- |
| $FLO_PROJECTS_DIR     | ~/projects                 |
| $FLO_WORKTREES_DIR    | ~/worktrees/<project name> |
| $FLO_PROJECT_TEMP_DIR | .flo                       |

# Global Points

## Preflight

- All commands when performing their first action within a @p/f should:
  - Ensure `$FLO_PROJECT_TEMP_DIR` is git ignored
  - Create `$FLO_PROJECT_TEMP_DIR` on demand

## Flags

| Flag               | Short | Description                                             |
| ------------------ | ----- | ------------------------------------------------------- |
| `--no-interactive` |       | Disable all prompts; require all answers via flags/args |

# Commands

## flo start

### Description

Continue a Flow, creating it if necessary.

### Flags

| Flag         | Short | Description          | Default |
| ------------ | ----- | -------------------- | ------- |
| `--no-issue` |       | Create no-issue flow |         |
| `--zed`      | -z    | Open in Zed after    | false   |
| `--claude`   | -c    | Launch Claude after  | false   |

### @f

- steps:
  - open zed IF --zed
  - start claude IF --claude

### @p

- steps:
  - select @f
  - go to @f

### @g

- steps:
  - select @p/f
  - go to @p/f

## flo end

### Description

End a Flow.

### @f

- steps:
  - delete wt, br
  - git sync trunk
  - close iss IF has one, is open, gave flag
  - close pr IF has one, is open, gave flag
  - cd @p

### @p

- steps:
  - list flows -> select flow
  - go to @f

### Flags

| Flag            | Short | Description            | Default |
| --------------- | ----- | ---------------------- | ------- |
| `--close-issue` |       | Close the GitHub issue | false   |
| `--close-pr`    |       | Close the pull request | false   |

## flo list

### Description

- List all flows in the current context.

### @p

- display flows

### @g

- for each project
  - display flows

# Context

- Commands always run in a context
- Commands by default infer their context by considering their current working directory
- The contexts a command support are identified by its `### @<context>` sections in this spec
- A command's behaviour may change based on the context it is run in
- There are flags that allow users to explicitly set the context for a command, overriding the default inference
- There are three contexts: Flow, Project, Global
- Contexts form a hierarchy:
  - Flow context is a subset of Project context
  - Project context is a subset of Global context
  - Global context is the most general context
- All commands support standard flags corresponding to contexts, each for overriding context inference to their respective context type
  - Internally, context must still always be inferred even when these flags are given in order to resolve the flags correctly, see next.
  - the flags are:
    - `--flow|-f <flow_target>`
    - `--project|-p [<project name>]`
      - Act as if CWD is the given project
      - `<project name>` is optional IF the inferred context is a Project or Flow, in which case the inferred project is used by default
        - This would be useful to run flo against the overal project while in a Flow
      - `<project name>` is required IF the inferred context is global
    - `--global|-g`
      - Act as if CWD is not in any project
  - the flags are mutually exclusive
  - if a command does not support a context then it will not have the corresponding flag
- In addition to flags, and mutually exclusive to them in terms of use, all commands support standard optional arguments corresponding to contexts they support, except @g
  - If the inferred context is ... then accepted argument pattern is ...
    - @g: <project_name> | <absolute_flow_target>
    - @p: <project_name> | <absolute_flow_target> | <flow_issue_number>
    - @f: <project_name> | <absolute_flow_target> | <flow_issue_number>
- When a contextual command is run without flags or arguments if uses interactive prompts to narrow down the context to a flow if needed
  - If the context is inferred to @f then no prompt
  - If the context is inferred to @p prompts for @f
  - If the context is inferred to @g then prompt for @p and @f (technically could be two prompts but can also be one of absolute @f targets)

# Patterns

## Prompts

- Specific prompt text and validation are defined in each command/pattern context

## Prompt Flag Indicators

All interactive prompts should display the corresponding flag name in dim text to help users learn the non-interactive alternatives.
The presentation of this should use gum to its best abilities

## Launch Claude With Context

- if no issue then launch claude normally
- if issue then launch Claude with context prompt:
  ```
  You are working on GitHub issue #{issue_number}: {issue_title}

  Issue details are available in .flo/issue.json

  Please read the issue file to understand the requirements before proceeding.
  ```

## Branch / Worktree Name

- always a valid slug
- all variables are [Slug](#slug)
- if there is an issue: `issue/<issue-number>`
- if there is no issue: `no-issue/<suffix>`

## Project Display in Terminal

- Extends [Flow display](#flow-display-in-terminal)
- If multiple projects
  - adds column for project name
  - sorted by project name

## Flow Display in Terminal

- A row of columns with aligned spacing
- Columns are: name, issue number, pull request number
- Headers: "Name", "Issue", "PR"
- Empty values displayed as "-"
- Column alignment: left-aligned text, right-aligned numbers

## Project Selection

- **Discovery**: Iterate through `$FLO_PROJECTS_DIR/<namespace>/*` directories
- **Valid project**: Any directory under a namespace that contains a `.git` directory
- **UI**: Standard select prompt listing discovered projects
- **No projects found**:
  - Display the supported pattern and what was searched
  - Example message:
    ```
    No projects found.
    Searched: ~/projects/*/*/.git
    Expected structure: $FLO_PROJECTS_DIR/<namespace>/<project>/
    ```

## Issue Selection

- **Fetch**: Use `gh` CLI to fetch issues (assumes proper credentials for all GitHub operations)
- **Filter**: Only show open issues, ignore closed
- **Display**: Compact single-row format per issue
- **Fields**: `#<number> <title>` (title truncated to 80 chars) + labels
- **Sort**: By creation date (newest first)
- **Limit**: Show only issues from first page of `gh` API response
- **No pagination**: If more issues exist than API returns, only show the first batch

## Git Sync

- **Branch**: Always refers to trunk
- **Operations**: Push all local changes to remote and pull all remote changes. Use fast forward approach if possible. Include tags.
- **Merge conflicts**: Block the flow and require user intervention
- **Purpose**: Ensure main is up-to-date before creating new flows

# Defects

Bugs in our code, such as malformed API requests causing 400 errors) are not exceptions. They should exit with code 1.

# Exceptions

## Current State

These are expected conditions based on the current environment or context.

| Code                          | Description                 | Action              | Message                                                        |
| ----------------------------- | --------------------------- | ------------------- | -------------------------------------------------------------- |
| `no_gh_remote`                | No GitHub remote found      | Skip issue features | "No GitHub remote found, continuing without issue integration" |
| `not_git_project`             | Not in git project          | Exit                | "Must be run from within a git project"                        |
| `branch_exists`               | Branch already exists       | Prompt alternatives | "Branch already exists, use existing or choose new name"       |
| `project_selection_cancelled` | User cancels project select | Exit gracefully     | -                                                              |
| `issue_selection_cancelled`   | User cancels issue select   | Exit gracefully     | -                                                              |
| `flo_not_gitignored`          | .flo not in gitignore       | Prompt to add       | "Add .flo/ to .gitignore?"                                     |
| `no_projects_found`           | No projects in projects dir | Exit                | "No projects found. See output for expected structure"         |

## External System Failures

These are failures outside our control from external systems or operations.

| Code                     | Description                 | Action           | Message                                                        |
| ------------------------ | --------------------------- | ---------------- | -------------------------------------------------------------- |
| `issue_download_failed`  | Issue download fails        | Continue without | "Failed to download issue details, continuing without context" |
| `gh_auth_failed`         | GitHub auth missing/expired | Exit             | "GitHub authentication required, run: gh auth login"           |
| `gh_operation_failed`    | GitHub operation fails      | Warn & continue  | "GitHub operation failed, continuing..."                       |
| `git_sync_failed`        | Git sync fails              | Warn & continue  | "Git sync failed, continuing..."                               |
| `worktree_create_failed` | Git worktree creation fails | Exit             | "Worktree creation failed, branch may already exist"           |
| `flo_dir_create_failed`  | Cannot create .flo dir      | Exit             | "Cannot create .flo directory, check permissions"              |
