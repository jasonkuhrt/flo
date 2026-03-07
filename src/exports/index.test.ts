import { expect, test } from 'bun:test'
import * as Lib from './index.ts'

test(`re-exports normalizeSelector`, () => {
  expect(Lib.normalizeSelector(' linear:ENG-241 ')).toEqual({
    raw: ' linear:ENG-241 ',
    value: 'linear:ENG-241',
  })
})

test(`re-exports syncFloUi`, () => {
  expect(typeof Lib.syncFloUi).toBe(`function`)
})

test(`re-exports doctorFlo`, () => {
  expect(typeof Lib.doctorFlo).toBe(`function`)
})
