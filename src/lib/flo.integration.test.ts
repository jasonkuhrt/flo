import { mkdtemp, mkdir, realpath } from 'node:fs/promises'
import { basename, dirname, join } from 'node:path'
import { tmpdir } from 'node:os'

import { afterEach, describe, expect, it } from 'bun:test'

import {
  launchInteractive,
  listFloState,
  openWorkspace,
  resolveOpenTarget,
  resolveStartTarget,
  startWork,
} from '#lib/flo'
import type { CommandRunner } from '#lib/process'

const tempPaths: string[] = []

afterEach(async () => {
  await Promise.all(
    tempPaths.splice(0).map(async (path) => {
      await Bun.$`rm -rf ${path}`.quiet()
    }),
  )
})

const makeRepoFixture = async (): Promise<{
  env: NodeJS.ProcessEnv
  repoRoot: string
  featureWorktreePath: string
}> => {
  const path = await mkdtemp(join(tmpdir(), `flo-env-`))
  tempPaths.push(path)
  const repoRootPath = join(path, `flo`)
  await mkdir(repoRootPath, { recursive: true })
  const repoRoot = await realpath(repoRootPath)
  const featureWorktreePath = join(
    dirname(repoRoot),
    `.flo-checkouts`,
    basename(repoRoot),
    `feat`,
    `auth`,
  )

  return {
    repoRoot,
    featureWorktreePath,
    env: {
      FLO_CONFIG_PATH: join(path, `missing-config.json`),
      SHELL: `/bin/zsh`,
      EDITOR: `nvim`,
      HOME: path,
    },
  }
}

const mainWorktreeList = (repoRoot: string): string =>
  [`worktree ${repoRoot}`, `HEAD abc123`, `branch refs/heads/main`, ``].join(`\n`)

const mockRunner =
  (
    answers: Record<string, { stdout?: string; stderr?: string; exitCode?: number }>,
  ): CommandRunner =>
  async (command, args = []) => {
    const key = [command, ...args].join(` `)
    const answer = answers[key]

    if (answer === undefined) {
      throw new Error(`Unhandled command: ${key}`)
    }

    return {
      stdout: answer.stdout ?? ``,
      stderr: answer.stderr ?? ``,
      exitCode: answer.exitCode ?? 0,
    }
  }

const ok = (stdout = ``) => ({
  stdout,
  stderr: ``,
  exitCode: 0,
})

const fail = (stderr = `unhandled`) => ({
  stdout: ``,
  stderr,
  exitCode: 1,
})

