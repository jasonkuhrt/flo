import { basename } from 'node:path'

import {
  createCmuxWorkspace,
  listCmuxWorkspaces,
  probeCmux,
  renameCmuxWorkspace,
  selectCmuxWorkspace,
  sendToCmuxWorkspace,
} from '#lib/cmux'
import { loadConfig } from '#lib/config'
import { FloError } from '#lib/errors'
import { runFzf, type LauncherItem } from '#lib/fzf'
import {
  buildEditorBootstrapCommand,
  createWorktree,
  fetchGitHubIssue,
  issueBranchName,
  planWorktreePath,
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
import { sanitizeIdentifier } from '#lib/strings'
import type {
  FloCheckout,
  FloCommandContext,
  FloListProject,
  FloListResult,
  FloProject,
  OpenTarget,
  StartSelector,
  StartTarget,
} from '#lib/types'

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

const editorSessionName = (prefix: string, project: FloProject, checkout: FloCheckout): string =>
  sanitizeIdentifier(
    checkout.isMain
      ? `${prefix}-${project.name}-main-editor`
      : `${prefix}-${project.name}-${checkout.branch ?? basename(checkout.path)}-editor`,
  )

const buildOpenTarget = (args: {
  project: FloProject
  checkout: FloCheckout
  runtime: Awaited<ReturnType<typeof loadConfig>>[`runtime`]
}): OpenTarget => {
  const title = workspaceTitle(args.runtime.workspacePrefix, args.project, args.checkout)
  const sessionName = editorSessionName(args.runtime.workspacePrefix, args.project, args.checkout)

  return {
    project: args.project,
    checkout: args.checkout,
    workspaceTitle: title,
    editorSessionName: sessionName,
    editorBootstrapCommand: buildEditorBootstrapCommand({
      zmxBin: args.runtime.zmxBin,
      shellCommand: args.runtime.shellCommand,
      sessionName,
      cwd: args.checkout.path,
      editorCommand: args.runtime.editorCommand,
    }),
  }
}

const requireCurrentProject = (projects: FloProject[], cwd: string): FloProject => {
  const currentProject = getCurrentProject(projects, cwd)
  if (currentProject === null) {
    throw new FloError(
      `PROJECT_CONTEXT_REQUIRED`,
      `No project matched the current directory. Run Flo inside a git project or pass an explicit project selector.`,
    )
  }

  return currentProject
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

const findWorkspaceByTitle = async (
  runner: CommandRunner,
  cmuxBin: string,
  title: string,
): Promise<string | null> => {
  const workspaces = await listCmuxWorkspaces(runner, cmuxBin)
  const match = workspaces.find((workspace) => workspace.title === title)
  return match?.id ?? null
}

const ensureWorkspace = async (args: {
  runner: CommandRunner
  cmuxBin: string
  target: OpenTarget
}): Promise<{ created: boolean; workspaceId: string }> => {
  const existingWorkspaceId = await findWorkspaceByTitle(
    args.runner,
    args.cmuxBin,
    args.target.workspaceTitle,
  )

  if (existingWorkspaceId !== null) {
    await selectCmuxWorkspace(args.runner, args.cmuxBin, existingWorkspaceId)
    return {
      created: false,
      workspaceId: existingWorkspaceId,
    }
  }

  const workspace = await createCmuxWorkspace(args.runner, args.cmuxBin)
  await renameCmuxWorkspace(args.runner, args.cmuxBin, workspace.id, args.target.workspaceTitle)
  await sendToCmuxWorkspace({
    runner: args.runner,
    cmuxBin: args.cmuxBin,
    workspaceId: workspace.id,
    text: args.target.editorBootstrapCommand,
  })

  return {
    created: true,
    workspaceId: workspace.id,
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
  const config = await loadConfig(args.context.env)
  const projects = await discoverProjects({
    config,
    cwd: args.context.cwd,
    runner: dependencies.runner,
  })

  const project =
    args.selector === undefined
      ? requireCurrentProject(projects, args.context.cwd)
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

export const resolveStartTarget = async (args: {
  context: FloCommandContext
  selector: string
  dependencies?: FloRuntimeDependencies
}): Promise<StartTarget> => {
  const dependencies = { ...defaultDependencies, ...args.dependencies }
  const config = await loadConfig(args.context.env)
  const projects = await discoverProjects({
    config,
    cwd: args.context.cwd,
    runner: dependencies.runner,
  })
  const project = requireCurrentProject(projects, args.context.cwd)
  const parsedSelector = parseStartSelector(args.selector)
  const branchResolution = await resolveBranchForSelector({
    selector: parsedSelector,
    project,
    runner: dependencies.runner,
  })
  const state = await listProjectState(dependencies.runner, project)
  const existingCheckout =
    state.checkouts.find((checkout) => checkout.branch === branchResolution.branch) ?? null

  const checkout =
    existingCheckout ??
    ({
      path: planWorktreePath(project.worktreeRoot, branchResolution.branch),
      branch: branchResolution.branch,
      headSha: null,
      isMain: false,
    } satisfies FloCheckout)

  const target = buildOpenTarget({
    project,
    checkout,
    runtime: config.runtime,
  })

  return {
    ...target,
    createdCheckout: existingCheckout === null,
    ...(branchResolution.issue === undefined ? {} : { issue: branchResolution.issue }),
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
  dryRun?: boolean
  dependencies?: FloRuntimeDependencies
}): Promise<StartTarget & { createdWorkspace?: boolean; workspaceId?: string }> => {
  const dependencies = { ...defaultDependencies, ...args.dependencies }
  const config = await loadConfig(args.context.env)
  const target = await resolveStartTarget(args)

  if (!args.dryRun && target.createdCheckout) {
    await createWorktree(
      dependencies.runner,
      target.project.path,
      target.project.worktreeRoot,
      target.checkout.branch ?? basename(target.checkout.path),
    )
  }

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

export const listFloState = async (args: {
  context: FloCommandContext
  dependencies?: FloRuntimeDependencies
}): Promise<FloListResult> => {
  const dependencies = { ...defaultDependencies, ...args.dependencies }
  const config = await loadConfig(args.context.env)
  const projects = await discoverProjects({
    config,
    cwd: args.context.cwd,
    runner: dependencies.runner,
  })
  const cmuxAvailable = await probeCmux(dependencies.runner, config.runtime.cmuxBin)
  const workspaces = cmuxAvailable
    ? await listCmuxWorkspaces(dependencies.runner, config.runtime.cmuxBin)
    : []
  const workspaceTitles = new Set(workspaces.map((workspace) => workspace.title))

  const projectResults = await Promise.all(
    projects.map(async (project): Promise<FloListProject> => {
      const state = await listProjectState(dependencies.runner, project)

      return {
        name: project.name,
        path: project.path,
        ...(project.defaultSource === undefined ? {} : { defaultSource: project.defaultSource }),
        ...(project.githubRepo === undefined ? {} : { githubRepo: project.githubRepo }),
        checkouts: state.checkouts.map((checkout) => {
          const title = workspaceTitle(config.runtime.workspacePrefix, project, checkout)
          return {
            path: checkout.path,
            branch: checkout.branch,
            isMain: checkout.isMain,
            workspaceTitle: title,
            workspaceOpen: cmuxAvailable ? workspaceTitles.has(title) : null,
          }
        }),
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
