import { describe, expect, it } from 'bun:test'

import {
  buildClaudeBootstrapCommand,
  buildEditorBootstrapCommand,
  isCheckoutDirty,
  issueBranchName,
  parseGitHubRepo,
  parseWorktreeList,
  planWorktreePath,
  pruneWorktrees,
  removeWorktree,
} from '#lib/git'
import type { CommandRunner } from '#lib/process'

describe(`parseGitHubRepo`, () => {
  it(`parses ssh remotes`, () => {
    expect(parseGitHubRepo(`git@github.com:jasonkuhrt/flo.git`)).toBe(`jasonkuhrt/flo`)
  })

  it(`parses https remotes`, () => {
    expect(parseGitHubRepo(`https://github.com/jasonkuhrt/flo.git`)).toBe(`jasonkuhrt/flo`)
  })
})

describe(`parseWorktreeList`, () => {
  it(`parses main and feature worktrees`, () => {
    const output = [
      `worktree /repos/flo`,
      `HEAD abc123`,
      `branch refs/heads/main`,
      ``,
      `worktree /repos/.flo-checkouts/flo/issue/123-test`,
      `HEAD def456`,
      `branch refs/heads/issue/123-test`,
      ``,
    ].join(`\n`)

    expect(parseWorktreeList(output, `/repos/flo`)).toEqual([
      {
        path: `/repos/flo`,
        branch: `main`,
        headSha: `abc123`,
        isMain: true,
      },
      {
        path: `/repos/.flo-checkouts/flo/issue/123-test`,
        branch: `issue/123-test`,
        headSha: `def456`,
        isMain: false,
      },
    ])
  })
})

describe(`issueBranchName`, () => {
  it(`builds a slugged issue branch`, () => {
    expect(
      issueBranchName({
        source: `github`,
        number: 42,
        title: `Add cmux launcher support`,
        url: `https://github.com/jasonkuhrt/flo/issues/42`,
        state: `OPEN`,
        repo: `jasonkuhrt/flo`,
      }),
    ).toBe(`issue/42-add-cmux-launcher-support`)
  })
})

describe(`planWorktreePath`, () => {
  it(`maps branch paths into nested checkout paths`, () => {
    expect(planWorktreePath(`/repos/.flo-checkouts/flo`, `issue/42-launcher`)).toBe(
      `/repos/.flo-checkouts/flo/issue/42-launcher`,
    )
  })
})

describe(`buildEditorBootstrapCommand`, () => {
  it(`builds a zmx attach command rooted in the checkout`, () => {
    expect(
      buildEditorBootstrapCommand({
        zmxBin: `zmx`,
        shellCommand: `/bin/zsh`,
        sessionName: `flo-dotfiles-main-editor`,
        cwd: `/repos/dotfiles`,
        editorCommand: `nvim`,
      }),
    ).toBe(
      `exec 'zmx' attach 'flo-dotfiles-main-editor' '/bin/zsh' -lc 'cd '\\''/repos/dotfiles'\\'' && exec nvim'`,
    )
  })
})

describe(`buildClaudeBootstrapCommand`, () => {
  it(`builds a zmx attach command for Claude Code`, () => {
    expect(
      buildClaudeBootstrapCommand({
        zmxBin: `zmx`,
        shellCommand: `/bin/zsh`,
        sessionName: `flo-dotfiles-main-claude`,
        cwd: `/repos/dotfiles`,
        claudeCommand: `claude`,
      }),
    ).toBe(
      `exec 'zmx' attach 'flo-dotfiles-main-claude' '/bin/zsh' -lc 'cd '\\''/repos/dotfiles'\\'' && exec claude'`,
    )
  })
})

describe(`worktree lifecycle helpers`, () => {
  it(`detects dirty checkouts`, async () => {
    const runner: CommandRunner = async () => ({
      stdout: ` M README.md\n`,
      stderr: ``,
      exitCode: 0,
    })

    expect(await isCheckoutDirty(runner, `/repos/flo`)).toBe(true)
  })

  it(`removes and prunes worktrees`, async () => {
    const calls: string[] = []
    const runner: CommandRunner = async (command, args = []) => {
      calls.push([command, ...args].join(` `))
      return {
        stdout: ``,
        stderr: ``,
        exitCode: 0,
      }
    }

    await removeWorktree({
      runner,
      repositoryPath: `/repos/flo`,
      checkoutPath: `/repos/.flo-checkouts/flo/feat/auth`,
    })
    await pruneWorktrees(runner, `/repos/flo`)

    expect(calls).toContain(`git -C /repos/flo worktree remove /repos/.flo-checkouts/flo/feat/auth`)
    expect(calls).toContain(`git -C /repos/flo worktree prune`)
  })
})
