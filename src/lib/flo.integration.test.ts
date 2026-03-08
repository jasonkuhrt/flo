import { mkdtemp, mkdir, realpath, writeFile } from 'node:fs/promises'
import { basename, dirname, join } from 'node:path'
import { tmpdir } from 'node:os'

import { afterEach, describe, expect, it } from 'bun:test'

import { installClaudeHooks } from '#lib/claude'
import {
  doctorFlo,
  endWork,
  explainEnd,
  explainOpen,
  explainStart,
  getFloContext,
  initConfig,
  launchInteractive,
  listFloState,
  listRecentWork,
  openLastWorkspace,
  openWorkspace,
  previewInitOpen,
  previewInitStart,
  pruneFloState,
  resolveOpenTarget,
  resolveStartTarget,
  statusFlo,
  startWork,
} from '#lib/flo'
import type { CommandRunner } from '#lib/process'
import { getDefaultStatePath, loadState, saveState } from '#lib/state'

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

const featureWorktreeList = (repoRoot: string, featureWorktreePath: string): string =>
  [
    `worktree ${repoRoot}`,
    `HEAD abc123`,
    `branch refs/heads/main`,
    ``,
    `worktree ${featureWorktreePath}`,
    `HEAD def456`,
    `branch refs/heads/feat/auth`,
    ``,
  ].join(`\n`)

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
      [`git -C ${fixture.featureWorktreePath} rev-parse --show-toplevel`]: {
        stdout: `${fixture.repoRoot}\n`,
      },
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

      if (key === `git -C ${fixture.repoRoot} rev-parse --show-toplevel`) {
        return ok(`${fixture.repoRoot}\n`)
      }

      if (key === `git -C ${fixture.repoRoot} remote get-url origin`) {
        return ok(`git@github.com:jasonkuhrt/flo.git\n`)
      }

      if (key === `git -C ${fixture.repoRoot} worktree list --porcelain`) {
        return ok(mainWorktreeList(fixture.repoRoot))
      }

      if (key === `cmux ping`) return ok()
      if (key === `cmux --json list-workspaces`) {
        return ok(JSON.stringify({ workspaces: [{ id: `workspace:3`, title: `renamed-main` }] }))
      }

      if (key === `cmux --json sidebar-state --workspace workspace:3`) {
        return ok(
          JSON.stringify({
            cwd: fixture.repoRoot,
            statuses: [],
          }),
        )
      }

      if (key.startsWith(`cmux set-status flo.`)) return ok()
      if (key === `cmux select-workspace --workspace workspace:3`) return ok()

      return fail()
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

    const statePath = getDefaultStatePath(fixture.env)
    expect(await Bun.file(statePath).exists()).toBe(true)
    const state = await loadState(fixture.env)
    const record = state.workspaces[0]
    expect(record).toBeDefined()
    expect(record?.workspaceTitle).toBe(`flo:flo`)
    expect(record?.checkoutPath).toBe(fixture.repoRoot)
    expect(record?.lastAction).toBe(`open`)
  })

  it(`starts GitHub issue work by planning a feature checkout`, async () => {
    const fixture = await makeRepoFixture()
    const runner = mockRunner({
      [`git -C ${fixture.repoRoot} rev-parse --show-toplevel`]: { stdout: `${fixture.repoRoot}\n` },
      [`git -C ${fixture.featureWorktreePath} rev-parse --show-toplevel`]: {
        stdout: `${fixture.repoRoot}\n`,
      },
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

  it(`explains open by distinguishing init from focus`, async () => {
    const fixture = await makeRepoFixture()
    const runner = mockRunner({
      [`git -C ${fixture.repoRoot} rev-parse --show-toplevel`]: { stdout: `${fixture.repoRoot}\n` },
      [`git -C ${fixture.repoRoot} remote get-url origin`]: {
        stdout: `git@github.com:jasonkuhrt/flo.git\n`,
      },
      [`git -C ${fixture.repoRoot} worktree list --porcelain`]: {
        stdout: mainWorktreeList(fixture.repoRoot),
      },
      [`cmux ping`]: ok(),
      [`cmux --json list-workspaces`]: ok(
        JSON.stringify({ workspaces: [{ id: `workspace:3`, title: `renamed-main` }] }),
      ),
      [`cmux --json sidebar-state --workspace workspace:3`]: ok(
        JSON.stringify({
          cwd: fixture.repoRoot,
          statuses: [{ key: `flo.identity`, value: `ce8d4f6cf89f` }],
        }),
      ),
    })

    const result = await explainOpen({
      context: {
        cwd: fixture.repoRoot,
        env: fixture.env,
      },
      dependencies: { runner },
    })

    expect(result.workspace.action).toBe(`focus-existing`)
    expect(result.workspace.existingWorkspace).toEqual({
      id: `workspace:3`,
      title: `renamed-main`,
    })
    expect(result.init.layout.focus).toBe(`editor`)
  })

  it(`explains start with checkout creation and init steps`, async () => {
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
      [`cmux ping`]: ok(),
      [`cmux --json list-workspaces`]: ok(JSON.stringify({ workspaces: [] })),
    })

    const result = await explainStart({
      context: {
        cwd: fixture.repoRoot,
        env: fixture.env,
      },
      selector: `42`,
      dependencies: { runner },
    })

    expect(result.createdCheckout).toBe(true)
    expect(result.workspace.action).toBe(`create-and-init`)
    expect(result.init.claude?.sessionName).toContain(`claude`)
    expect(result.issue?.number).toBe(42)
  })

  it(`previews open init without mutating workspace state`, async () => {
    const fixture = await makeRepoFixture()
    const runner = mockRunner({
      [`git -C ${fixture.repoRoot} rev-parse --show-toplevel`]: { stdout: `${fixture.repoRoot}\n` },
      [`git -C ${fixture.repoRoot} remote get-url origin`]: {
        stdout: `git@github.com:jasonkuhrt/flo.git\n`,
      },
      [`git -C ${fixture.repoRoot} worktree list --porcelain`]: {
        stdout: mainWorktreeList(fixture.repoRoot),
      },
      [`cmux ping`]: ok(),
      [`cmux --json list-workspaces`]: ok(JSON.stringify({ workspaces: [] })),
    })

    const result = await previewInitOpen({
      context: {
        cwd: fixture.repoRoot,
        env: fixture.env,
      },
      dependencies: { runner },
    })

    expect(result.command).toBe(`open`)
    expect(result.appliesNow).toBe(true)
    expect(result.workspace.action).toBe(`create-and-init`)
  })

  it(`previews start init even when the workspace already exists`, async () => {
    const fixture = await makeRepoFixture()
    const runner = mockRunner({
      [`git -C ${fixture.repoRoot} rev-parse --show-toplevel`]: { stdout: `${fixture.repoRoot}\n` },
      [`git -C ${fixture.repoRoot} remote get-url origin`]: {
        stdout: `git@github.com:jasonkuhrt/flo.git\n`,
      },
      [`git -C ${fixture.repoRoot} worktree list --porcelain`]: {
        stdout: featureWorktreeList(fixture.repoRoot, fixture.featureWorktreePath),
      },
      [`cmux ping`]: ok(),
      [`cmux --json list-workspaces`]: ok(
        JSON.stringify({ workspaces: [{ id: `workspace:4`, title: `flo:flo@feat/auth` }] }),
      ),
      [`cmux --json sidebar-state --workspace workspace:4`]: ok(
        JSON.stringify({
          cwd: fixture.featureWorktreePath,
          statuses: [],
        }),
      ),
    })

    const result = await previewInitStart({
      context: {
        cwd: fixture.repoRoot,
        env: fixture.env,
      },
      selector: `feat/auth`,
      dependencies: { runner },
    })

    expect(result.command).toBe(`start`)
    expect(result.appliesNow).toBe(false)
    expect(result.workspace.action).toBe(`focus-existing`)
  })

  it(`explains end and optional reopen-main behavior`, async () => {
    const fixture = await makeRepoFixture()
    const runner = mockRunner({
      [`git -C ${fixture.repoRoot} rev-parse --show-toplevel`]: { stdout: `${fixture.repoRoot}\n` },
      [`git -C ${fixture.featureWorktreePath} rev-parse --show-toplevel`]: {
        stdout: `${fixture.repoRoot}\n`,
      },
      [`git -C ${fixture.repoRoot} remote get-url origin`]: {
        stdout: `git@github.com:jasonkuhrt/flo.git\n`,
      },
      [`git -C ${fixture.repoRoot} worktree list --porcelain`]: {
        stdout: featureWorktreeList(fixture.repoRoot, fixture.featureWorktreePath),
      },
      [`cmux ping`]: ok(),
      [`cmux --json list-workspaces`]: ok(
        JSON.stringify({
          workspaces: [
            { id: `workspace:4`, title: `flo:flo@feat/auth` },
            { id: `workspace:5`, title: `flo:flo` },
          ],
        }),
      ),
      [`cmux --json sidebar-state --workspace workspace:4`]: ok(
        JSON.stringify({
          cwd: fixture.featureWorktreePath,
          statuses: [{ key: `flo.identity`, value: `feature123456` }],
        }),
      ),
      [`cmux --json sidebar-state --workspace workspace:5`]: ok(
        JSON.stringify({
          cwd: fixture.repoRoot,
          statuses: [{ key: `flo.identity`, value: `main123456789` }],
        }),
      ),
    })

    const result = await explainEnd({
      context: {
        cwd: fixture.featureWorktreePath,
        env: fixture.env,
      },
      openMain: true,
      dependencies: { runner },
    })

    expect(result.workspace.action).toBe(`close-existing`)
    expect(result.reopensMainWorkspace?.action).toBe(`focus-existing`)
    expect(result.sessions.editor).toContain(`editor`)
  })

  it(`starts work from outside the repo when an explicit project selector is provided`, async () => {
    const fixture = await makeRepoFixture()
    const configPath = fixture.env[`FLO_CONFIG_PATH`]
    if (configPath === undefined) {
      throw new Error(`expected FLO_CONFIG_PATH in fixture env`)
    }

    await writeFile(
      configPath,
      JSON.stringify({
        projects: [{ name: `flo`, path: fixture.repoRoot }],
      }),
    )
    const runner = mockRunner({
      [`git -C ${fixture.repoRoot} rev-parse --show-toplevel`]: { stdout: `${fixture.repoRoot}\n` },
      [`git -C ${tmpdir()} rev-parse --show-toplevel`]: { exitCode: 1 },
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
        cwd: tmpdir(),
        env: fixture.env,
      },
      selector: `42`,
      projectSelector: `flo`,
      dependencies: { runner },
    })

    expect(result).toMatchObject({
      project: {
        name: `flo`,
      },
      checkout: {
        branch: `issue/42-add-launcher`,
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

      if (key === `git -C ${fixture.repoRoot} rev-parse --show-toplevel`) {
        return ok(`${fixture.repoRoot}\n`)
      }

      if (key === `git -C ${fixture.repoRoot} remote get-url origin`) {
        return ok(`git@github.com:jasonkuhrt/flo.git\n`)
      }

      if (key === `git -C ${fixture.repoRoot} worktree list --porcelain`) {
        return ok(mainWorktreeList(fixture.repoRoot))
      }

      if (key === `git -C ${fixture.repoRoot} show-ref --verify --quiet refs/heads/feat/auth`) {
        return fail()
      }

      if (
        key ===
        `git -C ${fixture.repoRoot} worktree add -b feat/auth ${fixture.featureWorktreePath}`
      ) {
        return ok()
      }

      if (key === `cmux ping`) return ok()
      if (key === `cmux --json list-workspaces`) return ok(JSON.stringify({ workspaces: [] }))
      if (key === `cmux new-workspace`) return ok()
      if (key === `cmux --json current-workspace`) {
        return ok(JSON.stringify({ id: `workspace:4`, title: `untitled` }))
      }

      if (key === `cmux rename-workspace --workspace workspace:4 flo:flo@feat/auth`) return ok()
      if (key.startsWith(`cmux set-status flo.`)) return ok()
      if (key === `cmux new-pane --workspace workspace:4 --direction right`) return ok()
      if (key === `cmux last-pane --workspace workspace:4`) return ok()

      if (key.startsWith(`cmux send --workspace workspace:4 exec 'zmx' attach `)) {
        return ok()
      }

      return fail()
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
    expect(calls).toContain(`cmux new-pane --workspace workspace:4 --direction right`)
    expect(calls).toContain(`cmux last-pane --workspace workspace:4`)
  })

  it(`applies feature workspace profile overrides`, async () => {
    const fixture = await makeRepoFixture()
    await mkdir(fixture.featureWorktreePath, { recursive: true })
    const configPath = fixture.env[`FLO_CONFIG_PATH`]
    if (configPath === undefined) {
      throw new Error(`expected FLO_CONFIG_PATH in fixture env`)
    }

    await writeFile(
      configPath,
      JSON.stringify({
        runtime: {
          profiles: {
            feature: {
              layout: {
                splitDirection: `bottom`,
              },
              editorCommand: `nvim +'FloFeatureInit'`,
              claudeCommand: `claude --resume`,
            },
          },
        },
      }),
    )

    const calls: string[] = []
    const runner: CommandRunner = async (command, args = []) => {
      const key = [command, ...args].join(` `)
      calls.push(key)

      if (key === `git -C ${fixture.repoRoot} rev-parse --show-toplevel`) {
        return ok(`${fixture.repoRoot}\n`)
      }

      if (key === `git -C ${fixture.repoRoot} remote get-url origin`) {
        return ok(`git@github.com:jasonkuhrt/flo.git\n`)
      }

      if (key === `git -C ${fixture.repoRoot} worktree list --porcelain`) {
        return ok(mainWorktreeList(fixture.repoRoot))
      }

      if (key === `git -C ${fixture.repoRoot} show-ref --verify --quiet refs/heads/feat/auth`) {
        return fail()
      }

      if (
        key ===
        `git -C ${fixture.repoRoot} worktree add -b feat/auth ${fixture.featureWorktreePath}`
      ) {
        return ok()
      }

      if (key === `cmux ping`) return ok()
      if (key === `cmux --json list-workspaces`) return ok(JSON.stringify({ workspaces: [] }))
      if (key === `cmux new-workspace`) return ok()
      if (key === `cmux --json current-workspace`) {
        return ok(JSON.stringify({ id: `workspace:4`, title: `untitled` }))
      }

      if (key === `cmux rename-workspace --workspace workspace:4 flo:flo@feat/auth`) return ok()
      if (key.startsWith(`cmux set-status flo.`)) return ok()
      if (key === `cmux new-pane --workspace workspace:4 --direction down`) return ok()
      if (key === `cmux last-pane --workspace workspace:4`) return ok()

      if (key.startsWith(`cmux send --workspace workspace:4 exec 'zmx' attach `)) {
        return ok()
      }

      return fail()
    }

    const result = await startWork({
      context: {
        cwd: fixture.repoRoot,
        env: fixture.env,
      },
      selector: `feat/auth`,
      dependencies: { runner },
    })

    expect(result.workspaceLayout.splitDirection).toBe(`bottom`)
    expect(calls).toContain(`cmux new-pane --workspace workspace:4 --direction down`)
    expect(calls.some((call) => call.includes(`FloFeatureInit`))).toBe(true)
    expect(calls.some((call) => call.includes(`claude --resume`))).toBe(true)
  })

  it(`applies project workspace profile overrides on top of runtime defaults`, async () => {
    const fixture = await makeRepoFixture()
    await mkdir(fixture.featureWorktreePath, { recursive: true })
    const configPath = fixture.env[`FLO_CONFIG_PATH`]
    if (configPath === undefined) {
      throw new Error(`expected FLO_CONFIG_PATH in fixture env`)
    }

    await writeFile(
      configPath,
      JSON.stringify({
        runtime: {
          profiles: {
            feature: {
              layout: {
                splitDirection: `bottom`,
              },
              editorCommand: `nvim +RuntimeFeatureInit`,
            },
          },
        },
        projects: [
          {
            name: `flo`,
            path: fixture.repoRoot,
            workspaceProfiles: {
              feature: {
                layout: {
                  splitDirection: `right`,
                },
                editorCommand: `nvim +ProjectFeatureInit`,
                claudeCommand: `claude --print`,
              },
            },
          },
        ],
      }),
    )

    const calls: string[] = []
    const runner: CommandRunner = async (command, args = []) => {
      const key = [command, ...args].join(` `)
      calls.push(key)

      if (key === `git -C ${fixture.repoRoot} rev-parse --show-toplevel`) {
        return ok(`${fixture.repoRoot}\n`)
      }

      if (key === `git -C ${fixture.repoRoot} remote get-url origin`) {
        return ok(`git@github.com:jasonkuhrt/flo.git\n`)
      }

      if (key === `git -C ${fixture.repoRoot} worktree list --porcelain`) {
        return ok(mainWorktreeList(fixture.repoRoot))
      }

      if (key === `git -C ${fixture.repoRoot} show-ref --verify --quiet refs/heads/feat/auth`) {
        return fail()
      }

      if (
        key ===
        `git -C ${fixture.repoRoot} worktree add -b feat/auth ${fixture.featureWorktreePath}`
      ) {
        return ok()
      }

      if (key === `cmux ping`) return ok()
      if (key === `cmux --json list-workspaces`) return ok(JSON.stringify({ workspaces: [] }))
      if (key === `cmux new-workspace`) return ok()
      if (key === `cmux --json current-workspace`) {
        return ok(JSON.stringify({ id: `workspace:4`, title: `untitled` }))
      }

      if (key === `cmux rename-workspace --workspace workspace:4 flo:flo@feat/auth`) return ok()
      if (key.startsWith(`cmux set-status flo.`)) return ok()
      if (key === `cmux new-pane --workspace workspace:4 --direction right`) return ok()
      if (key === `cmux last-pane --workspace workspace:4`) return ok()

      if (key.startsWith(`cmux send --workspace workspace:4 exec 'zmx' attach `)) {
        return ok()
      }

      return fail()
    }

    const result = await startWork({
      context: {
        cwd: fixture.repoRoot,
        env: fixture.env,
      },
      selector: `feat/auth`,
      dependencies: { runner },
    })

    expect(result.workspaceLayout.splitDirection).toBe(`right`)
    expect(calls).toContain(`cmux new-pane --workspace workspace:4 --direction right`)
    expect(calls.some((call) => call.includes(`ProjectFeatureInit`))).toBe(true)
    expect(calls.some((call) => call.includes(`RuntimeFeatureInit`))).toBe(false)
    expect(calls.some((call) => call.includes(`claude --print`))).toBe(true)
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
        stdout: JSON.stringify({ workspaces: [{ id: `workspace:3`, title: `renamed-main` }] }),
      },
      [`cmux --json sidebar-state --workspace workspace:3`]: {
        stdout: JSON.stringify({ cwd: fixture.repoRoot, statuses: [] }),
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

  it(`filters list output to a single project`, async () => {
    const fixture = await makeRepoFixture()
    const siblingRepo = join(dirname(fixture.repoRoot), `dotfiles`)
    await mkdir(siblingRepo, { recursive: true })
    const configPath = fixture.env[`FLO_CONFIG_PATH`]
    if (configPath === undefined) {
      throw new Error(`expected FLO_CONFIG_PATH in fixture env`)
    }

    await writeFile(
      configPath,
      JSON.stringify({
        projects: [
          { name: `flo`, path: fixture.repoRoot },
          { name: `dotfiles`, path: siblingRepo },
        ],
      }),
    )

    const runner = mockRunner({
      [`git -C ${fixture.repoRoot} rev-parse --show-toplevel`]: ok(`${fixture.repoRoot}\n`),
      [`git -C ${siblingRepo} rev-parse --show-toplevel`]: ok(`${siblingRepo}\n`),
      [`git -C ${fixture.repoRoot} remote get-url origin`]: ok(
        `git@github.com:jasonkuhrt/flo.git\n`,
      ),
      [`git -C ${siblingRepo} remote get-url origin`]: ok(
        `git@github.com:jasonkuhrt/dotfiles.git\n`,
      ),
      [`git -C ${fixture.repoRoot} worktree list --porcelain`]: ok(
        mainWorktreeList(fixture.repoRoot),
      ),
      [`git -C ${siblingRepo} worktree list --porcelain`]: ok(mainWorktreeList(siblingRepo)),
      [`cmux ping`]: fail(),
    })

    const result = await listFloState({
      context: {
        cwd: fixture.repoRoot,
        env: fixture.env,
      },
      projectSelector: `flo`,
      dependencies: { runner },
    })

    expect(result.projects).toHaveLength(1)
    expect(result.projects[0]?.name).toBe(`flo`)
  })

  it(`filters list output to only open workspaces`, async () => {
    const fixture = await makeRepoFixture()
    const runner = mockRunner({
      [`git -C ${fixture.repoRoot} rev-parse --show-toplevel`]: { stdout: `${fixture.repoRoot}\n` },
      [`git -C ${fixture.repoRoot} remote get-url origin`]: {
        stdout: `git@github.com:jasonkuhrt/flo.git\n`,
      },
      [`git -C ${fixture.repoRoot} worktree list --porcelain`]: {
        stdout: featureWorktreeList(fixture.repoRoot, fixture.featureWorktreePath),
      },
      [`cmux ping`]: ok(),
      [`cmux --json list-workspaces`]: {
        stdout: JSON.stringify({ workspaces: [{ id: `workspace:3`, title: `flo:flo` }] }),
      },
      [`cmux --json sidebar-state --workspace workspace:3`]: {
        stdout: JSON.stringify({ cwd: fixture.repoRoot, statuses: [] }),
      },
    })

    const result = await listFloState({
      context: {
        cwd: fixture.repoRoot,
        env: fixture.env,
      },
      openOnly: true,
      dependencies: { runner },
    })

    expect(result.projects).toHaveLength(1)
    expect(result.projects[0]?.checkouts).toHaveLength(1)
    expect(result.projects[0]?.checkouts[0]?.isMain).toBe(true)
  })

  it(`sorts checkouts by recency when listing state`, async () => {
    const fixture = await makeRepoFixture()
    const planningRunner = mockRunner({
      [`git -C ${fixture.repoRoot} rev-parse --show-toplevel`]: { stdout: `${fixture.repoRoot}\n` },
      [`git -C ${fixture.repoRoot} remote get-url origin`]: {
        stdout: `git@github.com:jasonkuhrt/flo.git\n`,
      },
      [`git -C ${fixture.repoRoot} worktree list --porcelain`]: {
        stdout: featureWorktreeList(fixture.repoRoot, fixture.featureWorktreePath),
      },
    })
    const mainTarget = await resolveOpenTarget({
      context: {
        cwd: fixture.repoRoot,
        env: fixture.env,
      },
      dependencies: { runner: planningRunner },
    })
    const featureTarget = await resolveStartTarget({
      context: {
        cwd: fixture.repoRoot,
        env: fixture.env,
      },
      selector: `feat/auth`,
      dependencies: { runner: planningRunner },
    })

    await saveState(fixture.env, {
      version: 1,
      workspaces: [
        {
          workspaceIdentity: mainTarget.workspaceMetadata.identity,
          workspaceTitle: mainTarget.workspaceTitle,
          projectName: `flo`,
          checkoutPath: fixture.repoRoot,
          branch: null,
          isMain: true,
          lastOpenedAt: `2026-03-06T10:00:00.000Z`,
          lastAction: `open`,
        },
        {
          workspaceIdentity: featureTarget.workspaceMetadata.identity,
          workspaceTitle: featureTarget.workspaceTitle,
          projectName: `flo`,
          checkoutPath: fixture.featureWorktreePath,
          branch: `feat/auth`,
          isMain: false,
          lastOpenedAt: `2026-03-07T10:00:00.000Z`,
          lastAction: `start`,
        },
      ],
    })

    const runner = mockRunner({
      [`git -C ${fixture.repoRoot} rev-parse --show-toplevel`]: { stdout: `${fixture.repoRoot}\n` },
      [`git -C ${fixture.repoRoot} remote get-url origin`]: {
        stdout: `git@github.com:jasonkuhrt/flo.git\n`,
      },
      [`git -C ${fixture.repoRoot} worktree list --porcelain`]: {
        stdout: featureWorktreeList(fixture.repoRoot, fixture.featureWorktreePath),
      },
      [`cmux ping`]: { exitCode: 1 },
    })

    const result = await listFloState({
      context: {
        cwd: fixture.repoRoot,
        env: fixture.env,
      },
      dependencies: { runner },
    })

    expect(result.projects[0]?.checkouts[0]?.branch).toBe(`feat/auth`)
    expect(result.projects[0]?.checkouts[0]?.lastOpenedAt).toBe(`2026-03-07T10:00:00.000Z`)
    expect(result.projects[0]?.checkouts[1]?.isMain).toBe(true)
  })

  it(`lists only active recent work`, async () => {
    const fixture = await makeRepoFixture()
    const runner = mockRunner({
      [`git -C ${fixture.repoRoot} rev-parse --show-toplevel`]: { stdout: `${fixture.repoRoot}\n` },
      [`git -C ${fixture.repoRoot} remote get-url origin`]: {
        stdout: `git@github.com:jasonkuhrt/flo.git\n`,
      },
      [`git -C ${fixture.repoRoot} worktree list --porcelain`]: {
        stdout: featureWorktreeList(fixture.repoRoot, fixture.featureWorktreePath),
      },
      [`cmux ping`]: { exitCode: 1 },
    })
    const mainTarget = await resolveOpenTarget({
      context: {
        cwd: fixture.repoRoot,
        env: fixture.env,
      },
      dependencies: { runner },
    })
    const featureTarget = await resolveStartTarget({
      context: {
        cwd: fixture.repoRoot,
        env: fixture.env,
      },
      selector: `feat/auth`,
      dependencies: { runner },
    })

    await saveState(fixture.env, {
      version: 1,
      workspaces: [
        {
          workspaceIdentity: featureTarget.workspaceMetadata.identity,
          workspaceTitle: featureTarget.workspaceTitle,
          projectName: `flo`,
          checkoutPath: fixture.featureWorktreePath,
          branch: `feat/auth`,
          isMain: false,
          lastOpenedAt: `2026-03-07T10:00:00.000Z`,
          lastAction: `start`,
        },
        {
          workspaceIdentity: `orphan`,
          workspaceTitle: `flo:old`,
          projectName: `flo`,
          checkoutPath: `${fixture.repoRoot}/old`,
          branch: `old`,
          isMain: false,
          lastOpenedAt: `2026-03-07T09:00:00.000Z`,
          lastAction: `start`,
        },
        {
          workspaceIdentity: mainTarget.workspaceMetadata.identity,
          workspaceTitle: mainTarget.workspaceTitle,
          projectName: `flo`,
          checkoutPath: fixture.repoRoot,
          branch: null,
          isMain: true,
          lastOpenedAt: `2026-03-06T10:00:00.000Z`,
          lastAction: `open`,
        },
      ],
    })

    const result = await listRecentWork({
      context: {
        cwd: fixture.repoRoot,
        env: fixture.env,
      },
      dependencies: { runner },
    })

    expect(result.items).toHaveLength(2)
    expect(result.items[0]).toMatchObject({
      selector: `flo@feat/auth`,
      lastAction: `start`,
    })
    expect(result.items[1]).toMatchObject({
      selector: `flo`,
      lastAction: `open`,
    })
  })

  it(`limits recent work output`, async () => {
    const fixture = await makeRepoFixture()
    const runner = mockRunner({
      [`git -C ${fixture.repoRoot} rev-parse --show-toplevel`]: { stdout: `${fixture.repoRoot}\n` },
      [`git -C ${fixture.repoRoot} remote get-url origin`]: {
        stdout: `git@github.com:jasonkuhrt/flo.git\n`,
      },
      [`git -C ${fixture.repoRoot} worktree list --porcelain`]: {
        stdout: featureWorktreeList(fixture.repoRoot, fixture.featureWorktreePath),
      },
      [`cmux ping`]: { exitCode: 1 },
    })
    const mainTarget = await resolveOpenTarget({
      context: {
        cwd: fixture.repoRoot,
        env: fixture.env,
      },
      dependencies: { runner },
    })
    const featureTarget = await resolveStartTarget({
      context: {
        cwd: fixture.repoRoot,
        env: fixture.env,
      },
      selector: `feat/auth`,
      dependencies: { runner },
    })

    await saveState(fixture.env, {
      version: 1,
      workspaces: [
        {
          workspaceIdentity: featureTarget.workspaceMetadata.identity,
          workspaceTitle: featureTarget.workspaceTitle,
          projectName: `flo`,
          checkoutPath: fixture.featureWorktreePath,
          branch: `feat/auth`,
          isMain: false,
          lastOpenedAt: `2026-03-07T10:00:00.000Z`,
          lastAction: `start`,
        },
        {
          workspaceIdentity: mainTarget.workspaceMetadata.identity,
          workspaceTitle: mainTarget.workspaceTitle,
          projectName: `flo`,
          checkoutPath: fixture.repoRoot,
          branch: null,
          isMain: true,
          lastOpenedAt: `2026-03-06T10:00:00.000Z`,
          lastAction: `open`,
        },
      ],
    })

    const result = await listRecentWork({
      context: {
        cwd: fixture.repoRoot,
        env: fixture.env,
      },
      projectSelector: `flo`,
      limit: 1,
      dependencies: { runner },
    })

    expect(result.items).toHaveLength(1)
    expect(result.items[0]?.selector).toBe(`flo@feat/auth`)
  })

  it(`opens the most recent workspace`, async () => {
    const fixture = await makeRepoFixture()
    const runner = mockRunner({
      [`git -C ${fixture.repoRoot} rev-parse --show-toplevel`]: { stdout: `${fixture.repoRoot}\n` },
      [`git -C ${fixture.repoRoot} remote get-url origin`]: {
        stdout: `git@github.com:jasonkuhrt/flo.git\n`,
      },
      [`git -C ${fixture.repoRoot} worktree list --porcelain`]: {
        stdout: featureWorktreeList(fixture.repoRoot, fixture.featureWorktreePath),
      },
      [`cmux ping`]: { exitCode: 1 },
    })
    const mainTarget = await resolveOpenTarget({
      context: {
        cwd: fixture.repoRoot,
        env: fixture.env,
      },
      dependencies: { runner },
    })
    const featureTarget = await resolveStartTarget({
      context: {
        cwd: fixture.repoRoot,
        env: fixture.env,
      },
      selector: `feat/auth`,
      dependencies: { runner },
    })

    await saveState(fixture.env, {
      version: 1,
      workspaces: [
        {
          workspaceIdentity: featureTarget.workspaceMetadata.identity,
          workspaceTitle: featureTarget.workspaceTitle,
          projectName: `flo`,
          checkoutPath: fixture.featureWorktreePath,
          branch: `feat/auth`,
          isMain: false,
          lastOpenedAt: `2026-03-07T10:00:00.000Z`,
          lastAction: `start`,
        },
        {
          workspaceIdentity: mainTarget.workspaceMetadata.identity,
          workspaceTitle: mainTarget.workspaceTitle,
          projectName: `flo`,
          checkoutPath: fixture.repoRoot,
          branch: null,
          isMain: true,
          lastOpenedAt: `2026-03-06T10:00:00.000Z`,
          lastAction: `open`,
        },
      ],
    })

    const result = await openLastWorkspace({
      context: {
        cwd: fixture.repoRoot,
        env: fixture.env,
      },
      dryRun: true,
      dependencies: { runner },
    })

    expect(result.checkout.branch).toBe(`feat/auth`)
    expect(result.workspaceTitle).toBe(`flo:flo@feat/auth`)
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

  it(`ends a feature checkout by closing the workspace and removing the worktree`, async () => {
    const fixture = await makeRepoFixture()
    const calls: string[] = []
    const runner: CommandRunner = async (command, args = []) => {
      const key = [command, ...args].join(` `)
      calls.push(key)

      if (key === `git -C ${fixture.featureWorktreePath} rev-parse --show-toplevel`) {
        return ok(`${fixture.repoRoot}\n`)
      }
      if (key === `git -C ${fixture.repoRoot} rev-parse --show-toplevel`)
        return ok(`${fixture.repoRoot}\n`)
      if (key === `git -C ${fixture.repoRoot} remote get-url origin`) {
        return ok(`git@github.com:jasonkuhrt/flo.git\n`)
      }
      if (key === `git -C ${fixture.repoRoot} worktree list --porcelain`) {
        return ok(featureWorktreeList(fixture.repoRoot, fixture.featureWorktreePath))
      }
      if (key === `git -C ${fixture.featureWorktreePath} status --short`) return ok()
      if (key === `cmux ping`) return ok()
      if (key === `cmux --json list-workspaces`) {
        return ok(JSON.stringify({ workspaces: [{ id: `workspace:8`, title: `feature` }] }))
      }
      if (key === `cmux --json sidebar-state --workspace workspace:8`) {
        return ok(
          JSON.stringify({
            cwd: fixture.featureWorktreePath,
            statuses: [],
          }),
        )
      }
      if (key === `cmux close-workspace --workspace workspace:8`) return ok()
      if (key === `zmx list --short`) return ok(`flo-flo-feature-deadbeef0000-editor\n`)
      if (key.startsWith(`zmx kill flo-flo-feature-`)) return ok()
      if (key === `git -C ${fixture.repoRoot} worktree remove ${fixture.featureWorktreePath}`) {
        return ok()
      }

      return fail()
    }

    const result = await endWork({
      context: {
        cwd: fixture.featureWorktreePath,
        env: fixture.env,
      },
      dependencies: { runner },
    })

    expect(result.removedCheckout).toBe(true)
    expect(result.closedWorkspace).toBe(true)
    expect(calls).toContain(`cmux close-workspace --workspace workspace:8`)
    expect(calls).toContain(
      `git -C ${fixture.repoRoot} worktree remove ${fixture.featureWorktreePath}`,
    )
  })

  it(`can return to the main workspace after ending work`, async () => {
    const fixture = await makeRepoFixture()
    const calls: string[] = []
    const runner: CommandRunner = async (command, args = []) => {
      const key = [command, ...args].join(` `)
      calls.push(key)

      if (key === `git -C ${fixture.featureWorktreePath} rev-parse --show-toplevel`) {
        return ok(`${fixture.repoRoot}\n`)
      }
      if (key === `git -C ${fixture.repoRoot} rev-parse --show-toplevel`) {
        return ok(`${fixture.repoRoot}\n`)
      }
      if (key === `git -C ${fixture.repoRoot} remote get-url origin`) {
        return ok(`git@github.com:jasonkuhrt/flo.git\n`)
      }
      if (key === `git -C ${fixture.repoRoot} worktree list --porcelain`) {
        return ok(featureWorktreeList(fixture.repoRoot, fixture.featureWorktreePath))
      }
      if (key === `git -C ${fixture.featureWorktreePath} status --short`) return ok()
      if (key === `cmux ping`) return ok()
      if (key === `cmux --json list-workspaces`) {
        return ok(
          JSON.stringify({
            workspaces: [
              { id: `workspace:3`, title: `main` },
              { id: `workspace:8`, title: `feature` },
            ],
          }),
        )
      }
      if (key === `cmux --json sidebar-state --workspace workspace:3`) {
        return ok(
          JSON.stringify({
            cwd: fixture.repoRoot,
            statuses: [],
          }),
        )
      }
      if (key === `cmux --json sidebar-state --workspace workspace:8`) {
        return ok(
          JSON.stringify({
            cwd: fixture.featureWorktreePath,
            statuses: [],
          }),
        )
      }
      if (key === `cmux close-workspace --workspace workspace:8`) return ok()
      if (key === `cmux select-workspace --workspace workspace:3`) return ok()
      if (key.startsWith(`cmux set-status flo.`)) return ok()
      if (key === `zmx list --short`) return ok(`flo-flo-feature-deadbeef0000-editor\n`)
      if (key.startsWith(`zmx kill flo-flo-feature-`)) return ok()
      if (key === `git -C ${fixture.repoRoot} worktree remove ${fixture.featureWorktreePath}`) {
        return ok()
      }

      return fail()
    }

    const result = await endWork({
      context: {
        cwd: fixture.featureWorktreePath,
        env: fixture.env,
      },
      openMain: true,
      dependencies: { runner },
    })

    expect(result.reopenedMainWorkspace).toBe(true)
    expect(result.reopenedMainWorkspaceId).toBe(`workspace:3`)
    expect(calls).toContain(`cmux select-workspace --workspace workspace:3`)
  })

  it(`reports doctor information for the current checkout`, async () => {
    const fixture = await makeRepoFixture()
    const runner = mockRunner({
      [`/bin/zsh -lc command -v -- 'git'`]: ok(`/usr/bin/git\n`),
      [`/bin/zsh -lc command -v -- 'cmux'`]: ok(`/opt/homebrew/bin/cmux\n`),
      [`/bin/zsh -lc command -v -- 'zmx'`]: ok(`/opt/homebrew/bin/zmx\n`),
      [`/bin/zsh -lc command -v -- 'fzf'`]: ok(`/opt/homebrew/bin/fzf\n`),
      [`/bin/zsh -lc command -v -- 'claude'`]: ok(`/opt/homebrew/bin/claude\n`),
      [`/bin/zsh -lc command -v -- 'nvim'`]: ok(`/opt/homebrew/bin/nvim\n`),
      [`/bin/zsh -lc command -v -- 'gh'`]: ok(`/opt/homebrew/bin/gh\n`),
      [`git -C ${fixture.repoRoot} rev-parse --show-toplevel`]: ok(`${fixture.repoRoot}\n`),
      [`git -C ${fixture.repoRoot} remote get-url origin`]: ok(
        `git@github.com:jasonkuhrt/flo.git\n`,
      ),
      [`git -C ${fixture.repoRoot} worktree list --porcelain`]: ok(
        mainWorktreeList(fixture.repoRoot),
      ),
      [`cmux ping`]: ok(),
    })

    const result = await doctorFlo({
      context: {
        cwd: fixture.repoRoot,
        env: fixture.env,
      },
      dependencies: { runner },
    })

    expect(result).toMatchObject({
      configExists: false,
      currentProject: {
        name: `flo`,
      },
      currentCheckout: {
        path: fixture.repoRoot,
        isMain: true,
      },
      cmuxAvailable: true,
    })
    expect(result.commands.some((command) => command.key === `git` && command.available)).toBe(true)
    expect(result.commands.some((command) => command.key === `cmux` && command.available)).toBe(
      true,
    )
    expect(result.commands.some((command) => command.key === `gh` && command.available)).toBe(true)
  })

  it(`reports status for the current checkout and matching workspace`, async () => {
    const fixture = await makeRepoFixture()
    const runner = mockRunner({
      [`git -C ${fixture.repoRoot} rev-parse --show-toplevel`]: ok(`${fixture.repoRoot}\n`),
      [`git -C ${fixture.repoRoot} remote get-url origin`]: ok(
        `git@github.com:jasonkuhrt/flo.git\n`,
      ),
      [`git -C ${fixture.repoRoot} worktree list --porcelain`]: ok(
        mainWorktreeList(fixture.repoRoot),
      ),
      [`cmux ping`]: ok(),
      [`cmux --json list-workspaces`]: ok(
        JSON.stringify({ workspaces: [{ id: `workspace:3`, title: `renamed-main` }] }),
      ),
      [`cmux --json sidebar-state --workspace workspace:3`]: ok(
        JSON.stringify({
          cwd: fixture.repoRoot,
          statuses: [{ key: `flo.identity`, value: `4f1e7d7dbf9a` }],
        }),
      ),
    })

    const result = await statusFlo({
      context: {
        cwd: fixture.repoRoot,
        env: fixture.env,
      },
      dependencies: { runner },
    })

    expect(result).toMatchObject({
      currentProject: {
        name: `flo`,
      },
      currentCheckout: {
        path: fixture.repoRoot,
        isMain: true,
      },
      expectedWorkspace: {
        title: `flo:flo`,
      },
      activeWorkspace: {
        id: `workspace:3`,
        title: `renamed-main`,
      },
    })
  })

  it(`bootstraps a minimal config for the current project`, async () => {
    const fixture = await makeRepoFixture()
    const configPath = fixture.env[`FLO_CONFIG_PATH`]
    if (configPath === undefined) {
      throw new Error(`expected FLO_CONFIG_PATH in fixture env`)
    }

    const runner = mockRunner({
      [`git -C ${fixture.repoRoot} rev-parse --show-toplevel`]: ok(`${fixture.repoRoot}\n`),
      [`git -C ${fixture.repoRoot} remote get-url origin`]: ok(
        `git@github.com:jasonkuhrt/flo.git\n`,
      ),
    })

    const result = await initConfig({
      context: {
        cwd: fixture.repoRoot,
        env: fixture.env,
      },
      dependencies: { runner },
    })

    expect(result.wroteConfig).toBe(true)
    expect(await Bun.file(configPath).text()).toContain(`"name": "flo"`)
    expect(await Bun.file(configPath).text()).toContain(`"repo": "jasonkuhrt/flo"`)
  })

  it(`installs Claude hook settings for the current checkout`, async () => {
    const fixture = await makeRepoFixture()
    const settingsPath = join(fixture.repoRoot, `.claude`, `settings.local.json`)
    await mkdir(join(fixture.repoRoot, `.claude`), { recursive: true })
    await writeFile(
      settingsPath,
      JSON.stringify({
        permissions: {
          allow: [`Read`],
        },
      }),
    )

    const runner = mockRunner({
      [`git -C ${fixture.repoRoot} rev-parse --show-toplevel`]: ok(`${fixture.repoRoot}\n`),
      [`git -C ${fixture.repoRoot} remote get-url origin`]: ok(
        `git@github.com:jasonkuhrt/flo.git\n`,
      ),
      [`git -C ${fixture.repoRoot} worktree list --porcelain`]: ok(
        mainWorktreeList(fixture.repoRoot),
      ),
    })

    const result = await installClaudeHooks({
      context: {
        cwd: fixture.repoRoot,
        env: fixture.env,
      },
      dependencies: { runner },
    })

    expect(result.settingsPath).toBe(settingsPath)
    const parsedSettings: unknown = JSON.parse(await Bun.file(settingsPath).text())
    expect(typeof parsedSettings).toBe(`object`)
    expect(parsedSettings).not.toBeNull()
    if (
      typeof parsedSettings !== `object` ||
      parsedSettings === null ||
      !(`permissions` in parsedSettings) ||
      !(`hooks` in parsedSettings)
    ) {
      throw new Error(`expected Claude settings object`)
    }

    expect(parsedSettings.permissions).toEqual({
      allow: [`Read`],
    })
    const hooks =
      typeof parsedSettings.hooks === `object` && parsedSettings.hooks !== null
        ? parsedSettings.hooks
        : {}
    expect(Object.keys(hooks)).toEqual([
      `Notification`,
      `SessionStart`,
      `PreCompact`,
      `SubagentStart`,
      `SubagentStop`,
    ])
  })

  it(`prunes orphaned Flo workspaces by identity`, async () => {
    const fixture = await makeRepoFixture()
    await saveState(fixture.env, {
      version: 1,
      workspaces: [
        {
          workspaceIdentity: `deadbeef0000`,
          workspaceTitle: `flo:flo@old`,
          projectName: `flo`,
          checkoutPath: fixture.featureWorktreePath,
          branch: `old`,
          isMain: false,
          lastOpenedAt: `2026-03-07T10:00:00.000Z`,
          lastAction: `start`,
        },
      ],
    })
    const calls: string[] = []
    const runner: CommandRunner = async (command, args = []) => {
      const key = [command, ...args].join(` `)
      calls.push(key)

      if (key === `git -C ${fixture.repoRoot} rev-parse --show-toplevel`)
        return ok(`${fixture.repoRoot}\n`)
      if (key === `git -C ${fixture.repoRoot} remote get-url origin`) {
        return ok(`git@github.com:jasonkuhrt/flo.git\n`)
      }
      if (key === `git -C ${fixture.repoRoot} worktree prune`) return ok()
      if (key === `git -C ${fixture.repoRoot} worktree list --porcelain`) {
        return ok(mainWorktreeList(fixture.repoRoot))
      }
      if (key === `cmux ping`) return ok()
      if (key === `cmux --json list-workspaces`) {
        return ok(JSON.stringify({ workspaces: [{ id: `workspace:9`, title: `orphan` }] }))
      }
      if (key === `cmux --json sidebar-state --workspace workspace:9`) {
        return ok(
          JSON.stringify({
            cwd: fixture.featureWorktreePath,
            statuses: [
              { key: `flo.identity`, value: `deadbeef0000` },
              { key: `flo.project`, value: `flo` },
              { key: `flo.kind`, value: `feature` },
            ],
          }),
        )
      }
      if (key === `cmux close-workspace --workspace workspace:9`) return ok()
      if (key === `zmx list --short`) return ok()

      return fail()
    }

    const result = await pruneFloState({
      context: {
        cwd: fixture.repoRoot,
        env: fixture.env,
      },
      dependencies: { runner },
    })

    expect(result.closedWorkspaces).toHaveLength(1)
    expect(result.closedWorkspaces[0]).toMatchObject({
      workspaceId: `workspace:9`,
      closedWorkspace: true,
    })
    expect(result.prunedRecents).toEqual([
      {
        workspaceIdentity: `deadbeef0000`,
        workspaceTitle: `flo:flo@old`,
        checkoutPath: fixture.featureWorktreePath,
      },
    ])
    expect((await loadState(fixture.env)).workspaces).toHaveLength(0)
    expect(calls).toContain(`git -C ${fixture.repoRoot} worktree prune`)
  })

  it(`returns typed checkout context for Claude-facing integrations`, async () => {
    const fixture = await makeRepoFixture()
    const runner = mockRunner({
      [`git -C ${fixture.featureWorktreePath} rev-parse --show-toplevel`]: {
        stdout: `${fixture.repoRoot}\n`,
      },
      [`git -C ${fixture.repoRoot} remote get-url origin`]: {
        stdout: `git@github.com:jasonkuhrt/flo.git\n`,
      },
      [`git -C ${fixture.repoRoot} worktree list --porcelain`]: {
        stdout: [
          `worktree ${fixture.repoRoot}`,
          `HEAD abc123`,
          `branch refs/heads/main`,
          ``,
          `worktree ${fixture.featureWorktreePath}`,
          `HEAD def456`,
          `branch refs/heads/issue/42-add-launcher`,
          ``,
        ].join(`\n`),
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

    const result = await getFloContext({
      context: {
        cwd: fixture.featureWorktreePath,
        env: fixture.env,
      },
      dependencies: { runner },
    })

    expect(result).toMatchObject({
      project: {
        name: `flo`,
      },
      checkout: {
        path: fixture.featureWorktreePath,
        branch: `issue/42-add-launcher`,
      },
      issue: {
        number: 42,
      },
    })
  })
})
