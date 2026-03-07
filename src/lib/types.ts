export type FloSourceKind = `github` | `linear` | `bead`
export type FloWorkspaceKind = `main` | `feature`

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

export interface FloWorkspaceMetadata {
  identity: string
  project: string
  kind: FloWorkspaceKind
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
  workspaceMetadata: FloWorkspaceMetadata
  editorSessionName: string
  claudeSessionName: string
  editorBootstrapCommand: string
  claudeBootstrapCommand: string
}

export interface StartTarget extends OpenTarget {
  createdCheckout: boolean
  issue?: GitHubIssue
}

export interface FloContextResult extends OpenTarget {
  issue?: GitHubIssue
}

export interface CmuxWorkspace {
  id: string
  title: string
}

export interface CmuxStatusEntry {
  key: string
  value: string
  icon?: string
  color?: string
}

export interface CmuxSidebarState {
  cwd: string | null
  statuses: CmuxStatusEntry[]
}

export interface FloListCheckout {
  path: string
  branch: string | null
  isMain: boolean
  workspaceIdentity: string
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

export interface FloEndedTarget {
  project: FloProject
  checkout: FloCheckout
  workspaceTitle: string
  workspaceMetadata: FloWorkspaceMetadata
  editorSessionName: string
  claudeSessionName: string
  workspaceId?: string
}

export interface FloEndResult extends FloEndedTarget {
  closedWorkspace: boolean
  removedCheckout: boolean
  killedEditorSession: boolean
  killedClaudeSession: boolean
}

export interface FloPruneWorkspaceResult {
  workspaceId: string
  workspaceTitle: string
  identity: string | null
  checkoutPath: string | null
  closedWorkspace: boolean
  killedEditorSession: boolean
  killedClaudeSession: boolean
}

export interface FloPruneProjectResult {
  name: string
  path: string
}

export interface FloPruneResult {
  projects: FloPruneProjectResult[]
  closedWorkspaces: FloPruneWorkspaceResult[]
}

export interface FloUiSyncResult {
  cmuxAvailable: boolean
  workspaceId?: string
  phase?: string
  agents?: number
  claude?: string
}

export interface FloUiLogResult {
  cmuxAvailable: boolean
  workspaceId?: string
  level: string
  source: string
  message: string
}

export interface FloUiNotifyResult {
  cmuxAvailable: boolean
  workspaceId?: string
  title: string
  subtitle?: string
  body?: string
}

export interface FloClaudeHookResult {
  cmuxAvailable: boolean
  workspaceId?: string
  handled: boolean
  hook: `notification` | `session-start` | `pre-compact` | `subagent-start` | `subagent-stop`
  summary: string
}
