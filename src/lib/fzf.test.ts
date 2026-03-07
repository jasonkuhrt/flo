import { describe, expect, it } from 'bun:test'

import { FloError } from '#lib/errors'
import { runFzf } from '#lib/fzf'
import type { CommandRunner } from '#lib/process'

const items = [
  {
    selector: `dotfiles`,
    label: `dotfiles  [main]`,
    path: `/repos/dotfiles`,
  },
  {
    selector: `flo@feat/auth`,
    label: `flo  [feat/auth]`,
    path: `/repos/.flo-checkouts/flo/feat/auth`,
  },
]
const selectedItem = items[1]

if (selectedItem === undefined) {
  throw new Error(`Expected launcher fixture.`)
}

describe(`runFzf`, () => {
  it(`returns the selected launcher item`, async () => {
    const runner: CommandRunner = async () => ({
      stdout: `flo@feat/auth\tflo  [feat/auth]\t/repos/.flo-checkouts/flo/feat/auth\n`,
      stderr: ``,
      exitCode: 0,
    })

    const result = await runFzf({ runner, fzfBin: `fzf`, items })
    expect(result).toEqual(selectedItem)
  })

  it(`returns null when the selection is cancelled`, async () => {
    const runner: CommandRunner = async () => ({
      stdout: ``,
      stderr: ``,
      exitCode: 130,
    })

    const result = await runFzf({ runner, fzfBin: `fzf`, items })
    expect(result).toBeNull()
  })

  it(`rejects unknown selections`, async () => {
    const runner: CommandRunner = async () => ({
      stdout: `unknown\tunknown\t/tmp\n`,
      stderr: ``,
      exitCode: 0,
    })

    let thrown: unknown = null

    try {
      await runFzf({ runner, fzfBin: `fzf`, items })
    } catch (error) {
      thrown = error
    }

    expect(thrown).toBeInstanceOf(FloError)
  })
})
