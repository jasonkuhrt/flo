import { basename, dirname, resolve } from 'pathe'

import {
  closeCmuxWorkspace,
  createCmuxWorkspace,
  getCmuxSidebarState,
  listCmuxWorkspaces,
  newCmuxPane,
  probeCmux,
  renameCmuxWorkspace,
  selectCmuxWorkspace,
  selectLastCmuxPane,
  sendToCmuxWorkspace,
  setCmuxStatus,
  statusEntryValue,
} from '#lib/cmux'
import { loadConfig } from '#lib/config'
import { FloError } from '#lib/errors'
import { makeDirectoryRecursive, realPath, writeFileString } from '#lib/filesystem'
import { runFzf, type LauncherItem } from '#lib/fzf'
import {
  buildClaudeBootstrapCommand,
  buildEditorBootstrapCommand,
  createWorktree,
  fetchGitHubIssue,
  isCheckoutDirty,
  issueBranchName,
  planWorktreePath,
  pruneWorktrees,
  removeWorktree,
} from '#lib/git'
import { systemRunner, type CommandRunner } from '#lib/process'
import {
  discoverProjects,
  getCurrentProject,
  listProjectState,
  resolveCheckoutSelector,
  resolveProjectSelector,
} from '#lib/projects'
import { parseOpenSelector, parseStartSelector } from '#lib/selectors'
import { loadState, pruneWorkspaceState, touchWorkspaceState } from '#lib/state'
import { sanitizeIdentifier, shellQuote } from '#lib/strings'
import type {
  FloCheckout,
  FloCommandContext,
  FloConfigInitResult,
  FloContextResult,
  FloDoctorCommand,
  FloExplainEndResult,
  FloExplainOpenResult,
  FloExplainStartResult,
  FloInitPreviewResult,
  FloDoctorResult,
  FloEndResult,
  FloEndedTarget,
  FloListProject,
  FloListResult,
  FloProject,
  FloPruneProjectResult,
  FloPruneResult,
  FloPruneWorkspaceResult,
  FloRecentItem,
  FloRecentResult,
  FloWorkspacePlan,
  FloStatusResult,
  FloWorkspaceKind,
  FloWorkspaceInitPlan,
  OpenTarget,
  StartSelector,
  StartTarget,
} from '#lib/types'
import { killZmxSession } from '#lib/zmx'

export interface FloRuntimeDependencies {
  runner?: CommandRunner
}

const defaultDependencies: Required<FloRuntimeDependencies> = {
  runner: systemRunner,
}

const workspaceTitle = (prefix: string, project: FloProject, checkout: FloCheckout): string =>
  checkout.isMain
    ? `${prefix}:${project.name}`
    : `${prefix}:${project.name}@${checkout.branch ?? basename(checkout.path)}`

const workspaceKind = (checkout: FloCheckout): FloWorkspaceKind =>
  checkout.isMain ? `main` : `feature`

const parseIssueNumberFromBranch = (branch: string | null): number | null => {
  if (branch === null) return null

  const match = /^issue\/(\d+)-/u.exec(branch)
  return match?.[1] === undefined ? null : Number.parseInt(match[1], 10)
}

const canonicalizeCheckoutPath = async (checkoutPath: string): Promise<string> => {
  try {
    return resolve(await realPath(checkoutPath))
  } catch {
    return resolve(checkoutPath)
  }
}

const workspaceIdentity = async (checkoutPath: string): Promise<string> => {
  const digest = await crypto.subtle.digest(`SHA-256`, new TextEncoder().encode(checkoutPath))
  return [...new Uint8Array(digest)]
    .map((part) => part.toString(16).padStart(2, `0`))
    .join(``)
    .slice(0, 12)
}

const recencyScore = (timestamp: string | undefined): number =>
  timestamp === undefined ? Number.NEGATIVE_INFINITY : Date.parse(timestamp)

const compareCheckoutsForDisplay = (
  left: FloListProject[`checkouts`][number],
  right: FloListProject[`checkouts`][number],
): number => {
  if (left.workspaceOpen !== right.workspaceOpen) {
    return left.workspaceOpen === true ? -1 : 1
  }

  const recencyDelta = recencyScore(right.lastOpenedAt) - recencyScore(left.lastOpenedAt)
  if (recencyDelta !== 0) return recencyDelta

  if (left.isMain !== right.isMain) {
    return left.isMain ? -1 : 1
  }

  return (left.branch ?? basename(left.path)).localeCompare(right.branch ?? basename(right.path))
}

const compareProjectsForDisplay = (left: FloListProject, right: FloListProject): number => {
  const leftOpen = left.checkouts.some((checkout) => checkout.workspaceOpen === true)
  const rightOpen = right.checkouts.some((checkout) => checkout.workspaceOpen === true)
  if (leftOpen !== rightOpen) {
    return leftOpen ? -1 : 1
  }

  const leftRecent = Math.max(
    ...left.checkouts.map((checkout) => recencyScore(checkout.lastOpenedAt)),
    Number.NEGATIVE_INFINITY,
  )
  const rightRecent = Math.max(
    ...right.checkouts.map((checkout) => recencyScore(checkout.lastOpenedAt)),
    Number.NEGATIVE_INFINITY,
  )
  if (leftRecent !== rightRecent) {
    return rightRecent - leftRecent
  }

  return left.name.localeCompare(right.name)
}

const sessionStem = (args: {
  prefix: string
  project: FloProject
  checkout: FloCheckout
  identity: string
}): string =>
  sanitizeIdentifier(
    `${args.prefix}-${args.project.name}-${workspaceKind(args.checkout)}-${args.identity}`,
  )

const buildOpenTarget = async (args: {
  project: FloProject
  checkout: FloCheckout
  runtime: Awaited<ReturnType<typeof loadConfig>>[`runtime`]
}): Promise<OpenTarget> => {
  const canonicalCheckoutPath = await canonicalizeCheckoutPath(args.checkout.path)
  const normalizedCheckout =
    canonicalCheckoutPath === args.checkout.path
      ? args.checkout
      : {
          ...args.checkout,
          path: canonicalCheckoutPath,
        }
  const identity = await workspaceIdentity(canonicalCheckoutPath)
  const title = workspaceTitle(args.runtime.workspacePrefix, args.project, normalizedCheckout)
  const kind = workspaceKind(normalizedCheckout)
  const profile = {
    ...args.runtime.profiles[kind],
    ...args.project.workspaceProfiles[kind],
    layout: {
      ...(args.runtime.profiles[kind].layout ?? {}),
      ...(args.project.workspaceProfiles[kind]?.layout ?? {}),
    },
  }
  const stem = sessionStem({
    prefix: args.runtime.workspacePrefix,
    project: args.project,
    checkout: normalizedCheckout,
    identity,
  })

  return {
    project: args.project,
    checkout: normalizedCheckout,
    workspaceTitle: title,
    workspaceMetadata: {
      identity,
      project: args.project.name,
      kind,
    },
    workspaceLayout: {
      splitDirection: profile.layout.splitDirection ?? `right`,
      secondaryPane: profile.layout.secondaryPane ?? `claude`,
      focus: profile.layout.focus ?? `editor`,
    },
    editorSessionName: `${stem}-editor`,
    claudeSessionName: `${stem}-claude`,
    editorBootstrapCommand: buildEditorBootstrapCommand({
      zmxBin: args.runtime.zmxBin,
      shellCommand: args.runtime.shellCommand,
      sessionName: `${stem}-editor`,
      cwd: normalizedCheckout.path,
      editorCommand: profile.editorCommand ?? args.runtime.editorCommand,
    }),
    claudeBootstrapCommand: buildClaudeBootstrapCommand({
      zmxBin: args.runtime.zmxBin,
      shellCommand: args.runtime.shellCommand,
      sessionName: `${stem}-claude`,
      cwd: normalizedCheckout.path,
      claudeCommand: profile.claudeCommand ?? args.runtime.claudeCommand,
    }),
  }
}

