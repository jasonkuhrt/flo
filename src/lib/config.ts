import { resolve } from 'pathe'

import { FloError } from '#lib/errors'
import { pathExists, readFileString } from '#lib/filesystem'
import { expandHome } from '#lib/strings'
import type {
  FloConfig,
  FloProjectConfig,
  FloRuntimeConfig,
  FloWorkspaceProfileConfig,
  ResolvedFloConfig,
} from '#lib/types'

const defaultRuntimeConfig = (env: NodeJS.ProcessEnv): FloRuntimeConfig => ({
  editorCommand: env[`EDITOR`] ?? `nvim`,
  claudeCommand: `claude`,
  shellCommand: env[`SHELL`] ?? `/bin/zsh`,
  cmuxBin: `cmux`,
  zmxBin: `zmx`,
  fzfBin: `fzf`,
  workspacePrefix: `flo`,
  profiles: {
    main: {
      splitDirection: `right`,
    },
    feature: {
      splitDirection: `right`,
    },
  },
})

export const getDefaultConfigPath = (env: NodeJS.ProcessEnv): string => {
  const homeDirectory = env[`HOME`] ?? process.env[`HOME`] ?? `~`
  const xdgConfigHome = env[`XDG_CONFIG_HOME`] ?? `${homeDirectory}/.config`
  return resolve(xdgConfigHome, `flo`, `config.json`)
}

const resolveProjectConfig = (project: FloProjectConfig, homeDirectory: string): FloProjectConfig =>
  project.worktreeRoot === undefined
    ? {
        ...project,
        path: resolve(expandHome(project.path, homeDirectory)),
      }
    : {
        ...project,
        path: resolve(expandHome(project.path, homeDirectory)),
        worktreeRoot: resolve(expandHome(project.worktreeRoot, homeDirectory)),
      }

const isRecord = (value: unknown): value is Record<string, unknown> =>
  typeof value === `object` && value !== null && !Array.isArray(value)

const ensureString = (value: unknown, path: string): string => {
  if (typeof value !== `string` || value.trim().length === 0) {
    throw new FloError(`CONFIG_INVALID`, `Flo config field ${path} must be a non-empty string.`)
  }

  return value
}

const ensureOptionalString = (value: unknown, path: string): string | undefined => {
  if (value === undefined) return undefined
  return ensureString(value, path)
}

const ensureStringArray = (value: unknown, path: string): string[] => {
  if (!Array.isArray(value)) {
    throw new FloError(`CONFIG_INVALID`, `Flo config field ${path} must be an array of strings.`)
  }

  return value.map((entry, index) => ensureString(entry, `${path}[${index}]`))
}

const parseWorkspaceProfile = (value: unknown, path: string): FloWorkspaceProfileConfig => {
  if (!isRecord(value)) {
    throw new FloError(`CONFIG_INVALID`, `Flo config field ${path} must be an object.`)
  }

  const splitDirection = value[`splitDirection`]
  if (splitDirection !== undefined && splitDirection !== `right` && splitDirection !== `bottom`) {
    throw new FloError(
      `CONFIG_INVALID`,
      `Flo config field ${path}.splitDirection must be right or bottom.`,
    )
  }

  const editorCommand = ensureOptionalString(value[`editorCommand`], `${path}.editorCommand`)
  const claudeCommand = ensureOptionalString(value[`claudeCommand`], `${path}.claudeCommand`)

  return {
    ...(editorCommand === undefined ? {} : { editorCommand }),
    ...(claudeCommand === undefined ? {} : { claudeCommand }),
    ...(splitDirection === undefined ? {} : { splitDirection }),
  }
}

const parseProjectConfig = (value: unknown, path: string): FloProjectConfig => {
  if (!isRecord(value)) {
    throw new FloError(`CONFIG_INVALID`, `Flo config field ${path} must be an object.`)
  }
  const aliases =
    value[`aliases`] === undefined
      ? undefined
      : ensureStringArray(value[`aliases`], `${path}.aliases`)
  const worktreeRoot = ensureOptionalString(value[`worktreeRoot`], `${path}.worktreeRoot`)

  const github =
    value[`github`] === undefined
      ? undefined
      : (() => {
          if (!isRecord(value[`github`])) {
            throw new FloError(
              `CONFIG_INVALID`,
              `Flo config field ${path}.github must be an object.`,
            )
          }

          return {
            repo: ensureString(value[`github`][`repo`], `${path}.github.repo`),
          }
        })()

  const defaultSource = value[`defaultSource`]
  if (
    defaultSource !== undefined &&
    defaultSource !== `github` &&
    defaultSource !== `linear` &&
    defaultSource !== `bead`
  ) {
    throw new FloError(
      `CONFIG_INVALID`,
      `Flo config field ${path}.defaultSource must be github, linear, or bead.`,
    )
  }

  return {
    name: ensureString(value[`name`], `${path}.name`),
    path: ensureString(value[`path`], `${path}.path`),
    ...(aliases === undefined ? {} : { aliases }),
    ...(defaultSource === undefined ? {} : { defaultSource }),
    ...(github === undefined ? {} : { github }),
    ...(worktreeRoot === undefined ? {} : { worktreeRoot }),
  }
}

