import { describe, expect, it } from 'bun:test'

import { systemRunner } from '#lib/process'

describe(`systemRunner`, () => {
  it(`executes a command and captures stdout`, async () => {
    const result = await systemRunner(process.execPath, [`-e`, `console.log("ok")`])
    expect(result.exitCode).toBe(0)
    expect(result.stdout.trim()).toBe(`ok`)
  })
})
