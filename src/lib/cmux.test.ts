import { describe, expect, it } from 'bun:test'

import {
  createCmuxWorkspace,
  currentCmuxWorkspace,
  listCmuxWorkspaces,
  probeCmux,
  renameCmuxWorkspace,
  selectCmuxWorkspace,
  sendToCmuxWorkspace,
} from '#lib/cmux'
import type { CommandRunner } from '#lib/process'

const ok = (stdout = ``) => ({
  stdout,
  stderr: ``,
  exitCode: 0,
})

describe(`cmux`, () => {
  it(`detects cmux availability`, async () => {
    const runner: CommandRunner = async () => ok()
    const result = await probeCmux(runner, `cmux`)
    expect(result).toBe(true)
  })

  it(`parses workspace lists`, async () => {
    const runner: CommandRunner = async () =>
      ok(JSON.stringify({ workspaces: [{ id: `workspace:1`, title: `flo:dotfiles` }] }))

    const result = await listCmuxWorkspaces(runner, `cmux`)
    expect(result).toEqual([
      {
        id: `workspace:1`,
        title: `flo:dotfiles`,
      },
    ])
  })

  it(`reads the current workspace`, async () => {
    const runner: CommandRunner = async () =>
      ok(JSON.stringify({ id: `workspace:2`, title: `flo:flo` }))

    const result = await currentCmuxWorkspace(runner, `cmux`)
    expect(result).toEqual({
      id: `workspace:2`,
      title: `flo:flo`,
    })
  })

  it(`creates and renames a workspace`, async () => {
    const calls: string[] = []
    const runner: CommandRunner = async (command, args = []) => {
      calls.push([command, ...args].join(` `))

      if (args[0] === `new-workspace`) return ok()
      if (args[1] === `current-workspace`) {
        return ok(JSON.stringify({ id: `workspace:9`, title: `untitled` }))
      }

      return ok()
    }

    const workspace = await createCmuxWorkspace(runner, `cmux`)
    expect(workspace).toEqual({
      id: `workspace:9`,
      title: `untitled`,
    })
    await renameCmuxWorkspace(runner, `cmux`, `workspace:9`, `flo:dotfiles`)
    await selectCmuxWorkspace(runner, `cmux`, `workspace:9`)
    await sendToCmuxWorkspace({
      runner,
      cmuxBin: `cmux`,
      workspaceId: `workspace:9`,
      text: `echo hi`,
    })

    expect(calls).toContain(`cmux new-workspace`)
    expect(calls).toContain(`cmux --json current-workspace`)
    expect(calls).toContain(`cmux rename-workspace --workspace workspace:9 flo:dotfiles`)
    expect(calls).toContain(`cmux select-workspace --workspace workspace:9`)
  })
})
