## What

Allow individual projects to override the global `main` and `feature` workspace profiles.

## Why

Global defaults are helpful, but high-leverage tooling usually needs one more level of intent: some repos want a different main landing view, a different feature-pane layout, or a different Claude command than the rest of the machine. Project-scoped overrides keep that customization local to the repo it belongs to.

## How

Project config now accepts `workspaceProfiles.main` and `workspaceProfiles.feature`. Flo merges project profile values on top of the global runtime profile for the matching workspace kind when planning the launch target.

## When

These overrides apply whenever Flo opens or recreates a workspace for that project. They do not affect other repos and they do not override `zmx` restore once a session is already alive.

## Where

The overrides live on the project config object and flow through project discovery into target planning, which keeps profile precedence explicit: runtime defaults first, project intent second.
