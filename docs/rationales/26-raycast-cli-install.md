# What

Add a first-class `flo raycast` command family with:

- `flo raycast status`
- `flo raycast install`
- `flo raycast uninstall`

# Why

The Raycast adapter already existed, but it was still trapped behind maintainer-only repo workflows. That meant the user-facing install story was effectively "know the internals of `integrations/raycast` and drive Raycast's dev tooling yourself," which is the opposite of the Flo product boundary.

The right DX is that Flo owns the lifecycle of its own optional entrypoints.

# How

- Add a dedicated Raycast runtime module that:
  - locates the bundled adapter from the Flo package root
  - resolves Raycast's managed local extension directory
  - probes for Raycast.app and Bun
  - installs adapter dependencies deterministically
  - runs a one-shot `ray develop --non-interactive` bootstrap until Raycast reports a successful build
  - verifies the managed extension exists afterwards
  - removes the managed extension directory on uninstall
- Add an Effect-based `systemRunnerUntil` helper for watch-style commands that need to run until a ready signal appears and then terminate cleanly.
- Expose the Raycast lifecycle directly through the Flo CLI.

# Where

- `src/lib/process.ts`
- `src/lib/raycast.ts`
- `src/bin/flo.ts`
- `src/lib/raycast.test.ts`
- `src/lib/process.test.ts`

# When

Now, because the extension existing in the repo but not actually appearing in Raycast is a product failure, not a future enhancement.