const findProjectForCwd = async (args: {
  projects: FloProject[]
  cwd: string
  runner: CommandRunner
}): Promise<FloProject | null> => {
  const projectFromRepoRoot = getCurrentProject(args.projects, args.cwd)
  if (projectFromRepoRoot !== null) {
    return projectFromRepoRoot
  }

  const resolvedCwd = resolve(args.cwd)
  const candidates = await Promise.all(
    args.projects.map(async (project) => {
      const state = await listProjectState(args.runner, project)
      const matchingCheckout = state.checkouts
        .filter(
          (checkout) =>
            resolvedCwd === checkout.path || resolvedCwd.startsWith(`${checkout.path}/`),
        )
        .sort((left, right) => right.path.length - left.path.length)[0]

      return matchingCheckout === undefined
        ? null
        : {
            project,
            checkoutPath: matchingCheckout.path,
          }
    }),
  )

  const projectFromCheckout = candidates
    .filter((candidate) => candidate !== null)
    .sort((left, right) => right.checkoutPath.length - left.checkoutPath.length)[0]

  if (projectFromCheckout !== undefined) {
    return projectFromCheckout.project
  }

  return null
}

const requireCurrentProject = async (args: {
  projects: FloProject[]
  cwd: string
  runner: CommandRunner
}): Promise<FloProject> => {
  const project = await findProjectForCwd(args)
  if (project !== null) {
    return project
  }

  throw new FloError(
    `PROJECT_CONTEXT_REQUIRED`,
    `No project matched the current directory. Run Flo inside a git project or pass an explicit project selector.`,
  )
}

const extractExecutable = (command: string): string =>
  command.trim().split(/\s+/u)[0] ?? command.trim()

const probeConfiguredCommand = async (args: {
  runner: CommandRunner
  shellCommand: string
  key: string
  configured: string
}): Promise<FloDoctorCommand> => {
  const executable = extractExecutable(args.configured)
  const result = await args.runner(args.shellCommand, [
    `-lc`,
    `command -v -- ${shellQuote(executable)}`,
  ])

  return {
    key: args.key,
    configured: args.configured,
    executable,
    available: result.exitCode === 0,
  }
}

const ensureCmuxAvailable = async (runner: CommandRunner, cmuxBin: string): Promise<void> => {
  const available = await probeCmux(runner, cmuxBin)

  if (!available) {
    throw new FloError(
      `CMUX_UNAVAILABLE`,
      `cmux is not reachable. Open cmux first and, if launching from outside cmux, ensure its socket mode allows external clients.`,
    )
  }
}

const loadFloContext = async (args: {
  context: FloCommandContext
  runner: CommandRunner
}): Promise<{
  config: Awaited<ReturnType<typeof loadConfig>>
  projects: FloProject[]
}> => {
  const config = await loadConfig(args.context.env)
  const projects = await discoverProjects({
    config,
    cwd: args.context.cwd,
    runner: args.runner,
  })

  return {
    config,
    projects,
  }
}

const inspectCmuxWorkspaces = async (args: {
  runner: CommandRunner
  cmuxBin: string
}): Promise<
  {
    workspaceId: string
    workspaceTitle: string
    sidebarState: Awaited<ReturnType<typeof getCmuxSidebarState>>
  }[]
> => {
  const workspaces = await listCmuxWorkspaces(args.runner, args.cmuxBin)
  const inspected = await Promise.allSettled(
    workspaces.map(async (workspace) => ({
      workspaceId: workspace.id,
      workspaceTitle: workspace.title,
      sidebarState: await getCmuxSidebarState({
        runner: args.runner,
        cmuxBin: args.cmuxBin,
        workspaceId: workspace.id,
      }),
    })),
  )

  return inspected.flatMap((result) => (result.status === `fulfilled` ? [result.value] : []))
}

const stampWorkspaceMetadata = async (args: {
  runner: CommandRunner
  cmuxBin: string
  workspaceId: string
  target: Pick<OpenTarget, `workspaceMetadata`>
}): Promise<void> => {
  await setCmuxStatus({
    runner: args.runner,
    cmuxBin: args.cmuxBin,
    workspaceId: args.workspaceId,
    key: `flo.identity`,
    value: args.target.workspaceMetadata.identity,
  })
  await setCmuxStatus({
    runner: args.runner,
    cmuxBin: args.cmuxBin,
    workspaceId: args.workspaceId,
    key: `flo.project`,
    value: args.target.workspaceMetadata.project,
  })
  await setCmuxStatus({
    runner: args.runner,
    cmuxBin: args.cmuxBin,
    workspaceId: args.workspaceId,
    key: `flo.kind`,
    value: args.target.workspaceMetadata.kind,
  })
}

const buildWorkspaceInitPlan = (target: OpenTarget): FloWorkspaceInitPlan => ({
  layout: target.workspaceLayout,
  editor: {
    sessionName: target.editorSessionName,
    command: target.editorBootstrapCommand,
  },
  ...(target.workspaceLayout.secondaryPane === `claude`
    ? {
        claude: {
          sessionName: target.claudeSessionName,
          command: target.claudeBootstrapCommand,
        },
      }
    : {}),
})

function buildWorkspacePlan(args: {
  target:
    | Pick<OpenTarget, `workspaceTitle` | `workspaceMetadata`>
    | Pick<FloEndedTarget, `workspaceTitle` | `workspaceMetadata`>
  cmuxAvailable: boolean
  existingWorkspace: { id: string; title: string } | null
  whenOpen: `open` | `end`
}): FloWorkspacePlan {
  return {
    title: args.target.workspaceTitle,
    identity: args.target.workspaceMetadata.identity,
    kind: args.target.workspaceMetadata.kind,
    action: !args.cmuxAvailable
      ? `cmux-unavailable`
      : args.existingWorkspace === null
        ? args.whenOpen === `open`
          ? `create-and-init`
          : `no-open-workspace`
        : args.whenOpen === `open`
          ? `focus-existing`
          : `close-existing`,
    ...(args.existingWorkspace === null
      ? {}
      : {
          existingWorkspace: {
            id: args.existingWorkspace.id,
            title: args.existingWorkspace.title,
          },
        }),
  }
}

