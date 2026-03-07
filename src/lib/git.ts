import { mkdir } from 'node:fs/promises'
import { basename, dirname, join, resolve } from 'node:path'
import { realpath } from 'node:fs/promises'

import { FloError } from '#lib/errors'
import { shellQuote, slugify } from '#lib/strings'
import type { CommandRunner } from '#lib/process'
import type { FloCheckout, GitHubIssue } from '#lib/types'

const parseBranchRef = (value: string): string => value.replace(/^refs\/heads\//, ``)

export const parseGitHubRepo = (remoteUrl: string): string | null => {
  const trimmed = remoteUrl.trim()
  const sshMatch = /^git@github\.com:(.+?)(?:\.git)?$/u.exec(trimmed)

  if (sshMatch?.[1]) {
    return sshMatch[1]
  }

  const httpsMatch = /^https:\/\/github\.com\/(.+?)(?:\.git)?$/u.exec(trimmed)
  return httpsMatch?.[1] ?? null
}

export const parseWorktreeList = (text: string, mainPath: string): FloCheckout[] => {
  const normalizedMainPath = resolve(mainPath)
  const blocks = text.trim().split(/\n\n+/u).filter(Boolean)

  return blocks.map((block) => {
    let path: string | null = null
    let headSha: string | null = null
    let branch: string | null = null

    for (const line of block.split(`\n`)) {
      if (line.startsWith(`worktree `)) path = resolve(line.slice(`worktree `.length))
      else if (line.startsWith(`HEAD `)) headSha = line.slice(`HEAD `.length)
      else if (line.startsWith(`branch `)) branch = parseBranchRef(line.slice(`branch `.length))
    }

    if (path === null) {
      throw new FloError(`GIT_WORKTREE_PARSE`, `Missing worktree path in git worktree list output.`)
    }

    return {
      path,
      branch,
      headSha,
      isMain: path === normalizedMainPath,
    }
  })
}

export const getGitTopLevel = async (
  runner: CommandRunner,
  cwd: string,
): Promise<string | null> => {
  const result = await runner(`git`, [`-C`, cwd, `rev-parse`, `--show-toplevel`])
  if (result.exitCode !== 0) return null
  return resolve(result.stdout.trim())
}

export const getGitRemoteOrigin = async (
  runner: CommandRunner,
  cwd: string,
): Promise<string | null> => {
  const result = await runner(`git`, [`-C`, cwd, `remote`, `get-url`, `origin`])
  if (result.exitCode !== 0) return null
  return result.stdout.trim() || null
}

export const listWorktrees = async (
  runner: CommandRunner,
  repositoryPath: string,
): Promise<FloCheckout[]> => {
  const result = await runner(`git`, [`-C`, repositoryPath, `worktree`, `list`, `--porcelain`])

  if (result.exitCode !== 0) {
    throw new FloError(
      `GIT_WORKTREE_LIST_FAILED`,
      `Failed to list worktrees for ${repositoryPath}: ${result.stderr || result.stdout}`,
    )
  }

  return parseWorktreeList(result.stdout, repositoryPath)
}

export const branchExists = async (
  runner: CommandRunner,
  repositoryPath: string,
  branch: string,
): Promise<boolean> => {
  const result = await runner(`git`, [
    `-C`,
    repositoryPath,
    `show-ref`,
    `--verify`,
    `--quiet`,
    `refs/heads/${branch}`,
  ])

  return result.exitCode === 0
}

const toWorktreePath = (worktreeRoot: string, branch: string): string => {
  const segments = branch
    .split(`/`)
    .map((segment) => segment.trim())
    .filter(Boolean)
    .map((segment) => (segment === `.` || segment === `..` ? slugify(segment) : segment))

  return resolve(join(worktreeRoot, ...segments))
}

export const planWorktreePath = (worktreeRoot: string, branch: string): string =>
  toWorktreePath(worktreeRoot, branch)

export const createWorktree = async (
  runner: CommandRunner,
  repositoryPath: string,
  worktreeRoot: string,
  branch: string,
): Promise<string> => {
  const worktreePath = toWorktreePath(worktreeRoot, branch)
  await mkdir(dirname(worktreePath), { recursive: true })

  const branchAlreadyExists = await branchExists(runner, repositoryPath, branch)
  const args = branchAlreadyExists
    ? [`-C`, repositoryPath, `worktree`, `add`, worktreePath, branch]
    : [`-C`, repositoryPath, `worktree`, `add`, `-b`, branch, worktreePath]

  const result = await runner(`git`, args)

  if (result.exitCode !== 0) {
    throw new FloError(
      `GIT_WORKTREE_CREATE_FAILED`,
      `Failed to create worktree ${worktreePath}: ${result.stderr || result.stdout}`,
    )
  }

  return resolve(await realpath(worktreePath))
}

export const fetchGitHubIssue = async (
  runner: CommandRunner,
  repo: string,
  issueNumber: number,
): Promise<GitHubIssue> => {
  const result = await runner(`gh`, [
    `issue`,
    `view`,
    String(issueNumber),
    `--repo`,
    repo,
    `--json`,
    `number,title,url,state`,
  ])

  if (result.exitCode !== 0) {
    throw new FloError(
      `GITHUB_ISSUE_LOOKUP_FAILED`,
      `Failed to resolve GitHub issue #${issueNumber} in ${repo}: ${result.stderr || result.stdout}`,
    )
  }

  const payload: unknown = JSON.parse(result.stdout)

  if (typeof payload !== `object` || payload === null || Array.isArray(payload)) {
    throw new FloError(
      `GITHUB_ISSUE_LOOKUP_FAILED`,
      `GitHub issue lookup for ${repo} returned an unreadable payload.`,
    )
  }

  const record = payload as {
    number?: unknown
    title?: unknown
    url?: unknown
    state?: unknown
  }

  if (
    typeof record.number !== `number` ||
    typeof record.title !== `string` ||
    typeof record.url !== `string` ||
    typeof record.state !== `string`
  ) {
    throw new FloError(
      `GITHUB_ISSUE_LOOKUP_FAILED`,
      `GitHub issue lookup for ${repo} returned an incomplete payload.`,
    )
  }

  return {
    number: record.number,
    title: record.title,
    url: record.url,
    state: record.state,
    repo,
  }
}

export const issueBranchName = (issue: GitHubIssue): string =>
  `issue/${issue.number}-${slugify(issue.title)}`

export const buildEditorBootstrapCommand = (args: {
  zmxBin: string
  shellCommand: string
  sessionName: string
  cwd: string
  editorCommand: string
}): string =>
  `exec ${shellQuote(args.zmxBin)} attach ${shellQuote(args.sessionName)} ${shellQuote(args.shellCommand)} -lc ${shellQuote(`cd ${shellQuote(args.cwd)} && exec ${args.editorCommand}`)}`

export const deriveDefaultWorktreeRoot = (repositoryPath: string): string =>
  resolve(dirname(repositoryPath), `.flo-checkouts`, basename(repositoryPath))
