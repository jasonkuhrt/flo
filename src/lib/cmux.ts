import { FloError } from '#lib/errors'
import type { CommandRunner } from '#lib/process'
import type { CmuxSidebarState, CmuxStatusEntry, CmuxWorkspace } from '#lib/types'

const safeJsonParse = (text: string): unknown => {
  try {
    return JSON.parse(text) as unknown
  } catch {
    return null
  }
}

const isRecord = (value: unknown): value is Record<string, unknown> =>
  typeof value === `object` && value !== null && !Array.isArray(value)

const readString = (value: Record<string, unknown>, keys: string[]): string | null => {
  for (const key of keys) {
    const candidate = value[key]
    if (typeof candidate === `string`) {
      return candidate
    }
  }

  return null
}

const coerceWorkspace = (value: unknown): CmuxWorkspace | null => {
  if (!isRecord(value)) return null

  const id = readString(value, [`id`, `ref`, `workspaceId`, `workspace`])
  const title = readString(value, [`title`, `name`, `label`])

  return id !== null && title !== null
    ? {
        id,
        title,
      }
    : null
}

const extractWorkspaces = (value: unknown): CmuxWorkspace[] => {
  if (Array.isArray(value)) {
    return value.map(coerceWorkspace).filter((workspace) => workspace !== null)
  }

  if (!isRecord(value)) {
    return []
  }

  for (const key of [`workspaces`, `items`]) {
    const collection = value[key]
    if (Array.isArray(collection)) {
      return collection.map(coerceWorkspace).filter((workspace) => workspace !== null)
    }
  }

  const workspace = coerceWorkspace(value)
  return workspace === null ? [] : [workspace]
}

const coerceStatusEntry = (value: unknown): CmuxStatusEntry | null => {
  if (!isRecord(value)) return null

  const key = readString(value, [`key`, `name`, `id`])
  const statusValue = readString(value, [`value`, `text`, `label`])
  const icon = readString(value, [`icon`])
  const color = readString(value, [`color`])

  if (key === null || statusValue === null) return null

  return {
    key,
    value: statusValue,
    ...(icon === null ? {} : { icon }),
    ...(color === null ? {} : { color }),
  }
}

const extractStatusEntries = (value: unknown): CmuxStatusEntry[] => {
  if (Array.isArray(value)) {
    return value.map(coerceStatusEntry).filter((entry) => entry !== null)
  }

  if (!isRecord(value)) {
    return []
  }

  for (const key of [`statuses`, `statusEntries`, `entries`, `items`]) {
    const collection = value[key]
    if (Array.isArray(collection)) {
      return collection.map(coerceStatusEntry).filter((entry) => entry !== null)
    }
  }

  const singleEntry = coerceStatusEntry(value)
  return singleEntry === null ? [] : [singleEntry]
}

const coerceSidebarState = (value: unknown): CmuxSidebarState => {
  if (!isRecord(value)) {
    return {
      cwd: null,
      statuses: [],
    }
  }

  const cwd = readString(value, [`cwd`, `currentWorkingDirectory`])

  for (const key of [`sidebar`, `workspace`]) {
    const nested = value[key]
    if (isRecord(nested)) {
      const nestedState = coerceSidebarState(nested)
      if (nestedState.cwd !== null || nestedState.statuses.length > 0) {
        return {
          cwd: cwd ?? nestedState.cwd,
          statuses: nestedState.statuses,
        }
      }
    }
  }

  return {
    cwd,
    statuses: extractStatusEntries(value),
  }
}

const statusFlagArgs = (workspaceId: string | undefined): string[] =>
  workspaceId === undefined ? [] : [`--workspace`, workspaceId]

const expectOk = (
  exitCode: number,
  stderr: string,
  stdout: string,
  code: string,
  message: string,
): void => {
  if (exitCode !== 0) {
    throw new FloError(code, `${message}: ${stderr || stdout}`)
  }
}

export const probeCmux = async (runner: CommandRunner, cmuxBin: string): Promise<boolean> => {
  const result = await runner(cmuxBin, [`ping`])
  return result.exitCode === 0
}

