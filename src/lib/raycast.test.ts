import { mkdtemp, mkdir, writeFile } from 'node:fs/promises'
import { tmpdir } from 'node:os'

import { afterEach, describe, expect, it } from 'bun:test'
import { join } from 'pathe'

import { getRaycastStatus, installRaycastExtension, uninstallRaycastExtension } from '#lib/raycast'
import type { CommandRunner, CommandUntilRunner } from '#lib/process'

const tempPaths: string[] = []

afterEach(async () => {
  await Promise.all(
    tempPaths.splice(0).map(async (path) => {
      await Bun.$`rm -rf ${path}`.quiet()
    }),
  )
})

const makeEnv = async (): Promise<NodeJS.ProcessEnv> => {
  const homePath = await mkdtemp(join(tmpdir(), `flo-raycast-`))
  tempPaths.push(homePath)

  return {
    HOME: homePath,
    XDG_CONFIG_HOME: join(homePath, `.config`),
  }
}

const ok = (stdout = ``) => ({
  stdout,
  stderr: ``,
  exitCode: 0,
})

describe(`raycast integration`, () => {
  it(`reports status for the bundled Raycast adapter`, async () => {
    const env = await makeEnv()
    const runner: CommandRunner = async (command, args = []) => {
      const key = [command, ...args].join(` `)

      if (key === `open -Ra Raycast`) return ok()
      if (key === `bun --version`) return ok(`1.3.0\n`)

      throw new Error(`Unhandled command: ${key}`)
    }

    const result = await getRaycastStatus({
      context: {
        cwd: `/tmp`,
        env,
      },
      dependencies: { runner },
    })

    expect(result).toMatchObject({
      appAvailable: true,
      bunAvailable: true,
      adapterExists: true,
      installed: false,
      extensionName: `flo`,
    })
    expect(result.commands).toContain(`open-workspace`)
  })

  it(`installs the Raycast extension through a one-shot develop run`, async () => {
    const env = await makeEnv()
    const installPath = join(env[`XDG_CONFIG_HOME`] ?? ``, `raycast`, `extensions`, `flo`)
    const runner: CommandRunner = async (command, args = [], options = {}) => {
      const key = [command, ...args].join(` `)

      if (key === `open -Ra Raycast`) return ok()
      if (key === `open -a Raycast`) return ok()
      if (key === `bun --version`) return ok(`1.3.0\n`)
      if (key === `bun install --frozen-lockfile`) {
        expect(options.cwd).toContain(join(`integrations`, `raycast`))
        return ok()
      }

      throw new Error(`Unhandled command: ${key}`)
    }
    const untilRunner: CommandUntilRunner = async (command, args = [], options) => {
      expect(command).toBe(`bun`)
      expect(args).toEqual([`x`, `ray`, `develop`, `--non-interactive`])
      expect(options?.cwd).toContain(join(`integrations`, `raycast`))

      await mkdir(installPath, { recursive: true })
      await writeFile(
        join(installPath, `package.json`),
        JSON.stringify({
          name: `flo`,
          commands: [
            {
              name: `open-workspace`,
            },
            {
              name: `open-last`,
            },
          ],
        }),
      )

      return {
        stdout: `ready  - built extension successfully\n`,
        stderr: ``,
        exitCode: 0,
        matched: true,
      }
    }

    const result = await installRaycastExtension({
      context: {
        cwd: `/tmp`,
        env,
      },
      dependencies: {
        runner,
        untilRunner,
      },
    })

    expect(result).toMatchObject({
      installed: true,
      changed: true,
      method: `develop`,
      extensionName: `flo`,
    })
    expect(result.commands).toEqual([`open-workspace`, `open-last`])
  })

  it(`fails install when development mode never reaches a ready state`, async () => {
    const env = await makeEnv()
    const runner: CommandRunner = async (command, args = [], options = {}) => {
      const key = [command, ...args].join(` `)

      if (key === `open -Ra Raycast`) return ok()
      if (key === `bun --version`) return ok(`1.3.0\n`)
      if (key === `bun install --frozen-lockfile`) {
        expect(options.cwd).toContain(join(`integrations`, `raycast`))
        return ok()
      }

      throw new Error(`Unhandled command: ${key}`)
    }
    const untilRunner: CommandUntilRunner = async () => ({
      stdout: ``,
      stderr: `ray develop failed`,
      exitCode: 1,
      matched: false,
    })

    try {
      await installRaycastExtension({
        context: {
          cwd: `/tmp`,
          env,
        },
        dependencies: {
          runner,
          untilRunner,
        },
      })
      throw new Error(`expected installRaycastExtension to fail`)
    } catch (error) {
      expect(String(error)).toContain(`ray develop failed`)
    }
  })

  it(`fails install when the extension still does not exist afterwards`, async () => {
    const env = await makeEnv()
    const runner: CommandRunner = async (command, args = [], options = {}) => {
      const key = [command, ...args].join(` `)

      if (key === `open -Ra Raycast`) return ok()
      if (key === `open -a Raycast`) return ok()
      if (key === `bun --version`) return ok(`1.3.0\n`)
      if (key === `bun install --frozen-lockfile`) {
        expect(options.cwd).toContain(join(`integrations`, `raycast`))
        return ok()
      }

      throw new Error(`Unhandled command: ${key}`)
    }
    const untilRunner: CommandUntilRunner = async () => ({
      stdout: `ready  - built extension successfully\n`,
      stderr: ``,
      exitCode: 0,
      matched: true,
    })

    try {
      await installRaycastExtension({
        context: {
          cwd: `/tmp`,
          env,
        },
        dependencies: {
          runner,
          untilRunner,
        },
      })
      throw new Error(`expected installRaycastExtension to fail`)
    } catch (error) {
      expect(String(error)).toContain(`still missing`)
    }
  })

  it(`removes the installed Raycast extension`, async () => {
    const env = await makeEnv()
    const installPath = join(env[`XDG_CONFIG_HOME`] ?? ``, `raycast`, `extensions`, `flo`)
    await mkdir(installPath, { recursive: true })
    await writeFile(
      join(installPath, `package.json`),
      JSON.stringify({
        name: `flo`,
        commands: [
          {
            name: `open-workspace`,
          },
        ],
      }),
    )

    const runner: CommandRunner = async (command, args = []) => {
      const key = [command, ...args].join(` `)

      if (key === `open -Ra Raycast`) return ok()
      if (key === `bun --version`) return ok(`1.3.0\n`)

      throw new Error(`Unhandled command: ${key}`)
    }

    const result = await uninstallRaycastExtension({
      context: {
        cwd: `/tmp`,
        env,
      },
      dependencies: { runner },
    })

    expect(result).toEqual({
      extensionName: `flo`,
      installPath,
      installedBefore: true,
      removed: true,
    })
    expect(await Bun.file(join(installPath, `package.json`)).exists()).toBe(false)
  })

  it(`reports install failures when Bun or Raycast are missing`, async () => {
    const env = await makeEnv()
    const runner: CommandRunner = async (command, args = []) => {
      const key = [command, ...args].join(` `)

      if (key === `open -Ra Raycast`) {
        return {
          stdout: ``,
          stderr: `Raycast not found`,
          exitCode: 1,
        }
      }
      if (key === `bun --version`) return ok(`1.3.0\n`)

      throw new Error(`Unhandled command: ${key}`)
    }

    try {
      await installRaycastExtension({
        context: {
          cwd: `/tmp`,
          env,
        },
        dependencies: { runner },
      })
      throw new Error(`expected installRaycastExtension to fail`)
    } catch (error) {
      expect(String(error)).toContain(`Raycast.app must be installed`)
    }
  })
})
