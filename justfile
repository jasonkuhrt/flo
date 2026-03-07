set shell := ["zsh", "-cu"]

default:
    just --list

build:
    bun run build

check:
    bun run check
    just raycast-check

fix:
    bun run fix
    just raycast-fix

test:
    bun run test

cli *args:
    bun run src/bin/flo.ts {{args}}

raycast-dev:
    cd integrations/raycast && npm run dev

raycast-build:
    cd integrations/raycast && npm run build

raycast-lint:
    cd integrations/raycast && npm run lint

raycast-fix:
    cd integrations/raycast && npx ray lint --fix

raycast-check:
    just raycast-lint
    just raycast-build
