import { describe, expect, it } from 'bun:test'
import { mkdtemp } from 'node:fs/promises'
import { tmpdir } from 'node:os'
import { join } from 'pathe'

import { systemRunner, systemRunnerUntil } from '#lib/process'

describe(`systemRunner`, () => {
  it(`executes a command and captures stdout`, async () => {
    const result = await systemRunner(process.execPath, [`-e`, `console.log("ok")`])
    expect(result.exitCode).toBe(0)
    expect(result.stdout.trim()).toBe(`ok`)
  })

  it(`supports working directories and stdin input`, async () => {
    const cwd = await mkdtemp(join(tmpdir(), `flo-process-`))
    const result = await systemRunner(`zsh`, [`-lc`, `printf '%s\n' "$PWD"; cat`], {
      cwd,
      input: `hello from stdin`,
    })

    expect(result.exitCode).toBe(0)
    expect(result.stdout).toContain(cwd)
    expect(result.stdout).toContain(`hello from stdin`)
  })

  it(`maps command startup failures into a shell-like error result`, async () => {
    const result = await systemRunner(`definitely-not-a-real-command`)

    expect(result.exitCode).toBe(127)
    expect(result.stderr.length).toBeGreaterThan(0)
  })

  it(`stops a long-running command once the ready output appears`, async () => {
    const result = await systemRunnerUntil(
      `zsh`,
      [`-lc`, `printf 'booting\\n'; sleep 0.1; printf 'ready\\n'; sleep 30`],
      {
        readyWhen: `ready`,
        terminateSignal: `SIGINT`,
      },
    )

    expect(result.matched).toBe(true)
    expect(result.exitCode).toBe(0)
    expect(result.stdout).toContain(`ready`)
  })

  it(`returns the actual exit code when readiness is never reached`, async () => {
    const result = await systemRunnerUntil(`zsh`, [`-lc`, `printf 'nope\\n'; exit 7`], {
      readyWhen: `ready`,
    })

    expect(result.matched).toBe(false)
    expect(result.exitCode).toBe(7)
    expect(result.stdout).toContain(`nope`)
  })

  it(`supports regex readiness matchers with cwd and stdin`, async () => {
    const cwd = await mkdtemp(join(tmpdir(), `flo-process-until-`))
    const result = await systemRunnerUntil(`zsh`, [`-lc`, `printf '%s\n' "$PWD"; cat; sleep 30`], {
      cwd,
      input: `regex-ready`,
      readyWhen: /regex-ready/u,
    })

    expect(result.matched).toBe(true)
    expect(result.exitCode).toBe(0)
    expect(result.stdout).toContain(cwd)
    expect(result.stdout).toContain(`regex-ready`)
  })

  it(`supports function readiness matchers`, async () => {
    const result = await systemRunnerUntil(
      `zsh`,
      [`-lc`, `printf 'phase one\\n'; sleep 0.1; printf 'phase two\\n'; sleep 30`],
      {
        readyWhen: (output) => output.includes(`phase two`),
      },
    )

    expect(result.matched).toBe(true)
    expect(result.exitCode).toBe(0)
    expect(result.stdout).toContain(`phase two`)
  })

  it(`reports missing readiness options immediately`, async () => {
    const result = await systemRunnerUntil(`zsh`, [`-lc`, `printf 'ignored\\n'`])

    expect(result).toEqual({
      stdout: ``,
      stderr: `Missing readyWhen option`,
      exitCode: 127,
      matched: false,
    })
  })

  it(`maps startup failures for readiness commands into an error result`, async () => {
    const result = await systemRunnerUntil(`definitely-not-a-real-command`, [], {
      readyWhen: `ready`,
    })

    expect(result.exitCode).toBe(127)
    expect(result.matched).toBe(false)
    expect(result.stderr.length).toBeGreaterThan(0)
  })
})
