import { basename } from 'pathe'

import {
  clearCmuxStatus,
  getCmuxSidebarState,
  logToCmux,
  notifyCmux,
  probeCmux,
  setCmuxStatus,
  statusEntryValue,
} from '#lib/cmux'
import { loadConfig } from '#lib/config'
import { FloError } from '#lib/errors'
import { systemRunner, type CommandRunner } from '#lib/process'
import type {
  FloClaudeHookResult,
  FloCommandContext,
  FloUiLogResult,
  FloUiNotifyResult,
  FloUiSyncResult,
} from '#lib/types'

type ClaudeHookName =
  | `notification`
  | `session-start`
  | `pre-compact`
  | `subagent-start`
  | `subagent-stop`

export interface FloUiDependencies {
  runner?: CommandRunner
}

const defaultDependencies: Required<FloUiDependencies> = {
  runner: systemRunner,
}

const isRecord = (value: unknown): value is Record<string, unknown> =>
  typeof value === `object` && value !== null && !Array.isArray(value)

const parseHookInput = (text: string): Record<string, unknown> => {
  if (text.trim().length === 0) return {}

  try {
    const parsed: unknown = JSON.parse(text)
    return isRecord(parsed) ? parsed : {}
  } catch {
    throw new FloError(`CLAUDE_HOOK_INPUT_INVALID`, `Claude hook input must be valid JSON.`)
  }
}

const readString = (record: Record<string, unknown>, key: string): string | undefined => {
  const value = record[key]
  return typeof value === `string` ? value : undefined
}

const resolveUiContext = async (args: {
  context: FloCommandContext
  workspaceId?: string
  dependencies?: FloUiDependencies
}): Promise<{
  cmuxAvailable: boolean
  cmuxBin: string
  workspaceId: string | undefined
  runner: CommandRunner
}> => {
  const dependencies = { ...defaultDependencies, ...args.dependencies }
  const config = await loadConfig(args.context.env)
  const workspaceId = args.workspaceId ?? args.context.env[`CMUX_WORKSPACE_ID`] ?? undefined
  const cmuxAvailable =
    workspaceId !== undefined && (await probeCmux(dependencies.runner, config.runtime.cmuxBin))

  return {
    cmuxAvailable,
    cmuxBin: config.runtime.cmuxBin,
    workspaceId,
    runner: dependencies.runner,
  }
}

const syncStatus = async (args: {
  runner: CommandRunner
  cmuxBin: string
  workspaceId: string
  key: string
  value: string | null | undefined
}): Promise<void> => {
  if (args.value === undefined) {
    return
  }

  if (args.value === null) {
    await clearCmuxStatus({
      runner: args.runner,
      cmuxBin: args.cmuxBin,
      workspaceId: args.workspaceId,
      key: args.key,
    })
    return
  }

  await setCmuxStatus({
    runner: args.runner,
    cmuxBin: args.cmuxBin,
    workspaceId: args.workspaceId,
    key: args.key,
    value: args.value,
  })
}

export const syncFloUi = async (args: {
  context: FloCommandContext
  workspaceId?: string
  phase?: string | null
  agents?: number | null
  claude?: string | null
  dependencies?: FloUiDependencies
}): Promise<FloUiSyncResult> => {
  const runtime = await resolveUiContext(args)

  if (!runtime.cmuxAvailable || runtime.workspaceId === undefined) {
    return {
      cmuxAvailable: false,
      ...(args.phase === undefined || args.phase === null ? {} : { phase: args.phase }),
      ...(args.agents === undefined || args.agents === null ? {} : { agents: args.agents }),
      ...(args.claude === undefined || args.claude === null ? {} : { claude: args.claude }),
    }
  }

  await syncStatus({
    runner: runtime.runner,
    cmuxBin: runtime.cmuxBin,
    workspaceId: runtime.workspaceId,
    key: `flo.phase`,
    value: args.phase,
  })
  await syncStatus({
    runner: runtime.runner,
    cmuxBin: runtime.cmuxBin,
    workspaceId: runtime.workspaceId,
    key: `flo.agents`,
    value:
      args.agents === undefined ? undefined : args.agents === null ? null : String(args.agents),
  })
  await syncStatus({
    runner: runtime.runner,
    cmuxBin: runtime.cmuxBin,
    workspaceId: runtime.workspaceId,
    key: `flo.claude`,
    value: args.claude,
  })

  return {
    cmuxAvailable: true,
    workspaceId: runtime.workspaceId,
    ...(args.phase === undefined || args.phase === null ? {} : { phase: args.phase }),
    ...(args.agents === undefined || args.agents === null ? {} : { agents: args.agents }),
    ...(args.claude === undefined || args.claude === null ? {} : { claude: args.claude }),
  }
}

