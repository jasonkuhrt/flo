# Spec

# Design Goals

## Aesthetics

- No emojis in output

## Succinct Spec Driven

- Description:
  - This document is a source of truth for Flo behavior.
  - This document should be concise, clear, and easy to read.
  - This document is hand written and thus ease of writing/updating must be prioritized.

## Contextual Over Explicit

- Description:
  - We want contextual commands instead of many explicit commands.
- Motivation:
  - This alllows users to recall a small set of commands that just do the right thing optimized relative to their workspace context which either way is going to be there so why not leverage it.

## Prompt Flag Pattern

- Description:
  - Many commands will necessarially prompt user in response to context.
  - Each such prompt should have a coreesponding optional flag on the command to preload the answer and thus skip the prompt.
  - Each prompt should have an indicator about what the flag name for it is displayed somehow in dim subtle text.
  - In some command cases, an argument will also serve as an alias for the flag e.g. imagine `flo foo bar 1` is equivalent to `flo foo bar --thing 1`.
- Motivation:
  - The presence of flags at all allow for a faster execution (if user really knows what they want then prompts go from helpful to annoying)
  - The presence of flags allows scripting where there is no interactive opportunity.
  - Perfect consistent symmetry means easier for users to learn and use... 'learn once use everywhere' vibe

# Definitions

## Project

