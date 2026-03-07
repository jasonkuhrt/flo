import { describe, expect, it } from 'bun:test'

import {
  expandHome,
  looksLikeAbsolutePath,
  normalizeMatchKey,
  sanitizeIdentifier,
  shellQuote,
  slugify,
} from '#lib/strings'

describe(`strings`, () => {
  it(`quotes shell values`, () => {
    expect(shellQuote(`it's`)).toBe(`'it'\\''s'`)
  })

  it(`slugifies labels`, () => {
    expect(slugify(`Add cmux launcher`)).toBe(`add-cmux-launcher`)
  })

  it(`sanitizes identifiers`, () => {
    expect(sanitizeIdentifier(`flo:flo/main`)).toBe(`flo-flo-main`)
  })

  it(`normalizes match keys`, () => {
    expect(normalizeMatchKey(`  DotFiles `)).toBe(`dotfiles`)
  })

  it(`recognizes absolute paths`, () => {
    expect(looksLikeAbsolutePath(`/tmp/flo`)).toBe(true)
    expect(looksLikeAbsolutePath(`~/tmp/flo`)).toBe(true)
    expect(looksLikeAbsolutePath(`dotfiles`)).toBe(false)
  })

  it(`expands home prefixes`, () => {
    expect(expandHome(`~/projects`, `/home/test`)).toBe(`/home/test/projects`)
  })
})
