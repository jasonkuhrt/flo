import { FloError } from '#lib/errors'
import type { StartSelector } from '#lib/types'

const linearIssuePattern = /^[A-Z][A-Z0-9]+-\d+$/u

export const parseStartSelector = (rawSelector: string): StartSelector => {
  const value = rawSelector.trim()

  if (value.length === 0) {
    throw new FloError(`SELECTOR_EMPTY`, `A selector is required.`)
  }

  if (/^gh:\d+$/u.test(value)) {
    return {
      kind: `github-issue`,
      issueNumber: Number(value.slice(3)),
      explicit: true,
      raw: value,
    }
  }

  if (/^\d+$/u.test(value)) {
    return {
      kind: `github-issue`,
      issueNumber: Number(value),
      explicit: false,
      raw: value,
    }
  }

  if (value.startsWith(`linear:`)) {
    return {
      kind: `linear-issue`,
      key: value.slice(`linear:`.length),
      raw: value,
    }
  }

  if (value.startsWith(`bead:`)) {
    return {
      kind: `bead`,
      bead: value.slice(`bead:`.length),
      raw: value,
    }
  }

  if (linearIssuePattern.test(value)) {
    return {
      kind: `linear-issue`,
      key: value,
      raw: value,
    }
  }

  return {
    kind: `branch`,
    branch: value,
    raw: value,
  }
}

export interface OpenSelector {
  projectSelector: string
  checkoutSelector?: string
}

export const parseOpenSelector = (rawSelector: string): OpenSelector => {
  const value = rawSelector.trim()

  if (value.length === 0) {
    throw new FloError(`SELECTOR_EMPTY`, `A selector is required.`)
  }

  const atIndex = value.indexOf(`@`)
  if (atIndex === -1) {
    return {
      projectSelector: value,
    }
  }

  return {
    projectSelector: value.slice(0, atIndex),
    checkoutSelector: value.slice(atIndex + 1),
  }
}
