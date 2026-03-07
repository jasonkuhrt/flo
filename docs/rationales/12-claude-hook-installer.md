## What

Add `flo claude install-hooks`, a command that installs Flo's Claude hook bridge into `.claude/settings.local.json` for the current checkout.

## Why

The hook bridge is only useful if installation is low-friction. Manually editing the right per-worktree settings file is error-prone, especially because the correct home for this integration is local checkout settings rather than a globally shared Claude config.

## How

Flo resolves the current checkout, reads any existing `settings.local.json`, preserves unrelated settings, and writes deterministic Flo hook entries for `Notification`, `SessionStart`, `PreCompact`, `SubagentStart`, and `SubagentStop`.

## When

Use this when enabling Flo in a new checkout or when reapplying the canonical hook bridge after experimenting with local Claude settings.

## Where

The installer writes into the checkout-local Claude settings file, which keeps the integration scoped to the worktree that actually owns the Flo workspace and avoids polluting user-global Claude behavior.