const findWorkspaceForTarget = async (args: {
  runner: CommandRunner
  cmuxBin: string
  target: Pick<OpenTarget, `workspaceMetadata` | `checkout`>
}): Promise<{ id: string; title: string } | null> => {
  const workspaces = await inspectCmuxWorkspaces({
    runner: args.runner,
    cmuxBin: args.cmuxBin,
  })

  const identityMatch = workspaces.find(
    (workspace) =>
      statusEntryValue(workspace.sidebarState, `flo.identity`) ===
      args.target.workspaceMetadata.identity,
  )

  if (identityMatch !== undefined) {
    return {
      id: identityMatch.workspaceId,
      title: identityMatch.workspaceTitle,
    }
  }

  const checkoutMatch = workspaces.find(
    (workspace) =>
      workspace.sidebarState.cwd !== null &&
      resolve(workspace.sidebarState.cwd) === args.target.checkout.path,
  )

  if (checkoutMatch === undefined) {
    return null
  }

  return {
    id: checkoutMatch.workspaceId,
    title: checkoutMatch.workspaceTitle,
  }
}

const inspectTargetWorkspacePlan = async (args: {
  runner: CommandRunner
  cmuxBin: string
  target: Pick<OpenTarget, `workspaceTitle` | `workspaceMetadata` | `checkout`>
  whenOpen: `open` | `end`
}): Promise<{
  cmuxAvailable: boolean
  workspace: FloWorkspacePlan
}> => {
  const cmuxAvailable = await probeCmux(args.runner, args.cmuxBin)
  const existingWorkspace = !cmuxAvailable
    ? null
    : await findWorkspaceForTarget({
        runner: args.runner,
        cmuxBin: args.cmuxBin,
        target: args.target,
      })

  return {
    cmuxAvailable,
    workspace: buildWorkspacePlan({
      target: args.target,
      cmuxAvailable,
      existingWorkspace,
      whenOpen: args.whenOpen,
    }),
  }
}

const initializeWorkspace = async (args: {
  runner: CommandRunner
  cmuxBin: string
  workspaceId: string
  target: OpenTarget
}): Promise<void> => {
  await renameCmuxWorkspace(args.runner, args.cmuxBin, args.workspaceId, args.target.workspaceTitle)
  await stampWorkspaceMetadata({
    runner: args.runner,
    cmuxBin: args.cmuxBin,
    workspaceId: args.workspaceId,
    target: args.target,
  })
  await sendToCmuxWorkspace({
    runner: args.runner,
    cmuxBin: args.cmuxBin,
    workspaceId: args.workspaceId,
    text: args.target.editorBootstrapCommand,
  })

  if (args.target.workspaceLayout.secondaryPane === `claude`) {
    await newCmuxPane({
      runner: args.runner,
      cmuxBin: args.cmuxBin,
      workspaceId: args.workspaceId,
      direction:
        args.target.workspaceLayout.splitDirection === `bottom`
          ? `down`
          : args.target.workspaceLayout.splitDirection,
    })
    await sendToCmuxWorkspace({
      runner: args.runner,
      cmuxBin: args.cmuxBin,
      workspaceId: args.workspaceId,
      text: args.target.claudeBootstrapCommand,
    })

    if (args.target.workspaceLayout.focus === `editor`) {
      await selectLastCmuxPane(args.runner, args.cmuxBin, args.workspaceId)
    }
  }
}

const ensureWorkspace = async (args: {
  runner: CommandRunner
  cmuxBin: string
  target: OpenTarget
}): Promise<{ created: boolean; workspaceId: string }> => {
  const existingWorkspace = await findWorkspaceForTarget({
    runner: args.runner,
    cmuxBin: args.cmuxBin,
    target: args.target,
  })

  if (existingWorkspace !== null) {
    await stampWorkspaceMetadata({
      runner: args.runner,
      cmuxBin: args.cmuxBin,
      workspaceId: existingWorkspace.id,
      target: args.target,
    })
    await selectCmuxWorkspace(args.runner, args.cmuxBin, existingWorkspace.id)
    return {
      created: false,
      workspaceId: existingWorkspace.id,
    }
  }

  const workspace = await createCmuxWorkspace(args.runner, args.cmuxBin)
  await initializeWorkspace({
    runner: args.runner,
    cmuxBin: args.cmuxBin,
    workspaceId: workspace.id,
    target: args.target,
  })

  return {
    created: true,
    workspaceId: workspace.id,
  }
}

const resolveCurrentCheckout = (checkouts: FloCheckout[], cwd: string): FloCheckout => {
  const resolvedCwd = resolve(cwd)
  const matches = checkouts
    .filter(
      (checkout) => resolvedCwd === checkout.path || resolvedCwd.startsWith(`${checkout.path}/`),
    )
    .sort((left, right) => right.path.length - left.path.length)

  const checkout = matches[0]
  if (checkout === undefined) {
    throw new FloError(
      `CHECKOUT_CONTEXT_REQUIRED`,
      `No checkout matched the current directory. Run Flo inside a project checkout or pass an explicit selector.`,
    )
  }

  return checkout
}

const resolveBranchForSelector = async (args: {
  selector: StartSelector
  project: FloProject
  runner: CommandRunner
}): Promise<{ branch: string; issue?: StartTarget[`issue`] }> => {
  switch (args.selector.kind) {
    case `branch`:
      return { branch: args.selector.branch }
    case `github-issue`: {
      if (args.project.defaultSource !== `github` && !args.selector.explicit) {
        throw new FloError(
          `SOURCE_UNSUPPORTED`,
          `Numeric selectors require a GitHub-backed project. Configure a GitHub repo or use a branch selector.`,
        )
      }

      if (args.project.githubRepo === undefined) {
        throw new FloError(
          `GITHUB_REPO_REQUIRED`,
          `Project ${args.project.name} does not define a GitHub repo, so issue selectors cannot resolve.`,
        )
      }

      const issue = await fetchGitHubIssue(
        args.runner,
        args.project.githubRepo,
        args.selector.issueNumber,
      )
      return {
        branch: issueBranchName(issue),
        issue,
      }
    }
    case `linear-issue`:
      throw new FloError(`SOURCE_UNSUPPORTED`, `Linear selectors are not implemented in v1 yet.`)
    case `bead`:
      throw new FloError(`SOURCE_UNSUPPORTED`, `Bead selectors are not implemented in v1 yet.`)
  }
}

const resolveStartPlan = async (args: {
  context: FloCommandContext
  selector: string
  projectSelector?: string
  runner: CommandRunner
}): Promise<{
  config: Awaited<ReturnType<typeof loadConfig>>
  project: FloProject
  existingCheckout: FloCheckout | null
  plannedCheckout: FloCheckout
  issue?: StartTarget[`issue`]
}> => {
  const { config, projects } = await loadFloContext({
    context: args.context,
    runner: args.runner,
  })
  const project =
    args.projectSelector === undefined
      ? await requireCurrentProject({
          projects,
          cwd: args.context.cwd,
          runner: args.runner,
        })
      : resolveProjectSelector(projects, args.projectSelector)
  const parsedSelector = parseStartSelector(args.selector)
  const branchResolution = await resolveBranchForSelector({
    selector: parsedSelector,
    project,
    runner: args.runner,
  })
  const state = await listProjectState(args.runner, project)
  const existingCheckout =
    state.checkouts.find((checkout) => checkout.branch === branchResolution.branch) ?? null
  const plannedCheckout =
    existingCheckout ??
    ({
      path: planWorktreePath(project.worktreeRoot, branchResolution.branch),
      branch: branchResolution.branch,
      headSha: null,
      isMain: false,
    } satisfies FloCheckout)

  return {
    config,
    project,
    existingCheckout,
    plannedCheckout,
    ...(branchResolution.issue === undefined ? {} : { issue: branchResolution.issue }),
  }
}

