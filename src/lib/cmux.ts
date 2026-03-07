import { FloError } from '#lib/errors'
import type { CommandRunner } from '#lib/process'
import type { CmuxWorkspace } from '#lib/types'

const safeJsonParse = (text: string): unknown => {
  try {
    return JSON.parse(text) as unknown
  } catch {
    return null
  }
}

const isRecord = (value: unknown): value is Record<string, unknown> =>
  typeof value === `object` && value !== null && !Array.isArray(value)

const coerceWorkspace = (value: unknown): CmuxWorkspace | null => {
  if (!isRecord(value)) return null

  const id = value[`id`] ?? value[`ref`] ?? value[`workspaceId`] ?? value[`workspace`]
  const title = value[`title`] ?? value[`name`] ?? value[`label`]

  return typeof id === `string` && typeof title === `string`
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

  if (Array.isArray(value[`workspaces`])) {
    return value[`workspaces`].map(coerceWorkspace).filter((workspace) => workspace !== null)
  }

  const workspace = coerceWorkspace(value)
  return workspace === null ? [] : [workspace]
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

  if (result.exitCode !== 0) {
    throw new FloError(
      `CMUX_LIST_WORKSPACES_FAILED`,
      `Failed to list cmux workspaces: ${result.stderr || result.stdout}`,
    )
  }

  return extractWorkspaces(safeJsonParse(result.stdout))
}

export const currentCmuxWorkspace = async (
  runner: CommandRunner,
  cmuxBin: string,
): Promise<CmuxWorkspace> => {
  const result = await runner(cmuxBin, [`--json`, `current-workspace`])

  if (result.exitCode !== 0) {
    throw new FloError(
      `CMUX_CURRENT_WORKSPACE_FAILED`,
      `Failed to get current cmux workspace: ${result.stderr || result.stdout}`,
    )
  }

  const [workspace] = extractWorkspaces(safeJsonParse(result.stdout))
  if (workspace === undefined) {
    throw new FloError(
      `CMUX_CURRENT_WORKSPACE_INVALID`,
      `cmux returned an unreadable current workspace.`,
    )
  }

  return workspace
}

export const selectCmuxWorkspace = async (
  runner: CommandRunner,
  cmuxBin: string,
  workspaceId: string,
): Promise<void> => {
  const result = await runner(cmuxBin, [`select-workspace`, `--workspace`, workspaceId])
  if (result.exitCode !== 0) {
    throw new FloError(
      `CMUX_SELECT_WORKSPACE_FAILED`,
      `Failed to select cmux workspace ${workspaceId}: ${result.stderr || result.stdout}`,
    )
  }
}

export const createCmuxWorkspace = async (
  runner: CommandRunner,
  cmuxBin: string,
): Promise<CmuxWorkspace> => {
  const createResult = await runner(cmuxBin, [`new-workspace`])

  if (createResult.exitCode !== 0) {
    throw new FloError(
      `CMUX_NEW_WORKSPACE_FAILED`,
      `Failed to create a cmux workspace: ${createResult.stderr || createResult.stdout}`,
    )
  }

  return currentCmuxWorkspace(runner, cmuxBin)
}

export const renameCmuxWorkspace = async (
  runner: CommandRunner,
  cmuxBin: string,
  workspaceId: string,
  title: string,
): Promise<void> => {
  const result = await runner(cmuxBin, [`rename-workspace`, `--workspace`, workspaceId, title])

  if (result.exitCode !== 0) {
    throw new FloError(
      `CMUX_RENAME_WORKSPACE_FAILED`,
      `Failed to rename cmux workspace ${workspaceId}: ${result.stderr || result.stdout}`,
    )
  }
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

  if (result.exitCode !== 0) {
    throw new FloError(
      `CMUX_SEND_FAILED`,
      `Failed to send the bootstrap command to cmux workspace ${args.workspaceId}: ${result.stderr || result.stdout}`,
    )
  }
}
