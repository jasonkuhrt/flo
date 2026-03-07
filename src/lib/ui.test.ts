import { describe, expect, it } from 'bun:test'

import { handleClaudeHook, logFloUi, notifyFloUi, syncFloUi } from '#lib/ui'
import type { CommandRunner } from '#lib/process'

const ok = (stdout = ``) => ({
  stdout,
  stderr: ``,
  exitCode: 0,
})

const makeContext = () => ({
  cwd: `/repos/flo`,
  env: {
    FLO_CONFIG_PATH: `/tmp/missing-flo-config.json`,
    CMUX_WORKSPACE_ID: `workspace:2`,
  },
})

describe(`flo ui`, () => {
  it(`syncs status, logs, and notifications through cmux`, async () => {
    const calls: string[] = []
    const runner: CommandRunner = async (command, args = []) => {
      calls.push([command, ...args].join(` `))
      return ok()
    }

    const syncResult = await syncFloUi({
      context: makeContext(),
      phase: `working`,
      agents: 2,
      claude: `active`,
      dependencies: { runner },
    })
    const logResult = await logFloUi({
      context: makeContext(),
      source: `claude`,
      message: `Compaction complete`,
      dependencies: { runner },
    })
    const notifyResult = await notifyFloUi({
      context: makeContext(),
      title: `Claude needs attention`,
      body: `Permission prompt waiting`,
      dependencies: { runner },
    })

    expect(syncResult).toMatchObject({
      cmuxAvailable: true,
      workspaceId: `workspace:2`,
      phase: `working`,
      agents: 2,
      claude: `active`,
    })
    expect(logResult).toMatchObject({
      cmuxAvailable: true,
      source: `claude`,
      message: `Compaction complete`,
    })
    expect(notifyResult).toMatchObject({
      cmuxAvailable: true,
      title: `Claude needs attention`,
    })
    expect(calls).toContain(`cmux ping`)
    expect(calls).toContain(`cmux set-status flo.phase working --workspace workspace:2`)
    expect(calls).toContain(`cmux set-status flo.agents 2 --workspace workspace:2`)
    expect(calls).toContain(`cmux set-status flo.claude active --workspace workspace:2`)
    expect(calls).toContain(
      `cmux log --level info --source claude --workspace workspace:2 -- Compaction complete`,
    )
    expect(calls).toContain(
      `cmux notify --title Claude needs attention --body Permission prompt waiting --workspace workspace:2`,
    )
  })

  it(`maps Claude hooks into Flo UI actions`, async () => {
    const calls: string[] = []
    const runner: CommandRunner = async (command, args = []) => {
      const key = [command, ...args].join(` `)
      calls.push(key)

      if (key === `cmux --json sidebar-state --workspace workspace:2`) {
        return ok(
          JSON.stringify({ cwd: `/repos/flo`, statuses: [{ key: `flo.agents`, value: `1` }] }),
        )
      }

      return ok()
    }

    const compactResult = await handleClaudeHook({
      context: makeContext(),
      hook: `pre-compact`,
      input: JSON.stringify({ trigger: `auto` }),
      dependencies: { runner },
    })
    const subagentResult = await handleClaudeHook({
      context: makeContext(),
      hook: `subagent-start`,
      input: JSON.stringify({ agent_type: `reviewer` }),
      dependencies: { runner },
    })
    const notificationResult = await handleClaudeHook({
      context: makeContext(),
      hook: `notification`,
      input: JSON.stringify({
        notification_type: `permission_prompt`,
        title: `Claude Code`,
        message: `Needs approval`,
        cwd: `/repos/flo`,
      }),
      dependencies: { runner },
    })

    expect(compactResult).toMatchObject({
      handled: true,
      summary: `synced auto compaction`,
    })
    expect(subagentResult).toMatchObject({
      handled: true,
      summary: `subagent count is now 2`,
    })
    expect(notificationResult).toMatchObject({
      handled: true,
    })
    expect(calls).toContain(`cmux set-status flo.phase compacting --workspace workspace:2`)
    expect(calls).toContain(
      `cmux notify --title Claude compacting automatically --body The workspace context is being compacted. --workspace workspace:2`,
    )
    expect(calls).toContain(`cmux --json sidebar-state --workspace workspace:2`)
    expect(calls).toContain(`cmux set-status flo.agents 2 --workspace workspace:2`)
    expect(calls).toContain(
      `cmux log --level info --source claude --workspace workspace:2 -- Subagent started: reviewer`,
    )
    expect(calls).toContain(
      `cmux notify --title Claude Code --subtitle flo --body Needs approval --workspace workspace:2`,
    )
  })
})