const resolveEndTarget = async (args: {
  context: FloCommandContext
  selector?: string
  runner: CommandRunner
}): Promise<FloEndedTarget> => {
  const { config, projects } = await loadFloContext({
    context: args.context,
    runner: args.runner,
  })

  const resolveExplicitCheckout = async (
    project: FloProject,
    checkoutSelector: string | undefined,
  ): Promise<FloCheckout> => {
    const state = await listProjectState(args.runner, project)
    return resolveCheckoutSelector(state.checkouts, checkoutSelector)
  }

  let project: FloProject
  let checkout: FloCheckout

  if (args.selector === undefined) {
    project = await requireCurrentProject({
      projects,
      cwd: args.context.cwd,
      runner: args.runner,
    })
    checkout = resolveCurrentCheckout(
      (await listProjectState(args.runner, project)).checkouts,
      args.context.cwd,
    )
  } else if (args.selector.includes(`@`)) {
    const parsed = parseOpenSelector(args.selector)
    project = resolveProjectSelector(projects, parsed.projectSelector)
    checkout = await resolveExplicitCheckout(project, parsed.checkoutSelector)
  } else {
    project = await requireCurrentProject({
      projects,
      cwd: args.context.cwd,
      runner: args.runner,
    })
    const state = await listProjectState(args.runner, project)
    const parsedSelector = parseStartSelector(args.selector)
    const branchResolution = await resolveBranchForSelector({
      selector: parsedSelector,
      project,
      runner: args.runner,
    })
    checkout =
      state.checkouts.find((candidate) => candidate.branch === branchResolution.branch) ??
      (() => {
        throw new FloError(
          `CHECKOUT_NOT_FOUND`,
          `No active checkout matched selector "${args.selector}".`,
        )
      })()
  }

  if (checkout.isMain) {
    throw new FloError(
      `END_MAIN_CHECKOUT_FORBIDDEN`,
      `flo end only applies to feature checkouts. Use flo open to return to the main workspace.`,
    )
  }

  const target = await buildOpenTarget({
    project,
    checkout,
    runtime: config.runtime,
  })
  const cmuxAvailable = await probeCmux(args.runner, config.runtime.cmuxBin)
  const existingWorkspace = cmuxAvailable
    ? await findWorkspaceForTarget({
        runner: args.runner,
        cmuxBin: config.runtime.cmuxBin,
        target,
      })
    : null

  return {
    project: target.project,
    checkout: target.checkout,
    workspaceTitle: target.workspaceTitle,
    workspaceMetadata: target.workspaceMetadata,
    editorSessionName: target.editorSessionName,
    claudeSessionName: target.claudeSessionName,
    ...(existingWorkspace === null ? {} : { workspaceId: existingWorkspace.id }),
  }
}

export const normalizeSelector = (selector: string): { raw: string; value: string } => ({
  raw: selector,
  value: selector.trim(),
})

export const resolveOpenTarget = async (args: {
  context: FloCommandContext
  selector?: string
  dependencies?: FloRuntimeDependencies
}): Promise<OpenTarget> => {
  const dependencies = { ...defaultDependencies, ...args.dependencies }
  const { config, projects } = await loadFloContext({
    context: args.context,
    runner: dependencies.runner,
  })

  const project =
    args.selector === undefined
      ? await requireCurrentProject({
          projects,
          cwd: args.context.cwd,
          runner: dependencies.runner,
        })
      : resolveProjectSelector(projects, parseOpenSelector(args.selector).projectSelector)

  const state = await listProjectState(dependencies.runner, project)
  const openSelector = args.selector === undefined ? undefined : parseOpenSelector(args.selector)
  const checkout = resolveCheckoutSelector(state.checkouts, openSelector?.checkoutSelector)

  return buildOpenTarget({
    project,
    checkout,
    runtime: config.runtime,
  })
}

export const resolveStartTarget = async (args: {
  context: FloCommandContext
  selector: string
  projectSelector?: string
  dependencies?: FloRuntimeDependencies
}): Promise<StartTarget> => {
  const dependencies = { ...defaultDependencies, ...args.dependencies }
  const plan = await resolveStartPlan({
    context: args.context,
    selector: args.selector,
    ...(args.projectSelector === undefined ? {} : { projectSelector: args.projectSelector }),
    runner: dependencies.runner,
  })
  const target = await buildOpenTarget({
    project: plan.project,
    checkout: plan.plannedCheckout,
    runtime: plan.config.runtime,
  })

  return {
    ...target,
    createdCheckout: plan.existingCheckout === null,
    ...(plan.issue === undefined ? {} : { issue: plan.issue }),
  }
}

export const explainOpen = async (args: {
  context: FloCommandContext
  selector?: string
  last?: boolean
  dependencies?: FloRuntimeDependencies
}): Promise<FloExplainOpenResult> => {
  const dependencies = { ...defaultDependencies, ...args.dependencies }
  const config = await loadConfig(args.context.env)
  const target = args.last
    ? await openLastWorkspace({
        context: args.context,
        dryRun: true,
        dependencies,
      })
    : await resolveOpenTarget({
        context: args.context,
        ...(args.selector === undefined ? {} : { selector: args.selector }),
        dependencies,
      })
  const plan = await inspectTargetWorkspacePlan({
    runner: dependencies.runner,
    cmuxBin: config.runtime.cmuxBin,
    target,
    whenOpen: `open`,
  })

  return {
    command: `open`,
    ...(args.selector === undefined ? {} : { selector: args.selector }),
    cmuxAvailable: plan.cmuxAvailable,
    project: {
      name: target.project.name,
      path: target.project.path,
    },
    checkout: {
      path: target.checkout.path,
      branch: target.checkout.branch,
      isMain: target.checkout.isMain,
    },
    workspace: plan.workspace,
    init: buildWorkspaceInitPlan(target),
  }
}

export const previewInitOpen = async (args: {
  context: FloCommandContext
  selector?: string
  last?: boolean
  dependencies?: FloRuntimeDependencies
}): Promise<FloInitPreviewResult> => {
  const explained = await explainOpen(args)

  return {
    command: `open`,
    ...(explained.selector === undefined ? {} : { selector: explained.selector }),
    project: explained.project,
    checkout: explained.checkout,
    workspace: explained.workspace,
    init: explained.init,
    appliesNow: explained.workspace.action === `create-and-init`,
    appliesWhen: `create-and-init`,
  }
}

export const explainStart = async (args: {
  context: FloCommandContext
  selector: string
  projectSelector?: string
  dependencies?: FloRuntimeDependencies
}): Promise<FloExplainStartResult> => {
  const dependencies = { ...defaultDependencies, ...args.dependencies }
  const config = await loadConfig(args.context.env)
  const target = await resolveStartTarget({
    context: args.context,
    selector: args.selector,
    ...(args.projectSelector === undefined ? {} : { projectSelector: args.projectSelector }),
    dependencies,
  })
  const plan = await inspectTargetWorkspacePlan({
    runner: dependencies.runner,
    cmuxBin: config.runtime.cmuxBin,
    target,
    whenOpen: `open`,
  })

  return {
    command: `start`,
    selector: args.selector,
    ...(args.projectSelector === undefined ? {} : { projectSelector: args.projectSelector }),
    cmuxAvailable: plan.cmuxAvailable,
    project: {
      name: target.project.name,
      path: target.project.path,
    },
    checkout: {
      path: target.checkout.path,
      branch: target.checkout.branch,
      isMain: target.checkout.isMain,
    },
    workspace: plan.workspace,
    init: buildWorkspaceInitPlan(target),
    createdCheckout: target.createdCheckout,
    ...(target.issue === undefined ? {} : { issue: target.issue }),
  }
}

