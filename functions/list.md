---
{
  "description": "List all git worktrees with branches and paths",
  "parametersNamed": [
    {
      "name": "--project",
      "description": "Project to list worktrees for (name or path). Names resolved via ~/.config/flo/settings.json"
    }
  ],
  "examples": [
    {
      "command": "flo list",
      "description": "Show all worktrees for current project"
    },
    {
      "command": "flo list --project backend",
      "description": "List worktrees for different project (by name)"
    },
    {
      "command": "flo list --project ~/projects/api",
      "description": "List worktrees for project by path"
    }
  ],
  "related": ["end", "prune"],
  "exitCodes": {
    "0": "Success"
  }
}
---

Shows all worktrees with their paths, branches, and commits.
