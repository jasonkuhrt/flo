import { join, resolve } from 'pathe'

import { FloError } from '#lib/errors'
import { pathExists, readFileString, removePath } from '#lib/filesystem'
import {
  systemRunner,
  systemRunnerUntil,
  type CommandRunner,
  type CommandUntilRunner,
} from '#lib/process'
import type {
  FloCommandContext,
  FloRaycastInstallResult,
  FloRaycastStatusResult,
  FloRaycastUninstallResult,
} from '#lib/types'

export interface FloRaycastDependencies {
  runner?: CommandRunner
  untilRunner?: CommandUntilRunner
}

const defaultDependencies: Required<FloRaycastDependencies> = {
  runner: systemRunner,
  untilRunner: systemRunnerUntil,
}

interface RaycastManifest {
  name: string
  commands: string[]
}

const isRecord = (value: unknown): value is Record<string, unknown> =>
  typeof value === `object` && value !== null && !Array.isArray(value)

const floPackageRoot = (): string =>
  resolve(decodeURIComponent(new URL(`../../`, import.meta.url).pathname))

const raycastAdapterPath = (): string => resolve(floPackageRoot(), `integrations`, `raycast`)

const raycastConfigHome = (env: NodeJS.ProcessEnv): string =>
  resolve(env[`XDG_CONFIG_HOME`] ?? join(env[`HOME`] ?? process.env[`HOME`] ?? `~`, `.config`))

const parseRaycastManifest = (text: string, path: string): RaycastManifest => {
  const parsed: unknown = JSON.parse(text)
  if (!isRecord(parsed)) {
    throw new FloError(
      `RAYCAST_CONFIG_INVALID`,
      `Raycast manifest at ${path} must be a JSON object.`,
    )
  }

  const name = parsed[`name`]
  if (typeof name !== `string` || name.trim().length === 0) {
    throw new FloError(`RAYCAST_CONFIG_INVALID`, `Raycast manifest at ${path} must define a name.`)
  }

  const commandsValue = parsed[`commands`]
  if (!Array.isArray(commandsValue)) {
    throw new FloError(
      `RAYCAST_CONFIG_INVALID`,
      `Raycast manifest at ${path} must define a commands array.`,
    )
  }

  const commands = commandsValue.flatMap((command, index) => {
    if (!isRecord(command) || typeof command[`name`] !== `string`) {
      throw new FloError(
        `RAYCAST_CONFIG_INVALID`,
        `Raycast manifest at ${path} command[${index}] must define a name.`,
      )
    }

    return command[`name`]
  })

  return {
    name,
    commands,
  }
}

const readManifest = async (manifestPath: string): Promise<RaycastManifest> =>
  parseRaycastManifest(await readFileString(manifestPath), manifestPath)

const probeCommand = async (
  runner: CommandRunner,
  command: string,
  args: string[],
): Promise<boolean> => {
  const result = await runner(command, args)
  return result.exitCode === 0
}

const requireCommand = async (
  runner: CommandRunner,
  command: string,
  args: string[],
  message: string,
  options?: {
    cwd?: string
  },
): Promise<void> => {
  const result = await runner(command, args, options)
  if (result.exitCode !== 0) {
    throw new FloError(
      `RAYCAST_SETUP_INVALID`,
      `${message}\n${result.stderr.trim() || result.stdout.trim()}`.trim(),
    )
  }
}