export const logFloUi = async (args: {
  context: FloCommandContext
  message: string
  level?: string
  source?: string
  workspaceId?: string
  dependencies?: FloUiDependencies
}): Promise<FloUiLogResult> => {
  const runtime = await resolveUiContext(args)
  const level = args.level ?? `info`
  const source = args.source ?? `flo`

  if (!runtime.cmuxAvailable || runtime.workspaceId === undefined) {
    return {
      cmuxAvailable: false,
      level,
      source,
      message: args.message,
    }
  }

  await logToCmux({
    runner: runtime.runner,
    cmuxBin: runtime.cmuxBin,
    workspaceId: runtime.workspaceId,
    level,
    source,
    message: args.message,
  })

  return {
    cmuxAvailable: true,
    workspaceId: runtime.workspaceId,
    level,
    source,
    message: args.message,
  }
}

export const notifyFloUi = async (args: {
  context: FloCommandContext
  title: string
  subtitle?: string
  body?: string
  workspaceId?: string
  dependencies?: FloUiDependencies
}): Promise<FloUiNotifyResult> => {
  const runtime = await resolveUiContext(args)

  if (!runtime.cmuxAvailable || runtime.workspaceId === undefined) {
    return {
      cmuxAvailable: false,
      title: args.title,
      ...(args.subtitle === undefined ? {} : { subtitle: args.subtitle }),
      ...(args.body === undefined ? {} : { body: args.body }),
    }
  }

  await notifyCmux({
    runner: runtime.runner,
    cmuxBin: runtime.cmuxBin,
    workspaceId: runtime.workspaceId,
    title: args.title,
    ...(args.subtitle === undefined ? {} : { subtitle: args.subtitle }),
    ...(args.body === undefined ? {} : { body: args.body }),
  })

  return {
    cmuxAvailable: true,
    workspaceId: runtime.workspaceId,
    title: args.title,
    ...(args.subtitle === undefined ? {} : { subtitle: args.subtitle }),
    ...(args.body === undefined ? {} : { body: args.body }),
  }
}

const currentAgentCount = async (args: {
  runner: CommandRunner
  cmuxBin: string
  workspaceId: string
}): Promise<number> => {
  const sidebarState = await getCmuxSidebarState(args)
  const value = statusEntryValue(sidebarState, `flo.agents`)
  const parsed = value === undefined ? Number.NaN : Number.parseInt(value, 10)
  return Number.isNaN(parsed) ? 0 : Math.max(parsed, 0)
}

