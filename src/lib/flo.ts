import { basename, resolve } from 'pathe'

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
import { realPath } from '#lib/filesystem'
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
import { sanitizeIdentifier, shellQuote } from '#lib/strings'
import type {
  FloCheckout,
  FloCommandContext,
  FloContextResult,
  FloDoctorCommand,
  FloDoctorResult,
  FloEndResult,
  FloEndedTarget,
  FloListProject,
  FloListResult,
  FloProject,
  FloPruneProjectResult,
  FloPruneResult,
  FloPruneWorkspaceResult,
  FloWorkspaceKind,
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
      kind: workspaceKind(normalizedCheckout),
    },
    editorSessionName: `${stem}-editor`,
    claudeSessionName: `${stem}-claude`,
    editorBootstrapCommand: buildEditorBootstrapCommand({
      zmxBin: args.runtime.zmxBin,
      shellCommand: args.runtime.shellCommand,
      sessionName: `${stem}-editor`,
      cwd: normalizedCheckout.path,
      editorCommand: args.runtime.editorCommand,
    }),
    claudeBootstrapCommand: buildClaudeBootstrapCommand({
      zmxBin: args.runtime.zmxBin,
      shellCommand: args.runtime.shellCommand,
      sessionName: `${stem}-claude`,
      cwd: normalizedCheckout.path,
      claudeCommand: args.runtime.claudeCommand,
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
  await newCmuxPane({
    runner: args.runner,
    cmuxBin: args.cmuxBin,
    workspaceId: args.workspaceId,
    direction: `right`,
  })
  await sendToCmuxWorkspace({
    runner: args.runner,
    cmuxBin: args.cmuxBin,
    workspaceId: args.workspaceId,
    text: args.target.claudeBootstrapCommand,
  })
  await selectLastCmuxPane(args.runner, args.cmuxBin, args.workspaceId)
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

  return {
    ...target,
    createdWorkspace: workspace.created,
    workspaceId: workspace.workspaceId,
  }
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

export const endWork = async (args: {
  context: FloCommandContext
  selector?: string
  dryRun?: boolean
  force?: boolean
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

  return {
    ...target,
    closedWorkspace,
    removedCheckout: !args.dryRun,
    killedEditorSession,
    killedClaudeSession,
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

  return {
    projects: projectResults,
    closedWorkspaces,
  }
}

export const listFloState = async (args: {
  context: FloCommandContext
  dependencies?: FloRuntimeDependencies
}): Promise<FloListResult> => {
  const dependencies = { ...defaultDependencies, ...args.dependencies }
  const { config, projects } = await loadFloContext({
    context: args.context,
    runner: dependencies.runner,
  })
  const cmuxAvailable = await probeCmux(dependencies.runner, config.runtime.cmuxBin)
  const inspectedWorkspaces = cmuxAvailable
    ? await inspectCmuxWorkspaces({
        runner: dependencies.runner,
        cmuxBin: config.runtime.cmuxBin,
      })
    : []
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

  const projectResults = await Promise.all(
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
        checkouts: checkoutTargets.map((target) => ({
          path: target.checkout.path,
          branch: target.checkout.branch,
          isMain: target.checkout.isMain,
          workspaceIdentity: target.workspaceMetadata.identity,
          workspaceTitle: target.workspaceTitle,
          workspaceOpen: cmuxAvailable
            ? openWorkspaceIdentities.has(target.workspaceMetadata.identity) ||
              openWorkspacePaths.has(target.checkout.path)
            : null,
        })),
      }
    }),
  )

  return {
    configPath: config.configPath,
    configExists: config.exists,
    cmuxAvailable,
    projects: projectResults,
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