export const previewInitStart = async (args: {
  context: FloCommandContext
  selector: string
  projectSelector?: string
  dependencies?: FloRuntimeDependencies
}): Promise<FloInitPreviewResult> => {
  const explained = await explainStart(args)

  return {
    command: `start`,
    selector: explained.selector,
    ...(explained.projectSelector === undefined
      ? {}
      : { projectSelector: explained.projectSelector }),
    project: explained.project,
    checkout: explained.checkout,
    workspace: explained.workspace,
    init: explained.init,
    appliesNow: explained.workspace.action === `create-and-init`,
    appliesWhen: `create-and-init`,
    ...(explained.issue === undefined ? {} : { issue: explained.issue }),
  }
}

export const explainEnd = async (args: {
  context: FloCommandContext
  selector?: string
  force?: boolean
  openMain?: boolean
  dependencies?: FloRuntimeDependencies
}): Promise<FloExplainEndResult> => {
  const dependencies = { ...defaultDependencies, ...args.dependencies }
  const config = await loadConfig(args.context.env)
  const target = await resolveEndTarget({
    context: args.context,
    ...(args.selector === undefined ? {} : { selector: args.selector }),
    runner: dependencies.runner,
  })
  const plan = await inspectTargetWorkspacePlan({
    runner: dependencies.runner,
    cmuxBin: config.runtime.cmuxBin,
    target,
    whenOpen: `end`,
  })
  const reopenMainWorkspace =
    args.openMain === true
      ? await explainOpen({
          context: {
            cwd: target.project.path,
            env: args.context.env,
          },
          selector: target.project.name,
          dependencies,
        }).then((result) => result.workspace)
      : undefined

  return {
    command: `end`,
    ...(args.selector === undefined ? {} : { selector: args.selector }),
    cmuxAvailable: plan.cmuxAvailable,
    force: args.force === true,
    openMain: args.openMain === true,
    project: {
      name: target.project.name,
      path: target.project.path,
    },
    checkout: {
      path: target.checkout.path,
      branch: target.checkout.branch,
      isMain: target.checkout.isMain,
    },
    workspace: plan.workspace,
    sessions: {
      editor: target.editorSessionName,
      claude: target.claudeSessionName,
    },
    removesCheckout: true,
    dirtyCheckoutAllowed: args.force === true,
    ...(reopenMainWorkspace === undefined ? {} : { reopensMainWorkspace: reopenMainWorkspace }),
  }
}

export const openWorkspace = async (args: {
  context: FloCommandContext
  selector?: string
  dryRun?: boolean
  dependencies?: FloRuntimeDependencies
}): Promise<OpenTarget & { createdWorkspace?: boolean; workspaceId?: string }> => {
  const dependencies = { ...defaultDependencies, ...args.dependencies }
  const config = await loadConfig(args.context.env)
  const target = await resolveOpenTarget({
    context: args.context,
    ...(args.selector === undefined ? {} : { selector: args.selector }),
    dependencies,
  })

  if (args.dryRun) {
    return target
  }

  await ensureCmuxAvailable(dependencies.runner, config.runtime.cmuxBin)
  const workspace = await ensureWorkspace({
    runner: dependencies.runner,
    cmuxBin: config.runtime.cmuxBin,
    target,
  })
  await touchWorkspaceState({
    env: args.context.env,
    target,
    action: `open`,
  })

  return {
    ...target,
    createdWorkspace: workspace.created,
    workspaceId: workspace.workspaceId,
  }
}

export const openLastWorkspace = async (args: {
  context: FloCommandContext
  dryRun?: boolean
  dependencies?: FloRuntimeDependencies
}): Promise<OpenTarget & { createdWorkspace?: boolean; workspaceId?: string }> => {
  const recent = await listRecentWork(args)
  const item = recent.items[0]
  if (item === undefined) {
    throw new FloError(`RECENT_WORK_EMPTY`, `Flo has no recent work to reopen yet.`)
  }

  return openWorkspace({
    context: args.context,
    selector: item.selector,
    ...(args.dryRun === undefined ? {} : { dryRun: args.dryRun }),
    ...(args.dependencies === undefined ? {} : { dependencies: args.dependencies }),
  })
}

export const startWork = async (args: {
  context: FloCommandContext
  selector: string
  projectSelector?: string
  dryRun?: boolean
  dependencies?: FloRuntimeDependencies
}): Promise<StartTarget & { createdWorkspace?: boolean; workspaceId?: string }> => {
  const dependencies = { ...defaultDependencies, ...args.dependencies }
  const plan = await resolveStartPlan({
    context: args.context,
    selector: args.selector,
    ...(args.projectSelector === undefined ? {} : { projectSelector: args.projectSelector }),
    runner: dependencies.runner,
  })

  const checkout =
    !args.dryRun && plan.existingCheckout === null
      ? ({
          path: await createWorktree(
            dependencies.runner,
            plan.project.path,
            plan.project.worktreeRoot,
            plan.plannedCheckout.branch ?? basename(plan.plannedCheckout.path),
          ),
          branch: plan.plannedCheckout.branch,
          headSha: null,
          isMain: false,
        } satisfies FloCheckout)
      : (plan.existingCheckout ?? plan.plannedCheckout)

  const target = await buildOpenTarget({
    project: plan.project,
    checkout,
    runtime: plan.config.runtime,
  })

  if (args.dryRun) {
    return {
      ...target,
      createdCheckout: plan.existingCheckout === null,
      ...(plan.issue === undefined ? {} : { issue: plan.issue }),
    }
  }

  await ensureCmuxAvailable(dependencies.runner, plan.config.runtime.cmuxBin)
  const workspace = await ensureWorkspace({
    runner: dependencies.runner,
    cmuxBin: plan.config.runtime.cmuxBin,
    target,
  })
  await touchWorkspaceState({
    env: args.context.env,
    target,
    action: `start`,
  })

  return {
    ...target,
    createdCheckout: plan.existingCheckout === null,
    createdWorkspace: workspace.created,
    workspaceId: workspace.workspaceId,
    ...(plan.issue === undefined ? {} : { issue: plan.issue }),
  }
}

export const getFloContext = async (args: {
  context: FloCommandContext
  dependencies?: FloRuntimeDependencies
}): Promise<FloContextResult> => {
  const dependencies = { ...defaultDependencies, ...args.dependencies }
  const { config, projects } = await loadFloContext({
    context: args.context,
    runner: dependencies.runner,
  })
  const project = await requireCurrentProject({
    projects,
    cwd: args.context.cwd,
    runner: dependencies.runner,
  })
  const state = await listProjectState(dependencies.runner, project)
  const checkout = resolveCurrentCheckout(state.checkouts, args.context.cwd)
  const target = await buildOpenTarget({
    project,
    checkout,
    runtime: config.runtime,
  })
  const issueNumber = parseIssueNumberFromBranch(checkout.branch)

  if (issueNumber === null || project.githubRepo === undefined) {
    return target
  }

  const issue = await fetchGitHubIssue(dependencies.runner, project.githubRepo, issueNumber)
  return {
    ...target,
    issue,
  }
}

