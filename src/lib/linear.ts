import { FloError } from '#lib/errors'
import { slugify } from '#lib/strings'
import type { LinearIssue } from '#lib/types'

export const linearIssueKeyPattern = /^[A-Z][A-Z0-9]+-\d+$/u

interface ResponseLike {
  ok: boolean
  status: number
  text(): Promise<string>
}

type FetchLike = (
  input: string,
  init: {
    method: string
    headers: Record<string, string>
    body: string
  },
) => Promise<ResponseLike>

export type LinearFetch = FetchLike

const isRecord = (value: unknown): value is Record<string, unknown> =>
  typeof value === `object` && value !== null && !Array.isArray(value)
const isUnknownArray = (value: unknown): value is unknown[] => Array.isArray(value)

const normalizeLinearIssueKey = (value: string): string => value.trim().toUpperCase()

export const issueBranchName = (issue: LinearIssue): string =>
  `issue/${issue.key}-${slugify(issue.title)}`

export const fetchLinearIssue = async (args: {
  key: string
  env: NodeJS.ProcessEnv
  fetch?: FetchLike
  endpoint?: string
}): Promise<LinearIssue> => {
  const token = args.env[`LINEAR_API_TOKEN`]
  if (typeof token !== `string` || token.trim().length === 0) {
    throw new FloError(
      `LINEAR_TOKEN_REQUIRED`,
      `Linear issue selectors require LINEAR_API_TOKEN to be set.`,
    )
  }

  const key = normalizeLinearIssueKey(args.key)
  if (!linearIssueKeyPattern.test(key)) {
    throw new FloError(
      `LINEAR_ISSUE_LOOKUP_FAILED`,
      `Linear issue key "${args.key}" is invalid. Expected TEAM-123 format.`,
    )
  }

  const fetchImpl = args.fetch ?? fetch
  const endpoint = args.endpoint ?? `https://api.linear.app/graphql`
  const response = await fetchImpl(endpoint, {
    method: `POST`,
    headers: {
      'Content-Type': `application/json`,
      Authorization: token,
    },
    body: JSON.stringify({
      query: `query FloIssueByIdentifier($term: String!) {
  searchIssues(term: $term, first: 10) {
    nodes {
      identifier
      title
      url
      state { name }
      team { key }
    }
  }
}`,
      variables: {
        term: key,
      },
    }),
  })

  const bodyText = await response.text()
  if (!response.ok) {
    throw new FloError(
      `LINEAR_ISSUE_LOOKUP_FAILED`,
      `Failed to resolve Linear issue ${key}: HTTP ${response.status} ${bodyText}`,
    )
  }

  let payload: unknown
  try {
    payload = JSON.parse(bodyText) as unknown
  } catch {
    throw new FloError(
      `LINEAR_ISSUE_LOOKUP_FAILED`,
      `Linear issue lookup for ${key} returned invalid JSON.`,
    )
  }

  if (!isRecord(payload)) {
    throw new FloError(
      `LINEAR_ISSUE_LOOKUP_FAILED`,
      `Linear issue lookup for ${key} returned an unreadable payload.`,
    )
  }

  if (`errors` in payload && Array.isArray(payload[`errors`]) && payload[`errors`].length > 0) {
    throw new FloError(
      `LINEAR_ISSUE_LOOKUP_FAILED`,
      `Linear issue lookup for ${key} returned GraphQL errors.`,
    )
  }

  const data = payload[`data`]
  if (!isRecord(data)) {
    throw new FloError(
      `LINEAR_ISSUE_LOOKUP_FAILED`,
      `Linear issue lookup for ${key} returned an incomplete payload.`,
    )
  }

  const searchIssues = data[`searchIssues`]
  if (!isRecord(searchIssues)) {
    throw new FloError(
      `LINEAR_ISSUE_LOOKUP_FAILED`,
      `Linear issue lookup for ${key} returned an incomplete payload.`,
    )
  }

  const nodes = searchIssues[`nodes`]
  if (!isUnknownArray(nodes)) {
    throw new FloError(
      `LINEAR_ISSUE_LOOKUP_FAILED`,
      `Linear issue lookup for ${key} returned an incomplete payload.`,
    )
  }

  let node: Record<string, unknown> | undefined
  for (const candidate of nodes) {
    if (!isRecord(candidate)) continue
    const identifier = candidate[`identifier`]
    if (typeof identifier !== `string`) continue
    if (normalizeLinearIssueKey(identifier) !== key) continue
    node = candidate
    break
  }

  if (node === undefined) {
    throw new FloError(`LINEAR_ISSUE_NOT_FOUND`, `Linear issue ${key} was not found.`)
  }

  const identifier = node[`identifier`]
  const title = node[`title`]
  const url = node[`url`]
  const state = node[`state`]
  const team = node[`team`]

  if (
    typeof identifier !== `string` ||
    typeof title !== `string` ||
    typeof url !== `string` ||
    !isRecord(state) ||
    typeof state[`name`] !== `string` ||
    !isRecord(team) ||
    typeof team[`key`] !== `string`
  ) {
    throw new FloError(
      `LINEAR_ISSUE_LOOKUP_FAILED`,
      `Linear issue lookup for ${key} returned an incomplete payload.`,
    )
  }

  return {
    source: `linear`,
    key: normalizeLinearIssueKey(identifier),
    title,
    url,
    state: state[`name`],
    teamKey: normalizeLinearIssueKey(team[`key`]),
  }
}
