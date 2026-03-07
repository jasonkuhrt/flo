import { describe, expect, it } from 'bun:test'

import { killZmxSession, listZmxSessions } from '#lib/zmx'
import type { CommandRunner } from '#lib/process'

const ok = (stdout = ``) => ({
  stdout,
  stderr: ``,
  exitCode: 0,
})

describe(`zmx`, () => {
  it(`lists active sessions`, async () => {
    const runner: CommandRunner = async () => ok(`editor\nclaude\n`)

    const result = await listZmxSessions(runner, `zmx`)
    expect(result).toEqual([`editor`, `claude`])
  })

  it(`kills a session only when it exists`, async () => {
    const calls: string[] = []
    const runner: CommandRunner = async (command, args = []) => {
      calls.push([command, ...args].join(` `))

      if (args[0] === `list`) {
        return ok(`editor\nclaude\n`)
      }

      return ok()
    }

    expect(await killZmxSession(runner, `zmx`, `claude`)).toBe(true)
    expect(await killZmxSession(runner, `zmx`, `missing`)).toBe(false)
    expect(calls).toContain(`zmx kill claude`)
    expect(calls).not.toContain(`zmx kill missing`)
  })
})