describe(`flo runtime`, () => {
  it(`resolves the main checkout for the current project`, async () => {
    const fixture = await makeRepoFixture()
    const runner = mockRunner({
      [`git -C ${fixture.repoRoot} rev-parse --show-toplevel`]: { stdout: `${fixture.repoRoot}\n` },
      [`git -C ${fixture.repoRoot} remote get-url origin`]: {
        stdout: `git@github.com:jasonkuhrt/flo.git\n`,
      },
      [`git -C ${fixture.repoRoot} worktree list --porcelain`]: {
        stdout: mainWorktreeList(fixture.repoRoot),
      },
    })

    const result = await resolveOpenTarget({
      context: {
        cwd: fixture.repoRoot,
        env: fixture.env,
      },
      dependencies: { runner },
    })

    expect(result).toMatchObject({
      workspaceTitle: `flo:flo`,
      checkout: {
        path: fixture.repoRoot,
        isMain: true,
      },
    })
  })

  it(`opens an existing workspace by selecting it`, async () => {
    const fixture = await makeRepoFixture()
    const calls: string[] = []
    const runner: CommandRunner = async (command, args = []) => {
      const key = [command, ...args].join(` `)
      calls.push(key)

      if (
        key ===
        `git -C ${fixture.repoRoot} worktree add -b feat/auth ${fixture.featureWorktreePath}`
      ) {
        await mkdir(fixture.featureWorktreePath, { recursive: true })
      }

      return (
        {
          [`git -C ${fixture.repoRoot} rev-parse --show-toplevel`]: ok(`${fixture.repoRoot}\n`),
          [`git -C ${fixture.repoRoot} remote get-url origin`]: ok(
            `git@github.com:jasonkuhrt/flo.git\n`,
          ),
          [`git -C ${fixture.repoRoot} worktree list --porcelain`]: {
            ...ok(mainWorktreeList(fixture.repoRoot)),
          },
          [`cmux ping`]: ok(),
          [`cmux --json list-workspaces`]: {
            ...ok(JSON.stringify({ workspaces: [{ id: `workspace:3`, title: `flo:flo` }] })),
          },
          [`cmux select-workspace --workspace workspace:3`]: ok(),
        }[key] ?? fail()
      )
    }

    const result = await openWorkspace({
      context: {
        cwd: fixture.repoRoot,
        env: fixture.env,
      },
      dependencies: { runner },
    })

    expect(result.createdWorkspace).toBe(false)
    expect(result.workspaceId).toBe(`workspace:3`)
    expect(calls).toContain(`cmux select-workspace --workspace workspace:3`)
  })

  it(`starts GitHub issue work by planning a feature checkout`, async () => {
    const fixture = await makeRepoFixture()
    const runner = mockRunner({
      [`git -C ${fixture.repoRoot} rev-parse --show-toplevel`]: { stdout: `${fixture.repoRoot}\n` },
      [`git -C ${fixture.repoRoot} remote get-url origin`]: {
        stdout: `git@github.com:jasonkuhrt/flo.git\n`,
      },
      [`git -C ${fixture.repoRoot} worktree list --porcelain`]: {
        stdout: mainWorktreeList(fixture.repoRoot),
      },
      [`gh issue view 42 --repo jasonkuhrt/flo --json number,title,url,state`]: {
        stdout: JSON.stringify({
          number: 42,
          title: `Add launcher`,
          url: `https://github.com/jasonkuhrt/flo/issues/42`,
          state: `OPEN`,
        }),
      },
    })

    const result = await resolveStartTarget({
      context: {
        cwd: fixture.repoRoot,
        env: fixture.env,
      },
      selector: `42`,
      dependencies: { runner },
    })

    expect(result).toMatchObject({
      createdCheckout: true,
      checkout: {
        branch: `issue/42-add-launcher`,
      },
      issue: {
        number: 42,
      },
    })
  })

  it(`creates a new worktree and workspace for branch work`, async () => {
    const fixture = await makeRepoFixture()
    await mkdir(fixture.featureWorktreePath, { recursive: true })
    const calls: string[] = []
    const runner: CommandRunner = async (command, args = []) => {
      const key = [command, ...args].join(` `)
      calls.push(key)

      return (
        {
          [`git -C ${fixture.repoRoot} rev-parse --show-toplevel`]: ok(`${fixture.repoRoot}\n`),
          [`git -C ${fixture.repoRoot} remote get-url origin`]: ok(
            `git@github.com:jasonkuhrt/flo.git\n`,
          ),
          [`git -C ${fixture.repoRoot} worktree list --porcelain`]: {
            ...ok(mainWorktreeList(fixture.repoRoot)),
          },
          [`git -C ${fixture.repoRoot} show-ref --verify --quiet refs/heads/feat/auth`]: fail(),
          [`git -C ${fixture.repoRoot} worktree add -b feat/auth ${fixture.featureWorktreePath}`]:
            ok(),
          [`cmux ping`]: ok(),
          [`cmux --json list-workspaces`]: { ...ok(JSON.stringify({ workspaces: [] })) },
          [`cmux new-workspace`]: ok(),
          [`cmux --json current-workspace`]: {
            ...ok(JSON.stringify({ id: `workspace:4`, title: `untitled` })),
          },
          [`cmux rename-workspace --workspace workspace:4 flo:flo@feat/auth`]: ok(),
          [`cmux send --workspace workspace:4 exec 'zmx' attach 'flo-flo-feat-auth-editor' '/bin/zsh' -lc 'cd '\\''${fixture.featureWorktreePath}'\\'' && exec nvim'\n`]:
            ok(),
        }[key] ?? fail()
      )
    }

    const result = await startWork({
      context: {
        cwd: fixture.repoRoot,
        env: fixture.env,
      },
      selector: `feat/auth`,
      dependencies: { runner },
    })

    expect(result.createdCheckout).toBe(true)
    expect(result.createdWorkspace).toBe(true)
    expect(calls).toContain(
      `git -C ${fixture.repoRoot} worktree add -b feat/auth ${fixture.featureWorktreePath}`,
    )
  })

  it(`lists projects and marks matching workspaces as open`, async () => {
    const fixture = await makeRepoFixture()
    const runner = mockRunner({
      [`git -C ${fixture.repoRoot} rev-parse --show-toplevel`]: { stdout: `${fixture.repoRoot}\n` },
      [`git -C ${fixture.repoRoot} remote get-url origin`]: {
        stdout: `git@github.com:jasonkuhrt/flo.git\n`,
      },
      [`git -C ${fixture.repoRoot} worktree list --porcelain`]: {
        stdout: mainWorktreeList(fixture.repoRoot),
      },
      [`cmux ping`]: {},
      [`cmux --json list-workspaces`]: {
        stdout: JSON.stringify({ workspaces: [{ id: `workspace:3`, title: `flo:flo` }] }),
      },
    })

    const result = await listFloState({
      context: {
        cwd: fixture.repoRoot,
        env: fixture.env,
      },
      dependencies: { runner },
    })

    expect(result).toMatchObject({
      cmuxAvailable: true,
      projects: [
        {
          name: `flo`,
          checkouts: [
            {
              workspaceOpen: true,
            },
          ],
        },
      ],
    })
  })

  it(`launches through fzf and returns the selected open target`, async () => {
    const fixture = await makeRepoFixture()
    const runner = mockRunner({
      [`git -C ${fixture.repoRoot} rev-parse --show-toplevel`]: { stdout: `${fixture.repoRoot}\n` },
      [`git -C ${fixture.repoRoot} remote get-url origin`]: {
        stdout: `git@github.com:jasonkuhrt/flo.git\n`,
      },
      [`git -C ${fixture.repoRoot} worktree list --porcelain`]: {
        stdout: mainWorktreeList(fixture.repoRoot),
      },
      [`cmux ping`]: { exitCode: 1 },
      [`fzf --delimiter \t --with-nth 2.. --prompt flo > `]: {
        stdout: `flo\tflo  [main]\t${fixture.repoRoot}\n`,
      },
    })

    const result = await launchInteractive({
      context: {
        cwd: fixture.repoRoot,
        env: fixture.env,
      },
      dependencies: { runner },
    })

    expect(result).toMatchObject({
      workspaceTitle: `flo:flo`,
    })
  })
})
