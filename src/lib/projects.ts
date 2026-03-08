import { basename, join, resolve } from 'pathe'

import { loadProjectLocalConfig } from '#lib/config'
import { FloError } from '#lib/errors'
import { readDirectoryEntries, realPath } from '#lib/filesystem'
import {
  deriveDefaultWorktreeRoot,
  getGitRemoteOrigin,
  getGitTopLevel,
  listWorktrees,
  parseGitHubRepo,
} from '#lib/git'
import { looksLikeAbsolutePath, normalizeMatchKey } from '#lib/strings'
import type { CommandRunner } from '#lib/process'
import type {
  FloCheckout,
  FloProject,
  FloProjectConfig,
  FloProjectLocalConfig,
  FloProjectState,
  ResolvedFloConfig,
} from '#lib/types'

const listRootCandidates = async (root: string): Promise<string[]> => {
  const entries = await readDirectoryEntries(root).catch(() => [])
  const childDirectories = entries
    .filter((entry) => entry.type === `Directory` && !entry.name.startsWith(`.`))
    .map((entry) => resolve(join(root, entry.name)))

  return [root, ...childDirectories]
}

const mergeProjectConfig = (
  repositoryPath: string,
  configuredProjects: FloProjectConfig[],
): FloProjectConfig | undefined =>
  configuredProjects.find((project) => resolve(project.path) === repositoryPath)

const mergeProjectOverrides = (args: {
  repositoryPath: string
  configuredProject: FloProjectConfig | undefined
  localConfig: FloProjectLocalConfig | null
}): FloProjectConfig | undefined => {
  if (args.configuredProject === undefined && args.localConfig === null) {
    return undefined
  }

  const aliases = args.localConfig?.aliases ?? args.configuredProject?.aliases
  const defaultSource = args.localConfig?.defaultSource ?? args.configuredProject?.defaultSource
  const github = args.localConfig?.github ?? args.configuredProject?.github
  const worktreeRoot = args.localConfig?.worktreeRoot ?? args.configuredProject?.worktreeRoot
  const workspaceProfiles =
    args.localConfig?.workspaceProfiles === undefined &&
    args.configuredProject?.workspaceProfiles === undefined
      ? undefined
      : {
          ...(args.configuredProject?.workspaceProfiles ?? {}),
          ...(args.localConfig?.workspaceProfiles ?? {}),
          ...(args.configuredProject?.workspaceProfiles?.main === undefined &&
          args.localConfig?.workspaceProfiles?.main === undefined
            ? {}
            : {
                main: {
                  ...(args.configuredProject?.workspaceProfiles?.main ?? {}),
                  ...(args.localConfig?.workspaceProfiles?.main ?? {}),
                  ...(args.configuredProject?.workspaceProfiles?.main?.layout === undefined &&
                  args.localConfig?.workspaceProfiles?.main?.layout === undefined
                    ? {}
                    : {
                        layout: {
                          ...(args.configuredProject?.workspaceProfiles?.main?.layout ?? {}),
                          ...(args.localConfig?.workspaceProfiles?.main?.layout ?? {}),
                        },
                      }),
                },
              }),
          ...(args.configuredProject?.workspaceProfiles?.feature === undefined &&
          args.localConfig?.workspaceProfiles?.feature === undefined
            ? {}
            : {
                feature: {
                  ...(args.configuredProject?.workspaceProfiles?.feature ?? {}),
                  ...(args.localConfig?.workspaceProfiles?.feature ?? {}),
                  ...(args.configuredProject?.workspaceProfiles?.feature?.layout === undefined &&
                  args.localConfig?.workspaceProfiles?.feature?.layout === undefined
                    ? {}
                    : {
                        layout: {
                          ...(args.configuredProject?.workspaceProfiles?.feature?.layout ?? {}),
                          ...(args.localConfig?.workspaceProfiles?.feature?.layout ?? {}),
                        },
                      }),
                },
              }),
        }

  return {
    name: args.localConfig?.name ?? args.configuredProject?.name ?? basename(args.repositoryPath),
    path: args.repositoryPath,
    ...(aliases === undefined ? {} : { aliases }),
    ...(defaultSource === undefined ? {} : { defaultSource }),
    ...(github === undefined ? {} : { github }),
    ...(worktreeRoot === undefined ? {} : { worktreeRoot }),
    ...(workspaceProfiles === undefined ? {} : { workspaceProfiles }),
  }
}

const inferProject = async (
  runner: CommandRunner,
  repositoryPath: string,
  config: FloProjectConfig | undefined,
): Promise<FloProject> => {
  const remoteOrigin = await getGitRemoteOrigin(runner, repositoryPath)
  const githubRepo =
    config?.github?.repo ??
    (remoteOrigin === null ? undefined : (parseGitHubRepo(remoteOrigin) ?? undefined))

  return {
    name: config?.name ?? basename(repositoryPath),
    path: repositoryPath,
    aliases: config?.aliases ?? [],
    ...(config?.defaultSource === undefined
      ? githubRepo === undefined
        ? {}
        : { defaultSource: `github` as const }
      : { defaultSource: config.defaultSource }),
    ...(githubRepo === undefined ? {} : { githubRepo }),
    worktreeRoot: config?.worktreeRoot ?? deriveDefaultWorktreeRoot(repositoryPath),
    workspaceProfiles: config?.workspaceProfiles ?? {},
  }
}

