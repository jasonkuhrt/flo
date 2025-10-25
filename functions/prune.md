---
{
  "description": "Clean up Git metadata for manually deleted worktrees",
  "parametersNamed": [
    {
      "name": "--project",
      "description": "Project to prune worktrees for (name or path). Names resolved via ~/.config/flo/settings.json"
    }
  ],
  "examples": [
    {
      "command": "flo prune",
      "description": "Clean up metadata for current project"
    },
    {
      "command": "flo prune --project backend",
      "description": "Prune worktrees for different project (by name)"
    }
  ],
  "related": ["list", "end"],
  "exitCodes": {
    "0": "Success"
  }
}
---

# About

Use this if you deleted with `rm -rf` instead of `flo rm`.
