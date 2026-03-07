export type FloSourceKind = `github` | `linear` | `bead`

export interface FloRuntimeConfig {
  editorCommand: string
  claudeCommand: string
  shellCommand: string
  cmuxBin: string
  zmxBin: string
  fzfBin: string
  workspacePrefix: string
}

export interface FloProjectConfig {
  name: string
  path: string
  aliases?: string[]
  defaultSource?: FloSourceKind
  github?: {
    repo: string
  }
  worktreeRoot?: string
}

export interface FloConfig {
  discovery?: {
    roots?: string[]
  }
  runtime?: Partial<FloRuntimeConfig>
  projects?: FloProjectConfig[]
}

export interface ResolvedFloConfig {
  configPath: string
  exists: boolean
  discoveryRoots: string[]
  runtime: FloRuntimeConfig
  projects: FloProjectConfig[]
}

export interface FloProject {
  name: string
  path: string
  aliases: string[]
  defaultSource?: FloSourceKind
  githubRepo?: string
  worktreeRoot: string
}

export interface FloCheckout {
  path: string
  branch: string | null
  headSha: string | null
  isMain: boolean
}

export interface FloProjectState {
  project: FloProject
  checkouts: FloCheckout[]
}

export interface GitHubIssue {
  number: number
  title: string
  url: string
  state: string
  repo: string
}

export type StartSelector =
  | {
      kind: `github-issue`
      issueNumber: number
      explicit: boolean
      raw: string
    }
  | {
      kind: `linear-issue`
      key: string
      raw: string
    }
  | {
      kind: `bead`
      bead: string
      raw: string
    }
  | {
      kind: `branch`
      branch: string
      raw: string
    }

export interface OpenTarget {
  project: FloProject
  checkout: FloCheckout
  workspaceTitle: string
  editorSessionName: string
  editorBootstrapCommand: string
}

export interface StartTarget extends OpenTarget {
  createdCheckout: boolean
  issue?: GitHubIssue
}

export interface CmuxWorkspace {
  id: string
  title: string
}

export interface FloListCheckout {
  path: string
  branch: string | null
  isMain: boolean
  workspaceTitle: string
  workspaceOpen: boolean | null
}

export interface FloListProject {
  name: string
  path: string
  defaultSource?: FloSourceKind
  githubRepo?: string
  checkouts: FloListCheckout[]
}

export interface FloListResult {
  configPath: string
  configExists: boolean
  cmuxAvailable: boolean
  projects: FloListProject[]
}

export interface FloCommandContext {
  cwd: string
  env: NodeJS.ProcessEnv
}
