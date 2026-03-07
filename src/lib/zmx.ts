import { FloError } from '#lib/errors'
import type { CommandRunner } from '#lib/process'

export const listZmxSessions = async (runner: CommandRunner, zmxBin: string): Promise<string[]> => {
  const result = await runner(zmxBin, [`list`, `--short`])

  if (result.exitCode !== 0) {
    throw new FloError(
      `ZMX_LIST_FAILED`,
      `Failed to list zmx sessions: ${result.stderr || result.stdout}`,
    )
  }

  return result.stdout
    .split(`\n`)
    .map((line) => line.trim())
    .filter(Boolean)
}

export const killZmxSession = async (
  runner: CommandRunner,
  zmxBin: string,
  sessionName: string,
): Promise<boolean> => {
  const sessions = await listZmxSessions(runner, zmxBin)
  if (!sessions.includes(sessionName)) {
    return false
  }

  const result = await runner(zmxBin, [`kill`, sessionName])

  if (result.exitCode !== 0) {
    throw new FloError(
      `ZMX_KILL_FAILED`,
      `Failed to kill zmx session ${sessionName}: ${result.stderr || result.stdout}`,
    )
  }

  return true
}