const getStatusFromManifest = async (args: {
  context: FloCommandContext
  runner: CommandRunner
}): Promise<FloRaycastStatusResult> => {
  const adapterPath = raycastAdapterPath()
  const adapterManifestPath = join(adapterPath, `package.json`)
  const adapterExists = await pathExists(adapterManifestPath)
  const adapterManifest = !adapterExists
    ? {
        name: `flo`,
        commands: [],
      }
    : await readManifest(adapterManifestPath)

  const installPath = join(
    raycastConfigHome(args.context.env),
    `raycast`,
    `extensions`,
    adapterManifest.name,
  )
  const installedManifestPath = join(installPath, `package.json`)
  const installed = await pathExists(installedManifestPath)
  const installedManifest = !installed ? adapterManifest : await readManifest(installedManifestPath)

  return {
    appAvailable: await probeCommand(args.runner, `open`, [`-Ra`, `Raycast`]),
    bunAvailable: await probeCommand(args.runner, `bun`, [`--version`]),
    adapterPath,
    adapterExists,
    extensionName: adapterManifest.name,
    installPath,
    installed,
    commands: installedManifest.commands,
  }
}

export const getRaycastStatus = async (args: {
  context: FloCommandContext
  dependencies?: FloRaycastDependencies
}): Promise<FloRaycastStatusResult> => {
  const dependencies = {
    ...defaultDependencies,
    ...args.dependencies,
  }

  return getStatusFromManifest({
    context: args.context,
    runner: dependencies.runner,
  })
}

export const installRaycastExtension = async (args: {
  context: FloCommandContext
  dependencies?: FloRaycastDependencies
}): Promise<FloRaycastInstallResult> => {
  const dependencies = {
    ...defaultDependencies,
    ...args.dependencies,
  }
  const statusBefore = await getStatusFromManifest({
    context: args.context,
    runner: dependencies.runner,
  })

  if (!statusBefore.adapterExists) {
    throw new FloError(
      `RAYCAST_SETUP_INVALID`,
      `Bundled Raycast adapter not found at ${join(statusBefore.adapterPath, `package.json`)}.`,
    )
  }

  await requireCommand(
    dependencies.runner,
    `open`,
    [`-Ra`, `Raycast`],
    `Raycast.app must be installed before Flo can install the Raycast extension.`,
  )
  await requireCommand(
    dependencies.runner,
    `bun`,
    [`--version`],
    `bun must be installed before Flo can install the Raycast extension.`,
  )
  await requireCommand(
    dependencies.runner,
    `bun`,
    [`install`, `--frozen-lockfile`],
    `Failed to install Raycast adapter dependencies.`,
    {
      cwd: statusBefore.adapterPath,
    },
  )

  const readyResult = await dependencies.untilRunner(
    `bun`,
    [`x`, `ray`, `develop`, `--non-interactive`],
    {
      cwd: statusBefore.adapterPath,
      readyWhen: `ready  - built extension successfully`,
      terminateSignal: `SIGINT`,
    },
  )

  if (!readyResult.matched) {
    throw new FloError(
      `RAYCAST_INSTALL_FAILED`,
      [
        `Failed to bootstrap the Flo Raycast extension in development mode.`,
        readyResult.stderr.trim() || readyResult.stdout.trim(),
      ]
        .filter((part) => part.length > 0)
        .join(`\n`),
    )
  }

  await requireCommand(
    dependencies.runner,
    `open`,
    [`-a`, `Raycast`],
    `Flo installed the Raycast extension but could not open Raycast afterwards.`,
  )

  const statusAfter = await getStatusFromManifest({
    context: args.context,
    runner: dependencies.runner,
  })

  if (!statusAfter.installed) {
    throw new FloError(
      `RAYCAST_INSTALL_FAILED`,
      `Flo expected the Raycast extension at ${statusAfter.installPath}, but it is still missing.`,
    )
  }

  return {
    ...statusAfter,
    changed: !statusBefore.installed,
    method: `develop`,
  }
}

export const uninstallRaycastExtension = async (args: {
  context: FloCommandContext
  dependencies?: FloRaycastDependencies
}): Promise<FloRaycastUninstallResult> => {
  const status = await getRaycastStatus(args)
  if (status.installed) {
    await removePath(status.installPath, true)
  }

  return {
    extensionName: status.extensionName,
    installPath: status.installPath,
    installedBefore: status.installed,
    removed: status.installed,
  }
}
