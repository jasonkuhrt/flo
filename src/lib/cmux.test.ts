import { describe, expect, it } from 'bun:test'

import {
  clearCmuxStatus,
  closeCmuxWorkspace,
  createCmuxWorkspace,
  currentCmuxWorkspace,
  getCmuxSidebarState,
  listCmuxWorkspaces,
  logToCmux,
  newCmuxPane,
  notifyCmux,
  probeCmux,
  renameCmuxWorkspace,
  selectLastCmuxPane,
  selectCmuxWorkspace,
  sendToCmuxWorkspace,
  setCmuxStatus,
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

  it(`reads sidebar metadata and manages status, panes, logs, notifications, and close`, async () => {
    const calls: string[] = []
    const runner: CommandRunner = async (command, args = []) => {
      const key = [command, ...args].join(` `)
      calls.push(key)

      if (key === `cmux --json sidebar-state --workspace workspace:2`) {
        return ok(
          JSON.stringify({
            cwd: `/repos/flo`,
            statuses: [
              { key: `flo.identity`, value: `abc123def456` },
              { key: `flo.project`, value: `flo` },
            ],
          }),
        )
      }

      return ok()
    }

    const sidebar = await getCmuxSidebarState({
      runner,
      cmuxBin: `cmux`,
      workspaceId: `workspace:2`,
    })

    expect(sidebar).toEqual({
      cwd: `/repos/flo`,
      statuses: [
        { key: `flo.identity`, value: `abc123def456` },
        { key: `flo.project`, value: `flo` },
      ],
    })

    await setCmuxStatus({
      runner,
      cmuxBin: `cmux`,
      workspaceId: `workspace:2`,
      key: `flo.phase`,
      value: `working`,
    })
    await clearCmuxStatus({
      runner,
      cmuxBin: `cmux`,
      workspaceId: `workspace:2`,
      key: `flo.phase`,
    })
    await newCmuxPane({
      runner,
      cmuxBin: `cmux`,
      workspaceId: `workspace:2`,
      direction: `right`,
    })
    await selectLastCmuxPane(runner, `cmux`, `workspace:2`)
    await notifyCmux({
      runner,
      cmuxBin: `cmux`,
      workspaceId: `workspace:2`,
      title: `Claude needs attention`,
      body: `Permission prompt waiting`,
    })
    await logToCmux({
      runner,
      cmuxBin: `cmux`,
      workspaceId: `workspace:2`,
      source: `claude`,
      message: `Subagent started`,
    })
    await closeCmuxWorkspace(runner, `cmux`, `workspace:2`)

    expect(calls).toContain(`cmux set-status flo.phase working --workspace workspace:2`)
    expect(calls).toContain(`cmux clear-status flo.phase --workspace workspace:2`)
    expect(calls).toContain(`cmux new-pane --workspace workspace:2 --direction right`)
    expect(calls).toContain(`cmux last-pane --workspace workspace:2`)
    expect(calls).toContain(
      `cmux notify --title Claude needs attention --body Permission prompt waiting --workspace workspace:2`,
    )
    expect(calls).toContain(`cmux log --source claude --workspace workspace:2 -- Subagent started`)
    expect(calls).toContain(`cmux close-workspace --workspace workspace:2`)
  })
})
