---
{
  "description": "End your work by removing a worktree and optionally managing the PR",
  "aliases": ["rm"],
  "parametersPositional": [
    {
      "name": "branch-name-or-issue",
      "description": "Branch name, issue number, or worktree directory name to remove (optional - defaults to current worktree)",
      "required": false
    }
  ],
  "parametersNamed": [
    {
      "name": "--resolve",
      "description": "Resolution mode: 'success' (merge PR, default) or 'abort' (close PR without merging)"
    },
    {
      "name": "--force",
      "short": "-f",
      "description": "Skip all validations (PR checks, clean worktree, synced branch)"
    },
    {
      "name": "--ignore",
      "description": "Ignore specific operations: 'pr' (skip PR operations) or 'worktree' (skip worktree/branch cleanup)"
    },
    {
      "name": "--yes",
      "short": "-y",
      "description": "Skip confirmation prompt (non-interactive mode)"
    },
    {
      "name": "--project",
      "description": "Project to operate on (name or path). Names resolved via ~/.config/flo/settings.json"
    }
  ],
  "examples": [
    {
      "command": "flo end",
      "description": "Interactive cleanup: merge PR (if checks pass), delete worktree/branch, sync main"
    },
    {
      "command": "flo end --resolve success",
      "description": "Explicit success resolution (default behavior)"
    },
    {
      "command": "flo end --resolve abort",
      "description": "Abandon work: close PR without merging, delete worktree/branch"
    },
    {
      "command": "flo end 1320",
      "description": "End work on issue #1320"
    },
    {
      "command": "flo end feat/123-add-auth",
      "description": "End work by branch name"
    },
    {
      "command": "flo end --force",
      "description": "Skip validations (dirty worktree, failing PR checks, unpushed commits)"
    },
    {
      "command": "flo end --ignore pr",
      "description": "Clean up locally without touching the PR"
    },
    {
      "command": "flo end --ignore worktree",
      "description": "Merge/close PR but keep local worktree and branch"
    },
    {
      "command": "flo end --resolve abort --ignore pr",
      "description": "Delete worktree/branch locally but don't close the PR"
    },
    {
      "command": "flo end --yes",
      "description": "Non-interactive mode (for automation)"
    },
    {
      "command": "flo end --force --yes",
      "description": "Force cleanup without confirmation"
    },
    {
      "command": "flo end --project backend",
      "description": "End work in a different project"
    }
  ],
  "related": ["list", "prune"],
  "exitCodes": {
    "0": "Success",
    "1": "Error - worktree not found or removal failed"
  }
}
---

# ABOUT

Safely ends your work on a branch by managing the full cleanup lifecycle: PR resolution, worktree removal, branch deletion, and main branch synchronization.

The command follows a task-based model where operations can be selectively included or excluded via flags.

## Core Concept: Task-Based Cleanup

`flo end` executes a series of tasks to cleanly finish your work. The exact tasks depend on the resolution mode and can be modified with flags.

### Success Path (`--resolve success`, default)

**Tasks executed:**
1. **Validate**: PR checks passing (if PR exists)
2. **Validate**: Worktree clean (no uncommitted changes)
3. **Validate**: Branch synced (no unpushed commits)
4. **Merge PR** (deletes remote branch via `gh pr merge --squash --delete-branch`)
5. **Delete worktree**
6. **Delete local branch**
7. **Sync main branch** (`git pull origin main` in main repo)
8. **Navigate to main repo**

**Modifiers:**
- `--force`: Skip tasks 1-3 (all validations)
- `--ignore pr`: Skip tasks 1, 4, 7
- `--ignore worktree`: Skip tasks 2-3, 5-6
- If no PR exists: Skip tasks 1, 4, 7 automatically
- If PR already merged: Skip tasks 4, 7 automatically (idempotent)

### Abort Path (`--resolve abort`)

**Tasks executed:**
1. **Close PR** without merging (via `gh pr close`)
2. **Delete worktree**
3. **Delete local branch**
4. **Navigate to main repo**

**Modifiers:**
- `--ignore pr`: Skip task 1
- `--ignore worktree`: Skip tasks 2-3
- No validations (you're abandoning work, dirty state is acceptable)

## Validations (Success Path Only)

The following validations prevent accidental data loss and ensure clean merges. All can be bypassed with `--force`:

1. **PR checks passing**: If a PR exists for the branch, all GitHub status checks must be in SUCCESS state
2. **Worktree clean**: `git status --porcelain` must return empty (no uncommitted changes)
3. **Branch synced**: No unpushed commits (checked via `git rev-list @{u}..HEAD`)

## Edge Cases

- **No PR exists**: PR-related tasks are skipped gracefully (no error)
- **PR already merged**: Merge task skipped gracefully (idempotent operation)
- **PR already closed**: Close task skipped gracefully (idempotent operation)
- **`--ignore pr --ignore worktree`**: Does nothing, exits successfully (all tasks subtracted)
- **Remote vs local**: `--ignore worktree` only affects LOCAL state (worktree + local branch). Remote branch is still deleted via PR merge/close.