export const listCmuxWorkspaces = async (
  runner: CommandRunner,
  cmuxBin: string,
): Promise<CmuxWorkspace[]> => {
  const result = await runner(cmuxBin, [`--json`, `list-workspaces`])

  expectOk(
    result.exitCode,
    result.stderr,
    result.stdout,
    `CMUX_LIST_WORKSPACES_FAILED`,
    `Failed to list cmux workspaces`,
  )

  return extractWorkspaces(safeJsonParse(result.stdout))
}

export const currentCmuxWorkspace = async (
  runner: CommandRunner,
  cmuxBin: string,
): Promise<CmuxWorkspace> => {
  const result = await runner(cmuxBin, [`--json`, `current-workspace`])

  expectOk(
    result.exitCode,
    result.stderr,
    result.stdout,
    `CMUX_CURRENT_WORKSPACE_FAILED`,
    `Failed to get current cmux workspace`,
  )

  const [workspace] = extractWorkspaces(safeJsonParse(result.stdout))
  if (workspace === undefined) {
    throw new FloError(
      `CMUX_CURRENT_WORKSPACE_INVALID`,
      `cmux returned an unreadable current workspace.`,
    )
  }

  return workspace
}

export const getCmuxSidebarState = async (args: {
  runner: CommandRunner
  cmuxBin: string
  workspaceId: string
}): Promise<CmuxSidebarState> => {
  const result = await args.runner(args.cmuxBin, [
    `--json`,
    `sidebar-state`,
    `--workspace`,
    args.workspaceId,
  ])

  expectOk(
    result.exitCode,
    result.stderr,
    result.stdout,
    `CMUX_SIDEBAR_STATE_FAILED`,
    `Failed to read cmux sidebar state for ${args.workspaceId}`,
  )

  return coerceSidebarState(safeJsonParse(result.stdout))
}

export const selectCmuxWorkspace = async (
  runner: CommandRunner,
  cmuxBin: string,
  workspaceId: string,
): Promise<void> => {
  const result = await runner(cmuxBin, [`select-workspace`, `--workspace`, workspaceId])

  expectOk(
    result.exitCode,
    result.stderr,
    result.stdout,
    `CMUX_SELECT_WORKSPACE_FAILED`,
    `Failed to select cmux workspace ${workspaceId}`,
  )
}

export const createCmuxWorkspace = async (
  runner: CommandRunner,
  cmuxBin: string,
): Promise<CmuxWorkspace> => {
  const createResult = await runner(cmuxBin, [`new-workspace`])

  expectOk(
    createResult.exitCode,
    createResult.stderr,
    createResult.stdout,
    `CMUX_NEW_WORKSPACE_FAILED`,
    `Failed to create a cmux workspace`,
  )

  return currentCmuxWorkspace(runner, cmuxBin)
}

export const renameCmuxWorkspace = async (
  runner: CommandRunner,
  cmuxBin: string,
  workspaceId: string,
  title: string,
): Promise<void> => {
  const result = await runner(cmuxBin, [`rename-workspace`, `--workspace`, workspaceId, title])

  expectOk(
    result.exitCode,
    result.stderr,
    result.stdout,
    `CMUX_RENAME_WORKSPACE_FAILED`,
    `Failed to rename cmux workspace ${workspaceId}`,
  )
}

export const closeCmuxWorkspace = async (
  runner: CommandRunner,
  cmuxBin: string,
  workspaceId: string,
): Promise<void> => {
  const result = await runner(cmuxBin, [`close-workspace`, `--workspace`, workspaceId])

  expectOk(
    result.exitCode,
    result.stderr,
    result.stdout,
    `CMUX_CLOSE_WORKSPACE_FAILED`,
    `Failed to close cmux workspace ${workspaceId}`,
  )
}

