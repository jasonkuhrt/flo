export type FloSourceKind = `github` | `linear` | `bead`
export type FloWorkspaceKind = `main` | `feature`
export type FloSplitDirection = `right` | `bottom`
export type FloWorkspacePlanAction =
  | `create-and-init`
  | `focus-existing`
  | `close-existing`
  | `no-open-workspace`
  | `cmux-unavailable`

export interface FloWorkspaceProfileConfig {
  editorCommand?: string
  claudeCommand?: string
  splitDirection?: FloSplitDirection
}

export interface FloWorkspaceProfiles {
  main: FloWorkspaceProfileConfig
  feature: FloWorkspaceProfileConfig
}

export interface FloRuntimeConfig {
  editorCommand: string
  claudeCommand: string
  shellCommand: string
  cmuxBin: string
  zmxBin: string
  fzfBin: string
  workspacePrefix: string
  profiles: FloWorkspaceProfiles
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
  workspaceProfiles?: Partial<FloWorkspaceProfiles>
}

export interface FloConfig {
  discovery?: {
    roots?: string[]
  }
  runtime?: Partial<Omit<FloRuntimeConfig, `profiles`>> & {
    profiles?: Partial<FloWorkspaceProfiles>
  }
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
  workspaceProfiles: Partial<FloWorkspaceProfiles>
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
  claudePaneDirection: FloSplitDirection
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
  lastOpenedAt?: string
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

export interface FloDoctorCommand {
  key: string
  configured: string
  executable: string
  available: boolean
}

export interface FloDoctorResult {
  configPath: string
  configExists: boolean
  currentDirectory: string
  cmuxAvailable: boolean
  currentProject: {
    name: string
    path: string
  } | null
  currentCheckout: {
    path: string
    branch: string | null
    isMain: boolean
  } | null
  commands: FloDoctorCommand[]
}

export interface FloStatusResult {
  currentDirectory: string
  cmuxAvailable: boolean
  currentProject: {
    name: string
    path: string
  } | null
  currentCheckout: {
    path: string
    branch: string | null
    isMain: boolean
  } | null
  expectedWorkspace: {
    title: string
    identity: string
  } | null
  activeWorkspace: {
    id: string
    title: string
  } | null
  issue?: GitHubIssue
}

export interface FloWorkspaceStateRecord {
  workspaceIdentity: string
  workspaceTitle: string
  projectName: string
  checkoutPath: string
  branch: string | null
  isMain: boolean
  lastOpenedAt: string
  lastAction: `open` | `start`
}

export interface FloState {
  version: 1
  workspaces: FloWorkspaceStateRecord[]
}

export interface FloRecentItem {
  selector: string
  projectName: string
  checkoutPath: string
  branch: string | null
  isMain: boolean
  workspaceIdentity: string
  workspaceTitle: string
  workspaceOpen: boolean | null
  lastOpenedAt: string
  lastAction: `open` | `start`
}

export interface FloRecentResult {
  cmuxAvailable: boolean
  items: FloRecentItem[]
}

export interface FloConfigInitResult {
  configPath: string
  configExists: boolean
  wroteConfig: boolean
  project?: {
    name: string
    path: string
    githubRepo?: string
  }
}

export interface FloClaudeHookInstallResult {
  settingsPath: string
  checkoutPath: string
  wroteSettings: boolean
  hookEvents: string[]
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

export interface FloWorkspacePlan {
  title: string
  identity: string
  kind: FloWorkspaceKind
  action: FloWorkspacePlanAction
  existingWorkspace?: {
    id: string
    title: string
  }
}

export interface FloWorkspaceInitPlan {
  splitDirection: FloSplitDirection
  focus: `editor`
  editor: {
    sessionName: string
    command: string
  }
  claude: {
    sessionName: string
    command: string
  }
}

export interface FloExplainOpenResult {
  command: `open`
  selector?: string
  cmuxAvailable: boolean
  project: {
    name: string
    path: string
  }
  checkout: {
    path: string
    branch: string | null
    isMain: boolean
  }
  workspace: FloWorkspacePlan
  init: FloWorkspaceInitPlan
}

export interface FloExplainStartResult {
  command: `start`
  selector: string
  projectSelector?: string
  cmuxAvailable: boolean
  project: {
    name: string
    path: string
  }
  checkout: {
    path: string
    branch: string | null
    isMain: boolean
  }
  workspace: FloWorkspacePlan
  init: FloWorkspaceInitPlan
  createdCheckout: boolean
  issue?: GitHubIssue
}

export interface FloExplainEndResult {
  command: `end`
  selector?: string
  cmuxAvailable: boolean
  force: boolean
  openMain: boolean
  project: {
    name: string
    path: string
  }
  checkout: {
    path: string
    branch: string | null
    isMain: boolean
  }
  workspace: FloWorkspacePlan
  sessions: {
    editor: string
    claude: string
  }
  removesCheckout: true
  dirtyCheckoutAllowed: boolean
  reopensMainWorkspace?: FloWorkspacePlan
}

export type FloExplainResult = FloExplainOpenResult | FloExplainStartResult | FloExplainEndResult

export interface FloEndResult extends FloEndedTarget {
  closedWorkspace: boolean
  removedCheckout: boolean
  killedEditorSession: boolean
  killedClaudeSession: boolean
  reopenedMainWorkspace?: boolean
  reopenedMainWorkspaceId?: string
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

export interface FloPrunedRecentResult {
  workspaceIdentity: string
  workspaceTitle: string
  checkoutPath: string
}

export interface FloPruneResult {
  projects: FloPruneProjectResult[]
  closedWorkspaces: FloPruneWorkspaceResult[]
  prunedRecents: FloPrunedRecentResult[]
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
