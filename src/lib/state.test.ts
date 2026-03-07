import { mkdtemp } from 'node:fs/promises'
import { join } from 'node:path'
import { tmpdir } from 'node:os'

import { afterEach, describe, expect, it } from 'bun:test'

import {
  getDefaultStatePath,
  loadState,
  pruneWorkspaceState,
  touchWorkspaceState,
} from '#lib/state'
import type { OpenTarget } from '#lib/types'

const tempPaths: string[] = []

afterEach(async () => {
  await Promise.all(
    tempPaths.splice(0).map(async (path) => {
      await Bun.$`rm -rf ${path}`.quiet()
    }),
  )
})

const makeEnv = async (): Promise<NodeJS.ProcessEnv> => {
  const path = await mkdtemp(join(tmpdir(), `flo-state-`))
  tempPaths.push(path)

  return {
    HOME: path,
    XDG_STATE_HOME: join(path, `.state`),
  }
}

const makeTarget = (path: string, identity: string, actionTitle: string): OpenTarget => ({
  project: {
    name: `flo`,
    path,
    aliases: [],
    defaultSource: `github`,
    githubRepo: `jasonkuhrt/flo`,
    worktreeRoot: join(path, `.flo-checkouts`),
  },
  checkout: {
    path,
    branch: null,
    headSha: null,
    isMain: true,
  },
  workspaceTitle: actionTitle,
  workspaceMetadata: {
    identity,
    project: `flo`,
    kind: `main`,
  },
  claudePaneDirection: `right`,
  editorSessionName: `flo-editor`,
  claudeSessionName: `flo-claude`,
  editorBootstrapCommand: `zmx attach editor`,
  claudeBootstrapCommand: `zmx attach claude`,
})

describe(`flo state`, () => {
  it(`defaults to an empty state file`, async () => {
    const env = await makeEnv()
    expect(getDefaultStatePath(env)).toBe(join(env[`XDG_STATE_HOME`] ?? ``, `flo`, `state.json`))
    const state = await loadState(env)
    expect(state).toEqual({
      version: 1,
      workspaces: [],
    })
  })

  it(`records and replaces workspace activity by identity`, async () => {
    const env = await makeEnv()
    const target = makeTarget(join(env[`HOME`] ?? ``, `flo`), `abc123`, `flo:flo`)

    await touchWorkspaceState({
      env,
      target,
      action: `open`,
    })
    await touchWorkspaceState({
      env,
      target: {
        ...target,
        workspaceTitle: `flo:flo-renamed`,
      },
      action: `start`,
    })

    const state = await loadState(env)
    expect(state.workspaces).toHaveLength(1)
    expect(state.workspaces[0]).toMatchObject({
      workspaceIdentity: `abc123`,
      workspaceTitle: `flo:flo-renamed`,
      lastAction: `start`,
    })
  })

  it(`prunes stale workspace state`, async () => {
    const env = await makeEnv()
    const target = makeTarget(join(env[`HOME`] ?? ``, `flo`), `abc123`, `flo:flo`)

    await touchWorkspaceState({
      env,
      target,
      action: `open`,
    })
    await touchWorkspaceState({
      env,
      target: {
        ...target,
        checkout: {
          ...target.checkout,
          path: join(env[`HOME`] ?? ``, `flo`, `feat-auth`),
          branch: `feat/auth`,
          isMain: false,
        },
        workspaceMetadata: {
          ...target.workspaceMetadata,
          identity: `feature123`,
          kind: `feature`,
        },
        workspaceTitle: `flo:flo@feat/auth`,
      },
      action: `start`,
    })

    const stale = await pruneWorkspaceState({
      env,
      activeWorkspaceIdentities: new Set([`abc123`]),
      activeCheckoutPaths: new Set([join(env[`HOME`] ?? ``, `flo`)]),
    })

    expect(stale).toHaveLength(1)
    expect(stale[0]?.workspaceIdentity).toBe(`feature123`)

    const state = await loadState(env)
    expect(state.workspaces).toHaveLength(1)
    expect(state.workspaces[0]?.workspaceIdentity).toBe(`abc123`)
  })
})
