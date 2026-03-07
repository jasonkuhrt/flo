import { describe, expect, it } from 'bun:test'

import { FloError } from '#lib/errors'
import { parseOpenSelector, parseStartSelector } from '#lib/selectors'

describe(`parseStartSelector`, () => {
  it(`parses numeric selectors as implicit GitHub issues`, () => {
    expect(parseStartSelector(`123`)).toEqual({
      kind: `github-issue`,
      issueNumber: 123,
      explicit: false,
      raw: `123`,
    })
  })

  it(`parses explicit GitHub issue selectors`, () => {
    expect(parseStartSelector(`gh:42`)).toEqual({
      kind: `github-issue`,
      issueNumber: 42,
      explicit: true,
      raw: `gh:42`,
    })
  })

  it(`parses Linear-style selectors`, () => {
    expect(parseStartSelector(`ENG-241`)).toEqual({
      kind: `linear-issue`,
      key: `ENG-241`,
      raw: `ENG-241`,
    })
  })

  it(`falls back to branch selectors`, () => {
    expect(parseStartSelector(`feat/cmux-launcher`)).toEqual({
      kind: `branch`,
      branch: `feat/cmux-launcher`,
      raw: `feat/cmux-launcher`,
    })
  })

  it(`parses explicit Linear and bead selectors`, () => {
    expect(parseStartSelector(`linear:ENG-242`)).toEqual({
      kind: `linear-issue`,
      key: `ENG-242`,
      raw: `linear:ENG-242`,
    })
    expect(parseStartSelector(`bead:core/parser-cleanup`)).toEqual({
      kind: `bead`,
      bead: `core/parser-cleanup`,
      raw: `bead:core/parser-cleanup`,
    })
  })

  it(`rejects empty selectors`, () => {
    expect(() => parseStartSelector(`   `)).toThrow(FloError)
  })
})

describe(`parseOpenSelector`, () => {
  it(`parses project-only selectors`, () => {
    expect(parseOpenSelector(`dotfiles`)).toEqual({
      projectSelector: `dotfiles`,
    })
  })

  it(`parses checkout selectors`, () => {
    expect(parseOpenSelector(`heartbeat@feat-auth`)).toEqual({
      projectSelector: `heartbeat`,
      checkoutSelector: `feat-auth`,
    })
  })

  it(`rejects empty open selectors`, () => {
    expect(() => parseOpenSelector(` `)).toThrow(FloError)
  })
})
