# What

Remove the root `justfile` and make Bun scripts the canonical repo workflow surface for Flo, including Raycast-specific build, lint, fix, check, install, uninstall, and status commands.

# Why

The repo already uses Bun as its main runtime and task runner. Keeping a root `justfile` on top of that added one more indirection layer and made the Raycast workflow harder to discover. If the product wants `flo raycast ...` to be the user contract and `bun run ...` to be the repo contract, then `just` is redundant noise.

# How

- Delete the root `justfile`.
- Move Raycast workflows onto root `package.json` scripts:
  - `bun run dev:raycast`
  - `bun run build:raycast`
  - `bun run lint:raycast`
  - `bun run fix:raycast`
  - `bun run check:raycast`
  - `bun run raycast:status`
  - `bun run raycast:install`
  - `bun run raycast:uninstall`
- Fold Raycast checks into the canonical root `check` and `fix` scripts.
- Convert the Raycast adapter package to Bun-native scripts and lockfile management.

# Where

- `package.json`
- `integrations/raycast/package.json`
- `integrations/raycast/bun.lock`
- `README.md`

# When

Now, because the repo surface should match the intended product surface immediately. As long as `just` remained, the documentation and ergonomics would keep pointing at a maintainer workaround instead of the real contract.
