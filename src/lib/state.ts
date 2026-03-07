import { dirname, resolve } from 'pathe'

import { FloError } from '#lib/errors'
import {
  makeDirectoryRecursive,
  pathExists,
  readFileString,
  writeFileString,
} from '#lib/filesystem'
import type { FloState, FloWorkspaceStateRecord, OpenTarget } from '#lib/types'

const emptyState = (): FloState => ({
  version: 1,
  workspaces: [],
})

const isRecord = (value: unknown): value is Record<string, unknown> =>
  typeof value === `object` && value !== null && !Array.isArray(value)

const isWorkspaceRecord = (value: unknown): value is FloWorkspaceStateRecord =>
  isRecord(value) &&
  typeof value[`workspaceIdentity`] === `string` &&
  typeof value[`workspaceTitle`] === `string` &&
  typeof value[`projectName`] === `string` &&
  typeof value[`checkoutPath`] === `string` &&
  (typeof value[`branch`] === `string` || value[`branch`] === null) &&
  typeof value[`isMain`] === `boolean` &&
  typeof value[`lastOpenedAt`] === `string` &&
  (value[`lastAction`] === `open` || value[`lastAction`] === `start`)

const parseState = (text: string, statePath: string): FloState => {
  const parsed: unknown = JSON.parse(text)
  if (!isRecord(parsed) || parsed[`version`] !== 1 || !Array.isArray(parsed[`workspaces`])) {
    throw new FloError(
      `STATE_INVALID`,
      `Flo state at ${statePath} must be a versioned JSON object.`,
    )
  }

  const workspaces = parsed[`workspaces`]
  if (!workspaces.every(isWorkspaceRecord)) {
    throw new FloError(`STATE_INVALID`, `Flo state at ${statePath} has an invalid workspace entry.`)
  }

  return {
    version: 1,
    workspaces,
  }
}

export const getDefaultStatePath = (env: NodeJS.ProcessEnv): string => {
  const homeDirectory = env[`HOME`] ?? process.env[`HOME`] ?? `~`
  const xdgStateHome = env[`XDG_STATE_HOME`] ?? `${homeDirectory}/.local/state`
  return resolve(xdgStateHome, `flo`, `state.json`)
}

export const loadState = async (env: NodeJS.ProcessEnv): Promise<FloState> => {
  const statePath = getDefaultStatePath(env)
  if (!(await pathExists(statePath))) {
    return emptyState()
  }

  try {
    return parseState(await readFileString(statePath), statePath)
  } catch (error) {
    throw new FloError(
      `STATE_INVALID`,
      `Failed to read Flo state at ${statePath}: ${String(error)}`,
    )
  }
}

export const saveState = async (env: NodeJS.ProcessEnv, state: FloState): Promise<void> => {
  const statePath = getDefaultStatePath(env)
  await makeDirectoryRecursive(dirname(statePath))
  await writeFileString(statePath, `${JSON.stringify(state, null, 2)}\n`)
}

export const touchWorkspaceState = async (args: {
  env: NodeJS.ProcessEnv
  target: OpenTarget
  action: `open` | `start`
}): Promise<void> => {
  const state = await loadState(args.env)
  const nextRecord: FloWorkspaceStateRecord = {
    workspaceIdentity: args.target.workspaceMetadata.identity,
    workspaceTitle: args.target.workspaceTitle,
    projectName: args.target.project.name,
    checkoutPath: args.target.checkout.path,
    branch: args.target.checkout.branch,
    isMain: args.target.checkout.isMain,
    lastOpenedAt: new Date().toISOString(),
    lastAction: args.action,
  }

  const workspaces = state.workspaces.filter(
    (record) => record.workspaceIdentity !== nextRecord.workspaceIdentity,
  )
  workspaces.push(nextRecord)
  workspaces.sort((left, right) => right.lastOpenedAt.localeCompare(left.lastOpenedAt))

  await saveState(args.env, {
    version: 1,
    workspaces,
  })
}

export const pruneWorkspaceState = async (args: {
  env: NodeJS.ProcessEnv
  activeWorkspaceIdentities: ReadonlySet<string>
  activeCheckoutPaths: ReadonlySet<string>
  dryRun?: boolean
}): Promise<FloWorkspaceStateRecord[]> => {
  const state = await loadState(args.env)
  const staleRecords = state.workspaces.filter(
    (record) =>
      !args.activeWorkspaceIdentities.has(record.workspaceIdentity) &&
      !args.activeCheckoutPaths.has(record.checkoutPath),
  )

  if (!args.dryRun && staleRecords.length > 0) {
    await saveState(args.env, {
      version: 1,
      workspaces: state.workspaces.filter((record) => !staleRecords.includes(record)),
    })
  }

  return staleRecords
}
