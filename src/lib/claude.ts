import { join } from 'pathe'

import { FloError } from '#lib/errors'
import {
  makeDirectoryRecursive,
  pathExists,
  readFileString,
  writeFileString,
} from '#lib/filesystem'
import { getFloContext, type FloRuntimeDependencies } from '#lib/flo'
import type { FloClaudeHookInstallResult, FloCommandContext } from '#lib/types'

const isRecord = (value: unknown): value is Record<string, unknown> =>
  typeof value === `object` && value !== null && !Array.isArray(value)

const parseSettings = (text: string, path: string): Record<string, unknown> => {
  const parsed: unknown = JSON.parse(text)
  if (!isRecord(parsed)) {
    throw new FloError(
      `CLAUDE_SETTINGS_INVALID`,
      `Claude settings at ${path} must be a JSON object.`,
    )
  }

  return parsed
}

export const installClaudeHooks = async (args: {
  context: FloCommandContext
  dependencies?: FloRuntimeDependencies
}): Promise<FloClaudeHookInstallResult> => {
  const floContext = await getFloContext(args)
  const settingsPath = join(floContext.checkout.path, `.claude`, `settings.local.json`)
  const currentSettings = !(await pathExists(settingsPath))
    ? {}
    : parseSettings(await readFileString(settingsPath), settingsPath)

  const hookEvents = [
    `Notification`,
    `SessionStart`,
    `PreCompact`,
    `SubagentStart`,
    `SubagentStop`,
  ] as const
  const commands = {
    Notification: `flo ui claude-hook notification`,
    SessionStart: `flo ui claude-hook session-start`,
    PreCompact: `flo ui claude-hook pre-compact`,
    SubagentStart: `flo ui claude-hook subagent-start`,
    SubagentStop: `flo ui claude-hook subagent-stop`,
  } as const

  const hooks = isRecord(currentSettings[`hooks`]) ? currentSettings[`hooks`] : {}
  const nextHooks: Record<string, unknown> = {
    ...hooks,
  }

  for (const hookEvent of hookEvents) {
    nextHooks[hookEvent] = [
      {
        matcher: `*`,
        hooks: [
          {
            type: `command`,
            command: commands[hookEvent],
          },
        ],
      },
    ]
  }

  const nextSettings = {
    ...currentSettings,
    hooks: nextHooks,
  }

  await makeDirectoryRecursive(join(floContext.checkout.path, `.claude`))
  await writeFileString(settingsPath, `${JSON.stringify(nextSettings, null, 2)}\n`)

  return {
    settingsPath,
    checkoutPath: floContext.checkout.path,
    wroteSettings: true,
    hookEvents: [...hookEvents],
  }
}