export const formatFloContextEnv = (context: FloContextResult): string => {
  const entries: Array<readonly [string, string]> = [
    [`FLO_PROJECT_NAME`, context.project.name] as const,
    [`FLO_PROJECT_PATH`, context.project.path] as const,
    [`FLO_CHECKOUT_PATH`, context.checkout.path] as const,
    [`FLO_WORKSPACE_TITLE`, context.workspaceTitle] as const,
    [`FLO_WORKSPACE_IDENTITY`, context.workspaceMetadata.identity] as const,
    [`FLO_WORKSPACE_KIND`, context.workspaceMetadata.kind] as const,
    ...(context.checkout.branch === null
      ? []
      : [[`FLO_CHECKOUT_BRANCH`, context.checkout.branch] as const]),
    ...(context.issue === undefined
      ? []
      : [
          [`FLO_ISSUE_NUMBER`, String(context.issue.number)] as const,
          [`FLO_ISSUE_TITLE`, context.issue.title] as const,
          [`FLO_ISSUE_URL`, context.issue.url] as const,
          [`FLO_ISSUE_STATE`, context.issue.state] as const,
          [`FLO_ISSUE_REPO`, context.issue.repo] as const,
        ]),
  ]

  return entries.map(([key, value]) => `export ${key}=${shellQuote(value)}`).join(`\n`)
}

export const statusFlo = async (args: {
  context: FloCommandContext
  dependencies?: FloRuntimeDependencies
}): Promise<FloStatusResult> => {
  const dependencies = { ...defaultDependencies, ...args.dependencies }
  const { config, projects } = await loadFloContext({
    context: args.context,
    runner: dependencies.runner,
  })
  const currentProject = await findProjectForCwd({
    projects,
    cwd: args.context.cwd,
    runner: dependencies.runner,
  })

  if (currentProject === null) {
    return {
      currentDirectory: resolve(args.context.cwd),
      cmuxAvailable: await probeCmux(dependencies.runner, config.runtime.cmuxBin),
      currentProject: null,
      currentCheckout: null,
      expectedWorkspace: null,
      activeWorkspace: null,
    }
  }

  const currentCheckout = resolveCurrentCheckout(
    (await listProjectState(dependencies.runner, currentProject)).checkouts,
    args.context.cwd,
  )
  const target = await buildOpenTarget({
    project: currentProject,
    checkout: currentCheckout,
    runtime: config.runtime,
  })
  const cmuxAvailable = await probeCmux(dependencies.runner, config.runtime.cmuxBin)
  const activeWorkspace = cmuxAvailable
    ? await findWorkspaceForTarget({
        runner: dependencies.runner,
        cmuxBin: config.runtime.cmuxBin,
        target,
      })
    : null
  const issueNumber = parseIssueNumberFromBranch(currentCheckout.branch)
  const issue =
    issueNumber === null || currentProject.githubRepo === undefined
      ? undefined
      : await fetchGitHubIssue(dependencies.runner, currentProject.githubRepo, issueNumber)

  return {
    currentDirectory: resolve(args.context.cwd),
    cmuxAvailable,
    currentProject: {
      name: currentProject.name,
      path: currentProject.path,
    },
    currentCheckout: {
      path: currentCheckout.path,
      branch: currentCheckout.branch,
      isMain: currentCheckout.isMain,
    },
    expectedWorkspace: {
      title: target.workspaceTitle,
      identity: target.workspaceMetadata.identity,
    },
    activeWorkspace:
      activeWorkspace === null
        ? null
        : {
            id: activeWorkspace.id,
            title: activeWorkspace.title,
          },
    ...(issue === undefined ? {} : { issue }),
  }
}

export const endWork = async (args: {
  context: FloCommandContext
  selector?: string
  dryRun?: boolean
  force?: boolean
  openMain?: boolean
  dependencies?: FloRuntimeDependencies
}): Promise<FloEndResult> => {
  const dependencies = { ...defaultDependencies, ...args.dependencies }
  const config = await loadConfig(args.context.env)
  const target = await resolveEndTarget({
    context: args.context,
    ...(args.selector === undefined ? {} : { selector: args.selector }),
    runner: dependencies.runner,
  })

  if (!args.force && (await isCheckoutDirty(dependencies.runner, target.checkout.path))) {
    throw new FloError(
      `CHECKOUT_DIRTY`,
      `Checkout ${target.checkout.path} has uncommitted changes. Commit or stash them first, or pass --force.`,
    )
  }

  const cmuxAvailable = await probeCmux(dependencies.runner, config.runtime.cmuxBin)
  const closedWorkspace = !args.dryRun && cmuxAvailable && target.workspaceId !== undefined
  const workspaceId = target.workspaceId
  if (closedWorkspace && workspaceId !== undefined) {
    await closeCmuxWorkspace(dependencies.runner, config.runtime.cmuxBin, workspaceId)
  }

  const killedEditorSession = args.dryRun
    ? false
    : await killZmxSession(dependencies.runner, config.runtime.zmxBin, target.editorSessionName)
  const killedClaudeSession = args.dryRun
    ? false
    : await killZmxSession(dependencies.runner, config.runtime.zmxBin, target.claudeSessionName)

  if (!args.dryRun) {
    await removeWorktree({
      runner: dependencies.runner,
      repositoryPath: target.project.path,
      checkoutPath: target.checkout.path,
      ...(args.force === undefined ? {} : { force: args.force }),
    })
  }

  const reopenedMainWorkspace =
    args.openMain === true && !args.dryRun
      ? await openWorkspace({
          context: {
            cwd: target.project.path,
            env: args.context.env,
          },
          selector: target.project.name,
          dependencies,
        })
      : null

  return {
    ...target,
    closedWorkspace,
    removedCheckout: !args.dryRun,
    killedEditorSession,
    killedClaudeSession,
    ...(reopenedMainWorkspace === null
      ? {}
      : {
          reopenedMainWorkspace: true,
          ...(reopenedMainWorkspace.workspaceId === undefined
            ? {}
            : { reopenedMainWorkspaceId: reopenedMainWorkspace.workspaceId }),
        }),
  }
}