- A Git repository
- Has a name which is the parent directory name that contains the `.git` directory
- On local disk under root directory $PROJECTS_DIR/<namespace>/*
- <namespace> typically matches a GitHub organization or user which helps keeps projects on disk organized.

## Flow

- Its name is its Git Branch name
- Has 1 Git Worktree
- Has 1 Git Branch
- May have exactly 1 GitHub Issue
- May have exactly 1 GitHub Pull Request

## Slugified

- Converts text to a URL-safe format by:
  - Converting to lowercase
  - Replacing spaces and special characters with hyphens
  - Removing consecutive hyphens
  - Trimming hyphens from start/end

# Variable Defaults

- $FLO_PROJECTS_DIR - `~/projects`
- $FLO_WORKTREES_DIR - `~/worktrees/<project name>`
- $FLO_PROJECT_TEMP_DIR - `.flo`

# Global Points

- .flo project directory should be created on demand

# Commands

- allow commands run preflight checks:
  - '$FLO_PROJECT_TEMP_DIR' should be git ignored

## flo

### Flags

- `--project <name>` | Skip project selection, use specified project
- `--issue <number>` | Skip issue selection, use specified issue
- `--no-issue` | Skip issue selection, create no-issue flow
- `--close-current` | When in flow, close current and create new
- `--keep-current` | When in flow, keep current and create new flow
- `--zed, -z` | Open in Zed editor after creation
- `--claude, -c` | Launch Claude after creation

### Arguments

- `flo <issue-number>` | Equivalent to `flo --issue <issue-number>`
- `flo <project-name>` | Equivalent to `flo --project <project-name>` (when outside project)

### Examples

**Interactive usage (with prompts):**

```bash
flo                    # Prompts for context-appropriate actions
flo --zed              # Same as above, but opens in Zed
flo --claude           # Same as above, but launches Claude
```

**Non-interactive usage (skip prompts with flags):**

```bash
flo --issue 123                    # Create flow for issue #123
flo --issue 123 --zed --claude     # Create flow, open Zed, launch Claude
flo --no-issue                     # Create no-issue flow
flo --project myproject --issue 45 # Work on issue #45 in myproject
flo --close-current --issue 123    # Close current flow, create new for #123
```

**Argument shortcuts:**

```bash
flo 123                # Same as: flo --issue 123
flo myproject          # Same as: flo --project myproject (when outside project)
```

### Steps

- if CWD is a flow
  - consider project to be the one the flow is associated with
  - ask which thing the user wants:
    - close current flow and create a new one
      - run flo end to cleanup current flow
      - then proceed with flow creation as below
    - create a new flow (keeping current one)
      - proceed with flow creation as below
- if CWD is within a Project
  - Git sync with the remote
  - if project has issues
    - prompt to select exactly one issue or no issue
    - if issue selected branch name uses pattern
    - if no issue, prompt to enter text to use as branch name suffix (see pattern)
    - create a new git worktree in $FLO_WORKTREES_DIR, and branch
      - worktree and branch use same name
      - name using pattern
    - cd into the new worktree directory
    - if there is an issue
      - download the issue including comments and metadata as JSON to .flo/issue.json (schema being what GH CLI produces)
      - create/append to .flo/claude.local.md:
        ```markdown
        # Issue Context

        Working on issue #{issue_number}: {issue_title}

        See `.flo/issue.json` for full issue details including comments and metadata.
        ```
  - if project has no issues then carry out the flow but skipping issue selection prompt
  - if zed flag given then open zed to this current directory
  - if claude flag given then begin claude with context using pattern
- if CWD is not within a Project
  - prompt to select a project
  - continue with the flow as if CWD was within that Project

## flo end

End flows with contextual cleanup. Replaces the need for separate rm/close commands.

### Flags

- `--close-issue` | Close the GitHub issue
- `--close-pr` | Close the pull request
- `--keep-worktree` | Don't delete the worktree
- `--no-sync` | Skip git sync after cleanup
- `--force, -f` | Skip confirmation prompts

### Examples

**Interactive usage (with prompts):**

```bash
flo end                # Prompts for cleanup actions in current context
flo end 123            # Prompts for cleanup actions for issue #123
```

**Non-interactive usage (skip prompts with flags):**

```bash
flo end --force                          # Use defaults, no prompts
flo end --close-issue --close-pr         # Close issue and PR, delete worktree
flo end --keep-worktree --close-issue    # Close issue but keep worktree
flo end 123 --close-issue --force        # Close issue #123 with no prompts
flo end --no-sync                        # Skip git sync after cleanup
```

### Steps

**Context: In a Flow (worktree)**

- Auto-detect current flow context
- Show available cleanup actions with smart defaults:
  - ✓ Delete current worktree (default)
  - ✓ Git sync main branch (default)
  - ○ Close GitHub issue (optional)
  - ○ Close pull request (optional)
- Execute selected actions
- Return to main project directory

**Context: Not in Flow**

- Show interactive list of all flows available for ending
- Allow selection of flow to end
- Proceed with cleanup as above

**Context: With issue argument**

- `flo end 123` - End specific issue flow
- Show cleanup options for that specific flow

### Exceptions

- If not in git project, show error [not_git_project]
- If no flows available to end, show message and exit gracefully
- If worktree deletion fails, show error and exit [worktree_delete_failed]
- If git sync fails, show warning but continue [git_sync_failed]
- If GitHub operations fail, show warning but continue [gh_operation_failed]

## flo list

- if CWD is within a Project
  - Show list of flows for the current project using pattern
- if CWD is not within a Project
  - Show list of projects using pattern
  - a column of project name is added to table, sorted by project

# Patterns

## Prompt Flag Indicators

All interactive prompts should display the corresponding flag name in dim text to help users learn the non-interactive alternatives.

**Format:** `<prompt text> (use --flag-name to skip)`

**Examples:**

- "Select project: (use --project to skip)"
- "Select issue: (use --issue or --no-issue to skip)"
- "Close current flow? (use --close-current or --keep-current to skip)"

## Launch Claude With Context

- if no issue then launch claude normally
- if issue then launch claude with context prompt:
  ```
  You are working on GitHub issue #{issue_number}: {issue_title}

  Issue details are available in .flo/issue.json

  Please read the issue file to understand the requirements before proceeding.
  ```

## Branch / Worktree Name

- all variables are slugified
- if there is an issue: `issue/<issue-number>`
- if there is no issue: `no-issue/<suffix>`

## Project Display in Terminal

- Extends Flow display
- If multiple projects
  - adds column for project name
  - sorted by project name

## Flow Display in Terminal

- A row of columns with aligned spacing
- Columns are: name, issue number, pull request number
- Headers: "Name", "Issue", "PR"
- Empty values displayed as "-"
- Column alignment: left-aligned text, right-aligned numbers

# Exceptions

## No GitHub Remote [no_gh_remote]

- If project has no GitHub remote, skip issue-related features
- Show warning: "No GitHub remote found, continuing without issue integration"

## Issue Download Failure [issue_download_failed]

- If issue download fails, continue with worktree creation
- Show warning: "Failed to download issue details, continuing without context"

## .flo Directory Creation [flo_dir_create_failed]

- If .flo directory cannot be created, show error and exit
- Suggest checking permissions

## Git Ignore Check [flo_not_gitignored]

- Check if .flo/ is in .gitignore
- If not found, prompt to add it automatically
- Show diff of what would be added

## Not in Git Project [not_git_project]

- If CWD is not within a Git project, show error and exit
- Message: "Must be run from within a git project"

## GitHub Authentication Failed [gh_auth_failed]

- If GitHub CLI authentication is not set up or expired
- Show error with instructions to run `gh auth login`

## Project Selection Cancelled [project_selection_cancelled]

- If user cancels project selection prompt
- Exit gracefully without error

## Issue Selection Cancelled [issue_selection_cancelled]

- If user cancels issue selection prompt
- Exit gracefully without error

## Worktree Creation Failed [worktree_create_failed]

- If git worktree creation fails (e.g., branch already exists)
- Show error and suggest alternative branch name

## Branch Already Exists [branch_exists]

- If attempting to create a branch that already exists
- Show error and suggest using existing worktree or different name
