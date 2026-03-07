import { describe, expect, it } from 'bun:test'
import { normalizeSelector } from '#lib/flo'

describe('normalizeSelector', () => {
  it('trims surrounding whitespace', () => {
    expect(normalizeSelector('  gh:123  ')).toEqual({
      raw: '  gh:123  ',
      value: 'gh:123',
    })
  })
})
