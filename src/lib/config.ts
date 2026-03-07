import { resolve } from 'pathe'

import { FloError } from '#lib/errors'
import { pathExists, readFileString } from '#lib/filesystem'
import { expandHome } from '#lib/strings'
import type { FloConfig, FloProjectConfig, FloRuntimeConfig, ResolvedFloConfig } from '#lib/types'

const defaultRuntimeConfig = (env: NodeJS.ProcessEnv): FloRuntimeConfig => ({
  editorCommand: env[`EDITOR`] ?? `nvim`,
  claudeCommand: `claude`,
  shellCommand: env[`SHELL`] ?? `/bin/zsh`,
  cmuxBin: `cmux`,
  zmxBin: `zmx`,
  fzfBin: `fzf`,
  workspacePrefix: `flo`,
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

const parseConfig = (text: string, configPath: string): FloConfig => {
  const parsed: unknown = JSON.parse(text)

  if (!isRecord(parsed)) {
    throw new FloError(`CONFIG_INVALID`, `Flo config at ${configPath} must be a JSON object.`)
  }

  return parsed as FloConfig
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
