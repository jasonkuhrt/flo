import { mkdtemp, mkdir, writeFile } from 'node:fs/promises'
import { join } from 'node:path'
import { homedir, tmpdir } from 'node:os'

import { afterEach, describe, expect, it } from 'bun:test'

import { FloError } from '#lib/errors'
import { getDefaultConfigPath, loadConfig } from '#lib/config'

const tempPaths: string[] = []

afterEach(async () => {
  await Promise.all(
    tempPaths.splice(0).map(async (path) => {
      await Bun.$`rm -rf ${path}`.quiet()
    }),
  )
})

describe(`config`, () => {
  it(`builds the default config path from XDG`, () => {
    expect(getDefaultConfigPath({ XDG_CONFIG_HOME: `/tmp/config-home` })).toBe(
      `/tmp/config-home/flo/config.json`,
    )
  })

  it(`returns defaults when the config file is missing`, async () => {
    const path = await mkdtemp(join(tmpdir(), `flo-config-missing-`))
    tempPaths.push(path)

    const result = await loadConfig({
      FLO_CONFIG_PATH: join(path, `config.json`),
      SHELL: `/bin/zsh`,
      EDITOR: `nvim`,
    })

    expect(result.exists).toBe(false)
    expect(result.runtime.workspacePrefix).toBe(`flo`)
    expect(result.projects).toEqual([])
  })

  it(`reads and resolves an existing config file`, async () => {
    const path = await mkdtemp(join(tmpdir(), `flo-config-`))
    tempPaths.push(path)
    const configPath = join(path, `flo`, `config.json`)
    await mkdir(join(path, `flo`), { recursive: true })
    await writeFile(
      configPath,
      JSON.stringify({
        discovery: {
          roots: [join(homedir(), `projects`)],
        },
        runtime: {
          editorCommand: `hx`,
        },
        projects: [
          {
            name: `dotfiles`,
            path: join(path, `projects`, `dotfiles`),
            worktreeRoot: join(path, `checkouts`, `dotfiles`),
          },
        ],
      }),
    )

    const result = await loadConfig({
      FLO_CONFIG_PATH: configPath,
      SHELL: `/bin/zsh`,
    })

    expect(result.exists).toBe(true)
    expect(result.discoveryRoots).toEqual([join(homedir(), `projects`)])
    expect(result.runtime.editorCommand).toBe(`hx`)
    expect(result.projects).toEqual([
      {
        name: `dotfiles`,
        path: join(path, `projects`, `dotfiles`),
        worktreeRoot: join(path, `checkouts`, `dotfiles`),
      },
    ])
  })

  it(`rejects invalid config payloads`, async () => {
    const path = await mkdtemp(join(tmpdir(), `flo-config-invalid-`))
    tempPaths.push(path)
    const configPath = join(path, `config.json`)
    await writeFile(configPath, JSON.stringify([`not-an-object`]))

    let thrown: unknown = null

    try {
      await loadConfig({
        FLO_CONFIG_PATH: configPath,
      })
    } catch (error) {
      thrown = error
    }

    expect(thrown).toBeInstanceOf(FloError)
  })

  it(`rejects malformed config fields with a precise error`, async () => {
    const path = await mkdtemp(join(tmpdir(), `flo-config-invalid-fields-`))
    tempPaths.push(path)
    const configPath = join(path, `config.json`)
    await writeFile(
      configPath,
      JSON.stringify({
        runtime: {
          editorCommand: ``,
        },
        projects: [
          {
            name: `dotfiles`,
            path: 42,
          },
        ],
      }),
    )

    let thrown: unknown = null

    try {
      await loadConfig({
        FLO_CONFIG_PATH: configPath,
      })
    } catch (error) {
      thrown = error
    }

    expect(thrown).toBeInstanceOf(FloError)
    expect(String(thrown)).toContain(`runtime.editorCommand`)
  })
})