export const pruneFloState = async (args: {
  context: FloCommandContext
  dryRun?: boolean
  dependencies?: FloRuntimeDependencies
}): Promise<FloPruneResult> => {
  const dependencies = { ...defaultDependencies, ...args.dependencies }
  const { config, projects } = await loadFloContext({
    context: args.context,
    runner: dependencies.runner,
  })
  const activeIdentities = new Set<string>()
  const activeCheckoutPaths = new Set<string>()
  const projectResults = await Promise.all(
    projects.map(async (project): Promise<FloPruneProjectResult> => {
      if (!args.dryRun) {
        await pruneWorktrees(dependencies.runner, project.path)
      }

      const state = await listProjectState(dependencies.runner, project)
      const targets = await Promise.all(
        state.checkouts.map((checkout) =>
          buildOpenTarget({
            project,
            checkout,
            runtime: config.runtime,
          }),
        ),
      )

      for (const target of targets) {
        activeIdentities.add(target.workspaceMetadata.identity)
        activeCheckoutPaths.add(target.checkout.path)
      }

      return {
        name: project.name,
        path: project.path,
      }
    }),
  )

  const cmuxAvailable = await probeCmux(dependencies.runner, config.runtime.cmuxBin)
  if (!cmuxAvailable) {
    return {
      projects: projectResults,
      closedWorkspaces: [],
      prunedRecents: await pruneWorkspaceState({
        env: args.context.env,
        activeWorkspaceIdentities: activeIdentities,
        activeCheckoutPaths: activeCheckoutPaths,
        ...(args.dryRun === undefined ? {} : { dryRun: args.dryRun }),
      }).then((records) =>
        records.map((record) => ({
          workspaceIdentity: record.workspaceIdentity,
          workspaceTitle: record.workspaceTitle,
          checkoutPath: record.checkoutPath,
        })),
      ),
    }
  }

  const inspectedWorkspaces = await inspectCmuxWorkspaces({
    runner: dependencies.runner,
    cmuxBin: config.runtime.cmuxBin,
  })

  const closedWorkspaces = (
    await Promise.all(
      inspectedWorkspaces.map(async (workspace): Promise<FloPruneWorkspaceResult | null> => {
        const identity = statusEntryValue(workspace.sidebarState, `flo.identity`) ?? null
        const checkoutPath =
          workspace.sidebarState.cwd === null ? null : resolve(workspace.sidebarState.cwd)
        const shouldClose =
          identity !== null && (!activeIdentities.has(identity) || checkoutPath === null)

        if (!shouldClose) {
          return null
        }

        const sessionStemBase = sanitizeIdentifier(
          `${config.runtime.workspacePrefix}-${statusEntryValue(workspace.sidebarState, `flo.project`) ?? `workspace`}-${statusEntryValue(workspace.sidebarState, `flo.kind`) ?? `feature`}-${identity}`,
        )
        const editorSessionName = `${sessionStemBase}-editor`
        const claudeSessionName = `${sessionStemBase}-claude`

        if (!args.dryRun) {
          await closeCmuxWorkspace(
            dependencies.runner,
            config.runtime.cmuxBin,
            workspace.workspaceId,
          )
        }

        const [killedEditorSession, killedClaudeSession] = args.dryRun
          ? [false, false]
          : await Promise.all([
              killZmxSession(dependencies.runner, config.runtime.zmxBin, editorSessionName),
              killZmxSession(dependencies.runner, config.runtime.zmxBin, claudeSessionName),
            ])

        return {
          workspaceId: workspace.workspaceId,
          workspaceTitle: workspace.workspaceTitle,
          identity,
          checkoutPath,
          closedWorkspace: !args.dryRun,
          killedEditorSession,
          killedClaudeSession,
        }
      }),
    )
  ).filter((workspace) => workspace !== null)

  const prunedRecents = await pruneWorkspaceState({
    env: args.context.env,
    activeWorkspaceIdentities: activeIdentities,
    activeCheckoutPaths: activeCheckoutPaths,
    ...(args.dryRun === undefined ? {} : { dryRun: args.dryRun }),
  })

  return {
    projects: projectResults,
    closedWorkspaces,
    prunedRecents: prunedRecents.map((record) => ({
      workspaceIdentity: record.workspaceIdentity,
      workspaceTitle: record.workspaceTitle,
      checkoutPath: record.checkoutPath,
    })),
  }
}

export const listFloState = async (args: {
  context: FloCommandContext
  projectSelector?: string
  openOnly?: boolean
  dependencies?: FloRuntimeDependencies
}): Promise<FloListResult> => {
  const dependencies = { ...defaultDependencies, ...args.dependencies }
  const { config, projects: discoveredProjects } = await loadFloContext({
    context: args.context,
    runner: dependencies.runner,
  })
  const projects =
    args.projectSelector === undefined
      ? discoveredProjects
      : [resolveProjectSelector(discoveredProjects, args.projectSelector)]
  const cmuxAvailable = await probeCmux(dependencies.runner, config.runtime.cmuxBin)
  const inspectedWorkspaces = cmuxAvailable
    ? await inspectCmuxWorkspaces({
        runner: dependencies.runner,
        cmuxBin: config.runtime.cmuxBin,
      })
    : []
  const persistedState = await loadState(args.context.env)
  const recentByIdentity = new Map(
    persistedState.workspaces.map((workspace) => [
      workspace.workspaceIdentity,
      workspace.lastOpenedAt,
    ]),
  )
  const openWorkspaceIdentities = new Set(
    inspectedWorkspaces.flatMap((workspace) => {
      const identity = statusEntryValue(workspace.sidebarState, `flo.identity`)
      return identity === undefined ? [] : [identity]
    }),
  )
  const openWorkspacePaths = new Set(
    inspectedWorkspaces.flatMap((workspace) => {
      const cwd = workspace.sidebarState.cwd
      return cwd === null ? [] : [resolve(cwd)]
    }),
  )

  const projectResults = (
    await Promise.all(
      projects.map(async (project): Promise<FloListProject> => {
        const state = await listProjectState(dependencies.runner, project)
        const checkoutTargets = await Promise.all(
          state.checkouts.map((checkout) =>
            buildOpenTarget({
              project,
              checkout,
              runtime: config.runtime,
            }),
          ),
        )

        return {
          name: project.name,
          path: project.path,
          ...(project.defaultSource === undefined ? {} : { defaultSource: project.defaultSource }),
          ...(project.githubRepo === undefined ? {} : { githubRepo: project.githubRepo }),
          checkouts: checkoutTargets
            .map((target) => {
              const lastOpenedAt = recentByIdentity.get(target.workspaceMetadata.identity)

              return {
                path: target.checkout.path,
                branch: target.checkout.branch,
                isMain: target.checkout.isMain,
                workspaceIdentity: target.workspaceMetadata.identity,
                workspaceTitle: target.workspaceTitle,
                ...(lastOpenedAt === undefined ? {} : { lastOpenedAt }),
                workspaceOpen: cmuxAvailable
                  ? openWorkspaceIdentities.has(target.workspaceMetadata.identity) ||
                    openWorkspacePaths.has(target.checkout.path)
                  : null,
              }
            })
            .sort(compareCheckoutsForDisplay),
        }
      }),
    )
  )
    .map((project) => ({
      ...project,
      checkouts: args.openOnly
        ? project.checkouts.filter((checkout) => checkout.workspaceOpen === true)
        : project.checkouts,
    }))
    .filter((project) => project.checkouts.length > 0)

  return {
    configPath: config.configPath,
    configExists: config.exists,
    cmuxAvailable,
    projects: projectResults.sort(compareProjectsForDisplay),
  }
}