export const discoverProjects = async (args: {
  config: ResolvedFloConfig
  cwd: string
  env: NodeJS.ProcessEnv
  runner: CommandRunner
}): Promise<FloProject[]> => {
  const candidatePaths = new Set<string>()

  for (const configuredProject of args.config.projects) {
    candidatePaths.add(resolve(configuredProject.path))
  }

  const rootCandidateGroups = await Promise.all(
    args.config.discoveryRoots.map(async (root) => listRootCandidates(root)),
  )

  for (const candidates of rootCandidateGroups) {
    for (const candidate of candidates) {
      candidatePaths.add(candidate)
    }
  }

  const repositoryPaths = new Map<string, FloProjectConfig | undefined>()
  const resolvedCandidates = await Promise.all(
    [...candidatePaths].map(async (candidatePath) => {
      const topLevel = await getGitTopLevel(args.runner, candidatePath)
      if (topLevel === null) return null

      const canonicalPath = resolve(await realPath(topLevel))
      return {
        canonicalPath,
        configuredProject: mergeProjectConfig(canonicalPath, args.config.projects),
      }
    }),
  )

  for (const resolvedCandidate of resolvedCandidates) {
    if (resolvedCandidate === null) continue
    repositoryPaths.set(resolvedCandidate.canonicalPath, resolvedCandidate.configuredProject)
  }

  const cwdTopLevel = await getGitTopLevel(args.runner, args.cwd)
  if (cwdTopLevel !== null) {
    const canonicalCwdPath = resolve(await realPath(cwdTopLevel))
    repositoryPaths.set(
      canonicalCwdPath,
      mergeProjectConfig(canonicalCwdPath, args.config.projects),
    )
  }

  const projects = await Promise.all(
    [...repositoryPaths.entries()].map(async ([repositoryPath, configuredProject]) => {
      const localConfig = await loadProjectLocalConfig({
        projectPath: repositoryPath,
        env: args.env,
      })
      return inferProject(
        args.runner,
        repositoryPath,
        mergeProjectOverrides({
          repositoryPath,
          configuredProject,
          localConfig,
        }),
      )
    }),
  )

  return projects.sort((left, right) => left.name.localeCompare(right.name))
}

export const getCurrentProject = (projects: FloProject[], cwd: string): FloProject | null => {
  const resolvedCwd = resolve(cwd)
  const matches = projects
    .filter((project) => resolvedCwd === project.path || resolvedCwd.startsWith(`${project.path}/`))
    .sort((left, right) => right.path.length - left.path.length)

  return matches[0] ?? null
}

const projectMatchKeys = (project: FloProject): Set<string> =>
  new Set(
    [project.name, project.path, basename(project.path), ...project.aliases].map(normalizeMatchKey),
  )

export const resolveProjectSelector = (projects: FloProject[], selector: string): FloProject => {
  const trimmedSelector = selector.trim()
  const normalizedSelector = normalizeMatchKey(trimmedSelector)

  if (looksLikeAbsolutePath(trimmedSelector)) {
    const resolvedSelector = resolve(
      trimmedSelector.replace(/^~(?=\/)/u, process.env[`HOME`] ?? `~`),
    )
    const pathMatch = projects.find(
      (project) =>
        resolvedSelector === project.path || resolvedSelector.startsWith(`${project.path}/`),
    )

    if (pathMatch) return pathMatch
  }

  const exactMatches = projects.filter((project) =>
    projectMatchKeys(project).has(normalizedSelector),
  )
  const exactMatch = exactMatches[0]
  if (exactMatches.length === 1 && exactMatch !== undefined) return exactMatch
  if (exactMatches.length > 1) {
    throw new FloError(
      `PROJECT_SELECTOR_AMBIGUOUS`,
      `Project selector "${selector}" matched multiple projects.`,
    )
  }

  const fuzzyMatches = projects.filter((project) =>
    [...projectMatchKeys(project)].some((key) => key.includes(normalizedSelector)),
  )

  const fuzzyMatch = fuzzyMatches[0]
  if (fuzzyMatches.length === 1 && fuzzyMatch !== undefined) return fuzzyMatch
  if (fuzzyMatches.length > 1) {
    throw new FloError(
      `PROJECT_SELECTOR_AMBIGUOUS`,
      `Project selector "${selector}" is ambiguous across ${fuzzyMatches.length} projects.`,
    )
  }

  throw new FloError(`PROJECT_NOT_FOUND`, `No project matched selector "${selector}".`)
}

export const listProjectState = async (
  runner: CommandRunner,
  project: FloProject,
): Promise<FloProjectState> => ({
  project,
  checkouts: await listWorktrees(runner, project.path),
})

export const resolveCheckoutSelector = (
  checkouts: FloCheckout[],
  selector: string | undefined,
): FloCheckout => {
  if (selector === undefined || selector.trim().length === 0 || selector === `main`) {
    const mainCheckout = checkouts.find((checkout) => checkout.isMain)
    if (mainCheckout) return mainCheckout
    throw new FloError(`CHECKOUT_MAIN_MISSING`, `The project does not have a main checkout.`)
  }

  const normalizedSelector = normalizeMatchKey(selector)
  const matches = checkouts.filter((checkout) => {
    const branch = checkout.branch ? normalizeMatchKey(checkout.branch) : null
    const leaf = normalizeMatchKey(basename(checkout.path))
    return branch === normalizedSelector || leaf === normalizedSelector
  })

  const checkoutMatch = matches[0]
  if (matches.length === 1 && checkoutMatch !== undefined) return checkoutMatch
  if (matches.length > 1) {
    throw new FloError(
      `CHECKOUT_SELECTOR_AMBIGUOUS`,
      `Checkout selector "${selector}" matched multiple checkouts.`,
    )
  }

  throw new FloError(`CHECKOUT_NOT_FOUND`, `No checkout matched selector "${selector}".`)
}
