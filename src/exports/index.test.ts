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

test(`re-exports statusFlo`, () => {
  expect(typeof Lib.statusFlo).toBe(`function`)
})

test(`re-exports listRecentWork`, () => {
  expect(typeof Lib.listRecentWork).toBe(`function`)
})

test(`re-exports openLastWorkspace`, () => {
  expect(typeof Lib.openLastWorkspace).toBe(`function`)
})

test(`re-exports initConfig`, () => {
  expect(typeof Lib.initConfig).toBe(`function`)
})

test(`re-exports installClaudeHooks`, () => {
  expect(typeof Lib.installClaudeHooks).toBe(`function`)
})

test(`re-exports formatFloContextEnv`, () => {
  expect(typeof Lib.formatFloContextEnv).toBe(`function`)
})