export const handleClaudeHook = async (args: {
  context: FloCommandContext
  hook: ClaudeHookName
  input: string
  workspaceId?: string
  dependencies?: FloUiDependencies
}): Promise<FloClaudeHookResult> => {
  const payload = parseHookInput(args.input)
  const runtime = await resolveUiContext(args)

  if (!runtime.cmuxAvailable || runtime.workspaceId === undefined) {
    return {
      cmuxAvailable: false,
      handled: false,
      hook: args.hook,
      summary: `cmux workspace context was unavailable`,
    }
  }

  switch (args.hook) {
    case `notification`: {
      const notificationType = readString(payload, `notification_type`)
      if (
        notificationType !== `permission_prompt` &&
        notificationType !== `idle_prompt` &&
        notificationType !== `elicitation_dialog`
      ) {
        return {
          cmuxAvailable: true,
          workspaceId: runtime.workspaceId,
          handled: false,
          hook: args.hook,
          summary: `ignored Claude notification ${notificationType ?? `unknown`}`,
        }
      }

      const cwd = readString(payload, `cwd`)
      await notifyFloUi({
        context: args.context,
        workspaceId: runtime.workspaceId,
        title: readString(payload, `title`) ?? `Claude needs attention`,
        ...(cwd === undefined ? {} : { subtitle: basename(cwd) }),
        body: readString(payload, `message`) ?? notificationType,
        ...(args.dependencies === undefined ? {} : { dependencies: args.dependencies }),
      })

      return {
        cmuxAvailable: true,
        workspaceId: runtime.workspaceId,
        handled: true,
        hook: args.hook,
        summary: `forwarded Claude notification ${notificationType}`,
      }
    }
    case `session-start`: {
      const source = readString(payload, `source`) ?? `startup`
      await syncFloUi({
        context: args.context,
        workspaceId: runtime.workspaceId,
        phase: `ready`,
        ...(args.dependencies === undefined ? {} : { dependencies: args.dependencies }),
      })

      if (source === `compact`) {
        await logFloUi({
          context: args.context,
          workspaceId: runtime.workspaceId,
          source: `claude`,
          message: `Compaction complete`,
          ...(args.dependencies === undefined ? {} : { dependencies: args.dependencies }),
        })
      }

      return {
        cmuxAvailable: true,
        workspaceId: runtime.workspaceId,
        handled: true,
        hook: args.hook,
        summary: `synced session start state for ${source}`,
      }
    }
    case `pre-compact`: {
      const trigger = readString(payload, `trigger`) ?? `manual`
      await syncFloUi({
        context: args.context,
        workspaceId: runtime.workspaceId,
        phase: `compacting`,
        ...(args.dependencies === undefined ? {} : { dependencies: args.dependencies }),
      })
      await logFloUi({
        context: args.context,
        workspaceId: runtime.workspaceId,
        source: `claude`,
        message:
          trigger === `auto` ? `Automatic compaction starting` : `Manual compaction starting`,
        ...(args.dependencies === undefined ? {} : { dependencies: args.dependencies }),
      })

      if (trigger === `auto`) {
        await notifyFloUi({
          context: args.context,
          workspaceId: runtime.workspaceId,
          title: `Claude compacting automatically`,
          body: `The workspace context is being compacted.`,
          ...(args.dependencies === undefined ? {} : { dependencies: args.dependencies }),
        })
      }

      return {
        cmuxAvailable: true,
        workspaceId: runtime.workspaceId,
        handled: true,
        hook: args.hook,
        summary: `synced ${trigger} compaction`,
      }
    }
    case `subagent-start`: {
      const agentType = readString(payload, `agent_type`) ?? `subagent`
      const agents =
        (await currentAgentCount({
          runner: runtime.runner,
          cmuxBin: runtime.cmuxBin,
          workspaceId: runtime.workspaceId,
        })) + 1

      await syncFloUi({
        context: args.context,
        workspaceId: runtime.workspaceId,
        phase: `working`,
        agents,
        ...(args.dependencies === undefined ? {} : { dependencies: args.dependencies }),
      })
      await logFloUi({
        context: args.context,
        workspaceId: runtime.workspaceId,
        source: `claude`,
        message: `Subagent started: ${agentType}`,
        ...(args.dependencies === undefined ? {} : { dependencies: args.dependencies }),
      })

      return {
        cmuxAvailable: true,
        workspaceId: runtime.workspaceId,
        handled: true,
        hook: args.hook,
        summary: `subagent count is now ${agents}`,
      }
    }
    case `subagent-stop`: {
      const agentType = readString(payload, `agent_type`) ?? `subagent`
      const agents = Math.max(
        (await currentAgentCount({
          runner: runtime.runner,
          cmuxBin: runtime.cmuxBin,
          workspaceId: runtime.workspaceId,
        })) - 1,
        0,
      )

      await syncFloUi({
        context: args.context,
        workspaceId: runtime.workspaceId,
        phase: agents === 0 ? `ready` : `working`,
        agents,
        ...(args.dependencies === undefined ? {} : { dependencies: args.dependencies }),
      })
      await logFloUi({
        context: args.context,
        workspaceId: runtime.workspaceId,
        source: `claude`,
        message: `Subagent stopped: ${agentType}`,
        ...(args.dependencies === undefined ? {} : { dependencies: args.dependencies }),
      })

      return {
        cmuxAvailable: true,
        workspaceId: runtime.workspaceId,
        handled: true,
        hook: args.hook,
        summary: `subagent count is now ${agents}`,
      }
    }
  }
}
