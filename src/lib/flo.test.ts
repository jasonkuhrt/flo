import { describe, expect, it } from 'bun:test'
import { formatFloContextEnv, normalizeSelector } from '#lib/flo'

describe('normalizeSelector', () => {
  it('trims surrounding whitespace', () => {
    expect(normalizeSelector('  gh:123  ')).toEqual({
      raw: '  gh:123  ',
      value: 'gh:123',
    })
  })
})

describe(`formatFloContextEnv`, () => {
  it(`renders a shell-safe export block`, () => {
    expect(
      formatFloContextEnv({
        project: {
          name: `flo`,
          path: `/tmp/flo`,
          aliases: [],
          worktreeRoot: `/tmp/.flo-checkouts/flo`,
          workspaceProfiles: {},
        },
        checkout: {
          path: `/tmp/flo`,
          branch: `issue/42-add-launcher`,
          headSha: `abc123`,
          isMain: false,
        },
        workspaceTitle: `flo:flo@issue/42-add-launcher`,
        workspaceMetadata: {
          identity: `deadbeef0000`,
          project: `flo`,
          kind: `feature`,
        },
        workspaceLayout: {
          splitDirection: `right`,
          secondaryPane: `claude`,
          focus: `editor`,
        },
        editorSessionName: `editor`,
        claudeSessionName: `claude`,
        editorBootstrapCommand: `nvim`,
        claudeBootstrapCommand: `claude`,
        issue: {
          source: `github`,
          number: 42,
          title: `Add launcher`,
          url: `https://github.com/jasonkuhrt/flo/issues/42`,
          state: `OPEN`,
          repo: `jasonkuhrt/flo`,
        },
      }),
    ).toContain(`export FLO_ISSUE_NUMBER='42'`)
  })

  it(`renders source-specific exports for Linear work items`, () => {
    expect(
      formatFloContextEnv({
        project: {
          name: `flo`,
          path: `/tmp/flo`,
          aliases: [],
          worktreeRoot: `/tmp/.flo-checkouts/flo`,
          workspaceProfiles: {},
        },
        checkout: {
          path: `/tmp/flo`,
          branch: `issue/HEA-4225-redo-aborted`,
          headSha: `abc123`,
          isMain: false,
        },
        workspaceTitle: `flo:flo@issue/HEA-4225-redo-aborted`,
        workspaceMetadata: {
          identity: `deadbeef0000`,
          project: `flo`,
          kind: `feature`,
        },
        workspaceLayout: {
          splitDirection: `right`,
          secondaryPane: `claude`,
          focus: `editor`,
        },
        editorSessionName: `editor`,
        claudeSessionName: `claude`,
        editorBootstrapCommand: `nvim`,
        claudeBootstrapCommand: `claude`,
        issue: {
          source: `linear`,
          key: `HEA-4225`,
          title: `Redo aborted`,
          url: `https://linear.app/heartbeat-chat/issue/HEA-4225/redo-aborted`,
          state: `Todo`,
          teamKey: `HEA`,
        },
      }),
    ).toContain(`export FLO_ISSUE_KEY='HEA-4225'`)
  })
})
