import { describe, expect, it } from 'bun:test'

import { fetchLinearIssue, issueBranchName } from '#lib/linear'
import type { LinearFetch } from '#lib/linear'

const mockFetch =
  (payload: unknown, status = 200): LinearFetch =>
  async () => ({
    ok: status >= 200 && status < 300,
    status,
    text: async () => JSON.stringify(payload),
  })

describe(`linear issue adapter`, () => {
  it(`fetches and validates a Linear issue`, async () => {
    const issue = await fetchLinearIssue({
      key: `hea-4225`,
      env: { LINEAR_API_TOKEN: `lin_api_test` },
      fetch: mockFetch({
        data: {
          searchIssues: {
            nodes: [
              {
                identifier: `HEA-4225`,
                title: `Redo aborted`,
                url: `https://linear.app/heartbeat-chat/issue/HEA-4225/redo-aborted`,
                state: { name: `Todo` },
                team: { key: `HEA` },
              },
            ],
          },
        },
      }),
    })

    expect(issue).toEqual({
      source: `linear`,
      key: `HEA-4225`,
      title: `Redo aborted`,
      url: `https://linear.app/heartbeat-chat/issue/HEA-4225/redo-aborted`,
      state: `Todo`,
      teamKey: `HEA`,
    })
    expect(issueBranchName(issue)).toBe(`issue/HEA-4225-redo-aborted`)
  })

  it(`fails when LINEAR_API_TOKEN is missing`, async () => {
    try {
      await fetchLinearIssue({
        key: `HEA-4225`,
        env: {},
        fetch: mockFetch({ data: {} }),
      })
      throw new Error(`expected fetchLinearIssue to fail`)
    } catch (error) {
      expect(error).toMatchObject({ code: `LINEAR_TOKEN_REQUIRED` })
    }
  })

  it(`fails when the issue cannot be found`, async () => {
    try {
      await fetchLinearIssue({
        key: `HEA-4225`,
        env: { LINEAR_API_TOKEN: `lin_api_test` },
        fetch: mockFetch({
          data: {
            searchIssues: {
              nodes: [],
            },
          },
        }),
      })
      throw new Error(`expected fetchLinearIssue to fail`)
    } catch (error) {
      expect(error).toMatchObject({ code: `LINEAR_ISSUE_NOT_FOUND` })
    }
  })

  it(`fails when the response payload is malformed`, async () => {
    try {
      await fetchLinearIssue({
        key: `HEA-4225`,
        env: { LINEAR_API_TOKEN: `lin_api_test` },
        fetch: mockFetch({
          data: {
            searchIssues: {
              nodes: [
                {
                  identifier: `HEA-4225`,
                  title: `Redo aborted`,
                },
              ],
            },
          },
        }),
      })
      throw new Error(`expected fetchLinearIssue to fail`)
    } catch (error) {
      expect(error).toMatchObject({ code: `LINEAR_ISSUE_LOOKUP_FAILED` })
    }
  })
})