export const doctorFlo = async (args: {
  context: FloCommandContext
  dependencies?: FloRuntimeDependencies
}): Promise<FloDoctorResult> => {
  const dependencies = { ...defaultDependencies, ...args.dependencies }
  const { config, projects } = await loadFloContext({
    context: args.context,
    runner: dependencies.runner,
  })
  const currentProject = await findProjectForCwd({
    projects,
    cwd: args.context.cwd,
    runner: dependencies.runner,
  })
  const currentCheckout =
    currentProject === null
      ? null
      : resolveCurrentCheckout(
          (await listProjectState(dependencies.runner, currentProject)).checkouts,
          args.context.cwd,
        )
  const shouldProbeGitHub = projects.some(
    (project) => project.defaultSource === `github` || project.githubRepo !== undefined,
  )
  const commands = await Promise.all([
    probeConfiguredCommand({
      runner: dependencies.runner,
      shellCommand: config.runtime.shellCommand,
      key: `git`,
      configured: `git`,
    }),
    probeConfiguredCommand({
      runner: dependencies.runner,
      shellCommand: config.runtime.shellCommand,
      key: `cmux`,
      configured: config.runtime.cmuxBin,
    }),
    probeConfiguredCommand({
      runner: dependencies.runner,
      shellCommand: config.runtime.shellCommand,
      key: `zmx`,
      configured: config.runtime.zmxBin,
    }),
    probeConfiguredCommand({
      runner: dependencies.runner,
      shellCommand: config.runtime.shellCommand,
      key: `fzf`,
      configured: config.runtime.fzfBin,
    }),
    probeConfiguredCommand({
      runner: dependencies.runner,
      shellCommand: config.runtime.shellCommand,
      key: `claude`,
      configured: config.runtime.claudeCommand,
    }),
    probeConfiguredCommand({
      runner: dependencies.runner,
      shellCommand: config.runtime.shellCommand,
      key: `editor`,
      configured: config.runtime.editorCommand,
    }),
    ...(shouldProbeGitHub
      ? [
          probeConfiguredCommand({
            runner: dependencies.runner,
            shellCommand: config.runtime.shellCommand,
            key: `gh`,
            configured: `gh`,
          }),
        ]
      : []),
  ])

  return {
    configPath: config.configPath,
    configExists: config.exists,
    currentDirectory: resolve(args.context.cwd),
    cmuxAvailable: await probeCmux(dependencies.runner, config.runtime.cmuxBin),
    currentProject:
      currentProject === null
        ? null
        : {
            name: currentProject.name,
            path: currentProject.path,
          },
    currentCheckout:
      currentCheckout === null
        ? null
        : {
            path: currentCheckout.path,
            branch: currentCheckout.branch,
            isMain: currentCheckout.isMain,
          },
    commands,
  }
}

export const initConfig = async (args: {
  context: FloCommandContext
  force?: boolean
  dependencies?: FloRuntimeDependencies
}): Promise<FloConfigInitResult> => {
  const dependencies = { ...defaultDependencies, ...args.dependencies }
  const { config, projects } = await loadFloContext({
    context: args.context,
    runner: dependencies.runner,
  })
  const currentProject = await findProjectForCwd({
    projects,
    cwd: args.context.cwd,
    runner: dependencies.runner,
  })

  if (config.exists && !args.force) {
    return {
      configPath: config.configPath,
      configExists: true,
      wroteConfig: false,
      ...(currentProject === null
        ? {}
        : {
            project: {
              name: currentProject.name,
              path: currentProject.path,
              ...(currentProject.githubRepo === undefined
                ? {}
                : { githubRepo: currentProject.githubRepo }),
            },
          }),
    }
  }

  const discoveryRoot =
    currentProject === null ? resolve(args.context.cwd) : dirname(currentProject.path)
  const nextConfig = {
    discovery: {
      roots: [discoveryRoot],
    },
    projects:
      currentProject === null
        ? []
        : [
            {
              name: currentProject.name,
              path: currentProject.path,
              ...(currentProject.defaultSource === undefined
                ? {}
                : { defaultSource: currentProject.defaultSource }),
              ...(currentProject.githubRepo === undefined
                ? {}
                : { github: { repo: currentProject.githubRepo } }),
            },
          ],
  }

  await makeDirectoryRecursive(dirname(config.configPath))
  await writeFileString(config.configPath, `${JSON.stringify(nextConfig, null, 2)}\n`)

  return {
    configPath: config.configPath,
    configExists: config.exists,
    wroteConfig: true,
    ...(currentProject === null
      ? {}
      : {
          project: {
            name: currentProject.name,
            path: currentProject.path,
            ...(currentProject.githubRepo === undefined
              ? {}
              : { githubRepo: currentProject.githubRepo }),
          },
        }),
  }
}

export const launchInteractive = async (args: {
  context: FloCommandContext
  dryRun?: boolean
  dependencies?: FloRuntimeDependencies
}): Promise<OpenTarget | null> => {
  const dependencies = { ...defaultDependencies, ...args.dependencies }
  const state = await listFloState(args)

  const items: LauncherItem[] = state.projects.flatMap((project) =>
    project.checkouts.map((checkout) => ({
      selector: checkout.isMain
        ? project.name
        : `${project.name}@${checkout.branch ?? basename(checkout.path)}`,
      label: checkout.isMain
        ? `${project.name}  [main]`
        : `${project.name}  [${checkout.branch ?? basename(checkout.path)}]`,
      path: checkout.path,
    })),
  )

  const selection = await runFzf({
    runner: dependencies.runner,
    fzfBin: (await loadConfig(args.context.env)).runtime.fzfBin,
    items,
  })

  if (selection === null) {
    return null
  }

  return resolveOpenTarget({
    context: args.context,
    selector: selection.selector,
    dependencies,
  })
}

export const listRecentWork = async (args: {
  context: FloCommandContext
  projectSelector?: string
  limit?: number
  dependencies?: FloRuntimeDependencies
}): Promise<FloRecentResult> => {
  const state = await listFloState({
    context: args.context,
    ...(args.projectSelector === undefined ? {} : { projectSelector: args.projectSelector }),
    ...(args.dependencies === undefined ? {} : { dependencies: args.dependencies }),
  })
  const persistedState = await loadState(args.context.env)
  const checkoutByIdentity = new Map<
    string,
    {
      selector: string
      projectName: string
      checkoutPath: string
      branch: string | null
      isMain: boolean
      workspaceIdentity: string
      workspaceTitle: string
      workspaceOpen: boolean | null
    }
  >()

  for (const project of state.projects) {
    for (const checkout of project.checkouts) {
      checkoutByIdentity.set(checkout.workspaceIdentity, {
        selector: checkout.isMain
          ? project.name
          : `${project.name}@${checkout.branch ?? basename(checkout.path)}`,
        projectName: project.name,
        checkoutPath: checkout.path,
        branch: checkout.branch,
        isMain: checkout.isMain,
        workspaceIdentity: checkout.workspaceIdentity,
        workspaceTitle: checkout.workspaceTitle,
        workspaceOpen: checkout.workspaceOpen,
      })
    }
  }

  const items = persistedState.workspaces.flatMap((workspace): FloRecentItem[] => {
    const activeCheckout = checkoutByIdentity.get(workspace.workspaceIdentity)
    if (activeCheckout === undefined) {
      return []
    }

    return [
      {
        ...activeCheckout,
        lastOpenedAt: workspace.lastOpenedAt,
        lastAction: workspace.lastAction,
      },
    ]
  })

  return {
    cmuxAvailable: state.cmuxAvailable,
    items: args.limit === undefined ? items : items.slice(0, args.limit),
  }
}