const parseConfig = (text: string, configPath: string): FloConfig => {
  const parsed: unknown = JSON.parse(text)

  if (!isRecord(parsed)) {
    throw new FloError(`CONFIG_INVALID`, `Flo config at ${configPath} must be a JSON object.`)
  }

  const discovery =
    parsed[`discovery`] === undefined
      ? undefined
      : (() => {
          if (!isRecord(parsed[`discovery`])) {
            throw new FloError(`CONFIG_INVALID`, `Flo config field discovery must be an object.`)
          }

          return parsed[`discovery`][`roots`] === undefined
            ? {}
            : { roots: ensureStringArray(parsed[`discovery`][`roots`], `discovery.roots`) }
        })()
  const runtime =
    parsed[`runtime`] === undefined
      ? undefined
      : (() => {
          if (!isRecord(parsed[`runtime`])) {
            throw new FloError(`CONFIG_INVALID`, `Flo config field runtime must be an object.`)
          }

          const runtimeConfig = parsed[`runtime`]
          const profiles =
            runtimeConfig[`profiles`] === undefined
              ? undefined
              : (() => {
                  if (!isRecord(runtimeConfig[`profiles`])) {
                    throw new FloError(
                      `CONFIG_INVALID`,
                      `Flo config field runtime.profiles must be an object.`,
                    )
                  }

                  return {
                    ...(runtimeConfig[`profiles`][`main`] === undefined
                      ? {}
                      : {
                          main: parseWorkspaceProfile(
                            runtimeConfig[`profiles`][`main`],
                            `runtime.profiles.main`,
                          ),
                        }),
                    ...(runtimeConfig[`profiles`][`feature`] === undefined
                      ? {}
                      : {
                          feature: parseWorkspaceProfile(
                            runtimeConfig[`profiles`][`feature`],
                            `runtime.profiles.feature`,
                          ),
                        }),
                  }
                })()

          return {
            ...(ensureOptionalString(runtimeConfig[`editorCommand`], `runtime.editorCommand`) ===
            undefined
              ? {}
              : {
                  editorCommand: ensureString(
                    runtimeConfig[`editorCommand`],
                    `runtime.editorCommand`,
                  ),
                }),
            ...(ensureOptionalString(runtimeConfig[`claudeCommand`], `runtime.claudeCommand`) ===
            undefined
              ? {}
              : {
                  claudeCommand: ensureString(
                    runtimeConfig[`claudeCommand`],
                    `runtime.claudeCommand`,
                  ),
                }),
            ...(ensureOptionalString(runtimeConfig[`shellCommand`], `runtime.shellCommand`) ===
            undefined
              ? {}
              : {
                  shellCommand: ensureString(runtimeConfig[`shellCommand`], `runtime.shellCommand`),
                }),
            ...(ensureOptionalString(runtimeConfig[`cmuxBin`], `runtime.cmuxBin`) === undefined
              ? {}
              : { cmuxBin: ensureString(runtimeConfig[`cmuxBin`], `runtime.cmuxBin`) }),
            ...(ensureOptionalString(runtimeConfig[`zmxBin`], `runtime.zmxBin`) === undefined
              ? {}
              : { zmxBin: ensureString(runtimeConfig[`zmxBin`], `runtime.zmxBin`) }),
            ...(ensureOptionalString(runtimeConfig[`fzfBin`], `runtime.fzfBin`) === undefined
              ? {}
              : { fzfBin: ensureString(runtimeConfig[`fzfBin`], `runtime.fzfBin`) }),
            ...(ensureOptionalString(
              runtimeConfig[`workspacePrefix`],
              `runtime.workspacePrefix`,
            ) === undefined
              ? {}
              : {
                  workspacePrefix: ensureString(
                    runtimeConfig[`workspacePrefix`],
                    `runtime.workspacePrefix`,
                  ),
                }),
            ...(profiles === undefined ? {} : { profiles }),
          } satisfies NonNullable<FloConfig[`runtime`]>
        })()
  const projects =
    parsed[`projects`] === undefined
      ? undefined
      : (() => {
          if (!Array.isArray(parsed[`projects`])) {
            throw new FloError(`CONFIG_INVALID`, `Flo config field projects must be an array.`)
          }

          return parsed[`projects`].map((project, index) =>
            parseProjectConfig(project, `projects[${index}]`),
          )
        })()

  return {
    ...(discovery === undefined ? {} : { discovery }),
    ...(runtime === undefined ? {} : { runtime }),
    ...(projects === undefined ? {} : { projects }),
  }
}

export const loadConfig = async (env: NodeJS.ProcessEnv): Promise<ResolvedFloConfig> => {
  const configPath = resolve(env[`FLO_CONFIG_PATH`] ?? getDefaultConfigPath(env))
  const exists = await pathExists(configPath)

  if (!exists) {
    return {
      configPath,
      exists: false,
      discoveryRoots: [],
      runtime: defaultRuntimeConfig(env),
      projects: [],
    }
  }

  let parsed: FloConfig

  try {
    const text = await readFileString(configPath)
    parsed = parseConfig(text, configPath)
  } catch (error) {
    throw new FloError(
      `CONFIG_INVALID`,
      `Failed to read Flo config at ${configPath}: ${String(error)}`,
    )
  }

  const homeDirectory = env[`HOME`] ?? process.env[`HOME`] ?? `~`
  const discoveryRoots = (parsed.discovery?.roots ?? []).map((path) =>
    resolve(expandHome(path, homeDirectory)),
  )

  const runtime = {
    ...defaultRuntimeConfig(env),
    ...parsed.runtime,
    profiles: {
      ...defaultRuntimeConfig(env).profiles,
      ...parsed.runtime?.profiles,
      main: {
        ...defaultRuntimeConfig(env).profiles.main,
        ...parsed.runtime?.profiles?.main,
      },
      feature: {
        ...defaultRuntimeConfig(env).profiles.feature,
        ...parsed.runtime?.profiles?.feature,
      },
    },
  }

  const projects = (parsed.projects ?? []).map((project) =>
    resolveProjectConfig(project, homeDirectory),
  )

  return {
    configPath,
    exists,
    discoveryRoots,
    runtime,
    projects,
  }
}
