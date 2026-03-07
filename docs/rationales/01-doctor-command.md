## What

Add a first-class `flo doctor` command that reports config resolution, current project and checkout context, `cmux` availability, and whether the required runtime commands are actually reachable.

## Why

Flo depends on several external tools and a cwd-sensitive project model. When any one of those assumptions is wrong, the failure mode is usually confusing. A single diagnostic command lowers the cost of understanding "why didn't Flo open what I expected?" without making the user inspect config files or guess at binary resolution.

## How

The core now exposes a non-throwing project lookup for the current cwd and a typed `doctorFlo` result. `flo doctor` uses the configured shell to probe command availability, reports the resolved config path, and shows whether the current cwd maps to a known project and checkout.

## When

Run this before debugging launcher failures, after moving a repo, after changing config, or from a global launcher path where cwd context may be ambiguous.

## Where

The command is exposed through the main CLI and documented in the README. The logic lives in the Flo core so other entrypoints can reuse it later, including Raycast or editor integrations.
