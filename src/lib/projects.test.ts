import { mkdtemp, mkdir, realpath } from 'node:fs/promises'
import { dirname, join } from 'node:path'
import { tmpdir } from 'node:os'

import { afterEach, describe, expect, it } from 'bun:test'

import { FloError } from '#lib/errors'
import type { CommandRunner } from '#lib/process'
import {
  discoverProjects,
  getCurrentProject,
  resolveCheckoutSelector,
  resolveProjectSelector,
} from '#lib/projects'
import type { FloCheckout, FloProject, ResolvedFloConfig } from '#lib/types'

const tempPaths: string[] = []

afterEach(async () => {
  await Promise.all(
    tempPaths.splice(0).map(async (path) => {
      await Bun.$`rm -rf ${path}`.quiet()
    }),
  )
})

const projects: FloProject[] = [
  {
    name: `dotfiles`,
    path: `/Users/jasonkuhrt/projects/jasonkuhrt/dotfiles`,
    aliases: [`df`],
    defaultSource: `github`,
    githubRepo: `jasonkuhrt/dotfiles`,
    worktreeRoot: `/Users/jasonkuhrt/projects/jasonkuhrt/.flo-checkouts/dotfiles`,
    workspaceProfiles: {},
  },
  {
    name: `flo`,
    path: `/Users/jasonkuhrt/projects/jasonkuhrt/flo`,
    aliases: [],
    defaultSource: `github`,
    githubRepo: `jasonkuhrt/flo`,
    worktreeRoot: `/Users/jasonkuhrt/projects/jasonkuhrt/.flo-checkouts/flo`,
    workspaceProfiles: {},
  },
]
const [dotfilesProject, floProject] = projects

if (dotfilesProject === undefined || floProject === undefined) {
  throw new Error(`Expected project fixtures.`)
}

describe(`getCurrentProject`, () => {
  it(`returns the longest matching project root`, () => {
    expect(
      getCurrentProject(
        projects,
        `/Users/jasonkuhrt/projects/jasonkuhrt/dotfiles/home/.config/nvim`,
      ),
    ).toEqual(dotfilesProject)
  })
})

describe(`resolveProjectSelector`, () => {
  it(`resolves aliases`, () => {
    expect(resolveProjectSelector(projects, `df`)).toEqual(dotfilesProject)
  })

  it(`resolves fuzzy name matches`, () => {
    expect(resolveProjectSelector(projects, `flo`)).toEqual(floProject)
  })

  it(`rejects ambiguous fuzzy selectors`, () => {
    expect(() =>
      resolveProjectSelector(
        [
          ...projects,
          {
            name: `flow`,
            path: `/Users/jasonkuhrt/projects/jasonkuhrt/flow`,
            aliases: [],
            worktreeRoot: `/Users/jasonkuhrt/projects/jasonkuhrt/.flo-checkouts/flow`,
            workspaceProfiles: {},
          },
        ],
        `lo`,
      ),
    ).toThrow(FloError)
  })
})

describe(`resolveCheckoutSelector`, () => {
  const checkouts: FloCheckout[] = [
    {
      path: `/Users/jasonkuhrt/projects/jasonkuhrt/flo`,
      branch: `main`,
      headSha: `abc`,
      isMain: true,
    },
    {
      path: `/Users/jasonkuhrt/projects/jasonkuhrt/.flo-checkouts/flo/feat/auth`,
      branch: `feat/auth`,
      headSha: `def`,
      isMain: false,
    },
  ]
  const [mainCheckout, featureCheckout] = checkouts

  if (mainCheckout === undefined || featureCheckout === undefined) {
    throw new Error(`Expected checkout fixtures.`)
  }

  it(`returns the main checkout by default`, () => {
    expect(resolveCheckoutSelector(checkouts, undefined)).toEqual(mainCheckout)
  })

  it(`resolves branch selectors`, () => {
    expect(resolveCheckoutSelector(checkouts, `feat/auth`)).toEqual(featureCheckout)
  })

  it(`rejects missing checkouts`, () => {
    expect(() => resolveCheckoutSelector(checkouts, `missing`)).toThrow(FloError)
  })
})

describe(`discoverProjects`, () => {
  it(`discovers configured roots and applies project overrides`, async () => {
    const root = await mkdtemp(join(tmpdir(), `flo-projects-`))
    tempPaths.push(root)
    const repoRootPath = join(root, `flo`)
    await mkdir(repoRootPath, { recursive: true })
    const repoRoot = await realpath(repoRootPath)

    const config: ResolvedFloConfig = {
      configPath: join(root, `config.json`),
      exists: true,
      discoveryRoots: [root],
      runtime: {
        editorCommand: `nvim`,
        claudeCommand: `claude`,
        shellCommand: `/bin/zsh`,
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
      },
      projects: [
        {
          name: `flo`,
          path: repoRoot,
          aliases: [`ff`],
        },
      ],
    }

    const runner: CommandRunner = async (_command, args = []) => {
      const key = args.join(` `)

      if (key === `-C ${root} rev-parse --show-toplevel`) {
        return { stdout: ``, stderr: `no git`, exitCode: 1 }
      }

      if (key === `-C ${repoRoot} rev-parse --show-toplevel`) {
        return { stdout: `${repoRoot}\n`, stderr: ``, exitCode: 0 }
      }

      if (key === `-C ${repoRootPath} rev-parse --show-toplevel`) {
        return { stdout: `${repoRoot}\n`, stderr: ``, exitCode: 0 }
      }

      if (key === `-C ${repoRoot} remote get-url origin`) {
        return {
          stdout: `git@github.com:jasonkuhrt/flo.git\n`,
          stderr: ``,
          exitCode: 0,
        }
      }

      throw new Error(`Unhandled command: ${key}`)
    }

    const result = await discoverProjects({
      config,
      cwd: repoRoot,
      runner,
    })

    expect(result).toEqual([
      {
        name: `flo`,
        path: repoRoot,
        aliases: [`ff`],
        defaultSource: `github`,
        githubRepo: `jasonkuhrt/flo`,
        worktreeRoot: join(dirname(repoRoot), `.flo-checkouts`, `flo`),
        workspaceProfiles: {},
      },
    ])
  })
})