export const setCmuxStatus = async (args: {
  runner: CommandRunner
  cmuxBin: string
  key: string
  value: string
  workspaceId?: string
  icon?: string
  color?: string
}): Promise<void> => {
  const result = await args.runner(args.cmuxBin, [
    `set-status`,
    args.key,
    args.value,
    ...statusFlagArgs(args.workspaceId),
    ...(args.icon === undefined ? [] : [`--icon`, args.icon]),
    ...(args.color === undefined ? [] : [`--color`, args.color]),
  ])

  expectOk(
    result.exitCode,
    result.stderr,
    result.stdout,
    `CMUX_SET_STATUS_FAILED`,
    `Failed to set cmux status ${args.key}`,
  )
}

export const clearCmuxStatus = async (args: {
  runner: CommandRunner
  cmuxBin: string
  key: string
  workspaceId?: string
}): Promise<void> => {
  const result = await args.runner(args.cmuxBin, [
    `clear-status`,
    args.key,
    ...statusFlagArgs(args.workspaceId),
  ])

  expectOk(
    result.exitCode,
    result.stderr,
    result.stdout,
    `CMUX_CLEAR_STATUS_FAILED`,
    `Failed to clear cmux status ${args.key}`,
  )
}

export const newCmuxPane = async (args: {
  runner: CommandRunner
  cmuxBin: string
  workspaceId: string
  direction?: `left` | `right` | `up` | `down`
}): Promise<void> => {
  const result = await args.runner(args.cmuxBin, [
    `new-pane`,
    `--workspace`,
    args.workspaceId,
    `--direction`,
    args.direction ?? `right`,
  ])

  expectOk(
    result.exitCode,
    result.stderr,
    result.stdout,
    `CMUX_NEW_PANE_FAILED`,
    `Failed to create a new cmux pane in ${args.workspaceId}`,
  )
}

export const selectLastCmuxPane = async (
  runner: CommandRunner,
  cmuxBin: string,
  workspaceId: string,
): Promise<void> => {
  const result = await runner(cmuxBin, [`last-pane`, `--workspace`, workspaceId])

  expectOk(
    result.exitCode,
    result.stderr,
    result.stdout,
    `CMUX_LAST_PANE_FAILED`,
    `Failed to focus the previous pane in ${workspaceId}`,
  )
}

export const sendToCmuxWorkspace = async (args: {
  runner: CommandRunner
  cmuxBin: string
  workspaceId: string
  text: string
}): Promise<void> => {
  const result = await args.runner(args.cmuxBin, [
    `send`,
    `--workspace`,
    args.workspaceId,
    `${args.text}\n`,
  ])

  expectOk(
    result.exitCode,
    result.stderr,
    result.stdout,
    `CMUX_SEND_FAILED`,
    `Failed to send text to cmux workspace ${args.workspaceId}`,
  )
}

export const notifyCmux = async (args: {
  runner: CommandRunner
  cmuxBin: string
  title: string
  subtitle?: string
  body?: string
  workspaceId?: string
}): Promise<void> => {
  const result = await args.runner(args.cmuxBin, [
    `notify`,
    `--title`,
    args.title,
    ...(args.subtitle === undefined ? [] : [`--subtitle`, args.subtitle]),
    ...(args.body === undefined ? [] : [`--body`, args.body]),
    ...statusFlagArgs(args.workspaceId),
  ])

  expectOk(
    result.exitCode,
    result.stderr,
    result.stdout,
    `CMUX_NOTIFY_FAILED`,
    `Failed to send a cmux notification`,
  )
}

export const logToCmux = async (args: {
  runner: CommandRunner
  cmuxBin: string
  message: string
  level?: string
  source?: string
  workspaceId?: string
}): Promise<void> => {
  const result = await args.runner(args.cmuxBin, [
    `log`,
    ...(args.level === undefined ? [] : [`--level`, args.level]),
    ...(args.source === undefined ? [] : [`--source`, args.source]),
    ...statusFlagArgs(args.workspaceId),
    `--`,
    args.message,
  ])

  expectOk(
    result.exitCode,
    result.stderr,
    result.stdout,
    `CMUX_LOG_FAILED`,
    `Failed to write a cmux log entry`,
  )
}

export const statusEntryValue = (sidebarState: CmuxSidebarState, key: string): string | undefined =>
  sidebarState.statuses.find((entry) => entry.key === key)?.value
