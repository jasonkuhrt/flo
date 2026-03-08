#!/usr/bin/env node

import { basename } from 'pathe'

import { installClaudeHooks } from '#lib/claude'
import { FloError } from '#lib/errors'
import {
  doctorFlo,
  explainEnd,
  explainOpen,
  explainStart,
  formatFloContextEnv,
  endWork,
  getFloContext,
  initConfig,
  launchInteractive,
  listFloState,
  listRecentWork,
  openLastWorkspace,
  openWorkspace,
  previewInitOpen,
  previewInitStart,
  pruneFloState,
  statusFlo,
  startWork,
} from '#lib/flo'
import { handleClaudeHook, logFloUi, notifyFloUi, syncFloUi } from '#lib/ui'

const usage = `flo

Usage:
  flo
  flo open [selector] [--last] [--dry-run] [--json]
  flo start <selector> [--project <project>] [--dry-run] [--json]
  flo explain open [selector] [--last] [--json]
  flo explain start <selector> [--project <project>] [--json]
  flo explain end [selector] [--force] [--open-main] [--json]
  flo init preview open [selector] [--last] [--json]
  flo init preview start <selector> [--project <project>] [--json]
  flo context [--json|--env]
  flo status [--json]
  flo list [--project <project>] [--open] [--json]
  flo recent [--project <project>] [--limit <n>] [--json]
  flo doctor [--json]
  flo config init [--force] [--json]
  flo claude install-hooks [--json]
  flo end [selector] [--dry-run] [--force] [--open-main] [--json]
  flo prune [--dry-run] [--json]
  flo ui sync [--workspace <id>] [--phase <value|clear>] [--agents <n|clear>] [--claude <value|clear>] [--json]
  flo ui log [--workspace <id>] [--level <level>] [--source <source>] <message> [--json]
  flo ui notify [--workspace <id>] --title <title> [--subtitle <text>] [--body <text>] [--json]
  flo ui claude-hook <notification|session-start|pre-compact|subagent-start|subagent-stop> [--workspace <id>] [--json]
  flo help

Examples:
  flo
  flo open dotfiles
  flo open --last
  flo open heartbeat@feat-auth
  flo start 123
  flo start 123 --project dotfiles
  flo start gh:123
  flo start feat/cmux-launcher
  flo explain open dotfiles
  flo explain start 123 --project dotfiles
  flo explain end 123 --open-main
  flo init preview open dotfiles
  flo init preview start 123 --project dotfiles
  flo context --json
  flo context --env
  flo status
  flo recent
  flo doctor --json
  flo config init
  flo claude install-hooks
  flo end 123
  flo end 123 --open-main
  flo prune
  flo ui sync --phase compacting
  flo ui log --source claude "Compaction complete"
  flo ui notify --title "Claude needs attention" --body "Permission prompt waiting"
`

interface ParsedArgs {
  booleans: Set<string>
  named: Map<string, string>
  positional: string[]
}

const valueFlags = new Set([
  `--workspace`,
  `--project`,
  `--limit`,
  `--phase`,
  `--agents`,
  `--claude`,
  `--level`,
  `--source`,
  `--title`,
  `--subtitle`,
  `--body`,
])

const parseArgs = (args: string[]): ParsedArgs => {
  const booleans = new Set<string>()
  const named = new Map<string, string>()
  const positional: string[] = []

  for (let index = 0; index < args.length; index += 1) {
    const arg = args[index]
    if (arg === undefined) continue

    if (valueFlags.has(arg)) {
      const value = args[index + 1]
      if (value === undefined) {
        throw new FloError(`CLI_USAGE`, `Missing value for ${arg}.\n\n${usage}`)
      }

      named.set(arg.slice(2), value)
      index += 1
      continue
    }

    if (arg.startsWith(`--`)) {
      booleans.add(arg.slice(2))
      continue
    }

    positional.push(arg)
  }

  return {
    booleans,
    named,
    positional,
  }
}

const printResult = (value: unknown): void => {
  process.stdout.write(`${JSON.stringify(value, null, 2)}\n`)
}

const readStdin = async (): Promise<string> => {
  let text = ``

  for await (const chunk of process.stdin) {
    text += String(chunk)
  }

  return text
}

const printList = async (
  context: { cwd: string; env: NodeJS.ProcessEnv },
  json: boolean,
  projectSelector?: string,
  openOnly?: boolean,
): Promise<void> => {
  const result = await listFloState({
    context,
    ...(projectSelector === undefined ? {} : { projectSelector }),
    ...(openOnly === undefined ? {} : { openOnly }),
  })

  if (json) {
    printResult(result)
    return
  }

  for (const project of result.projects) {
    process.stdout.write(`${project.name}  ${project.path}\n`)
    for (const checkout of project.checkouts) {
      const label = checkout.isMain ? `main` : (checkout.branch ?? basename(checkout.path))
      const workspaceState =
        checkout.workspaceOpen === null
          ? `cmux:unknown`
          : checkout.workspaceOpen
            ? `cmux:open`
            : `cmux:closed`
      process.stdout.write(`  ${label}  ${checkout.path}  ${workspaceState}\n`)
    }
  }
}

const printRecents = async (
  context: { cwd: string; env: NodeJS.ProcessEnv },
  json: boolean,
  projectSelector?: string,
  limit?: number,
): Promise<void> => {
  const result = await listRecentWork({
    context,
    ...(projectSelector === undefined ? {} : { projectSelector }),
    ...(limit === undefined ? {} : { limit }),
  })

  if (json) {
    printResult(result)
    return
  }

  for (const item of result.items) {
    const checkoutLabel = item.isMain ? `main` : (item.branch ?? basename(item.checkoutPath))
    const workspaceState =
      item.workspaceOpen === null
        ? `cmux:unknown`
        : item.workspaceOpen
          ? `cmux:open`
          : `cmux:closed`
    process.stdout.write(
      `${item.lastOpenedAt}  ${item.selector}  [${checkoutLabel}]  ${workspaceState}\n`,
    )
  }
}

const printDoctor = async (
  context: { cwd: string; env: NodeJS.ProcessEnv },
  json: boolean,
): Promise<void> => {
  const result = await doctorFlo({ context })

  if (json) {
    printResult(result)
    return
  }

  process.stdout.write(`cwd  ${result.currentDirectory}\n`)
  process.stdout.write(
    `config  ${result.configExists ? `present` : `missing`}  ${result.configPath}\n`,
  )
  process.stdout.write(`cmux  ${result.cmuxAvailable ? `available` : `unavailable`}\n`)
  process.stdout.write(
    `project  ${result.currentProject === null ? `none` : `${result.currentProject.name}  ${result.currentProject.path}`}\n`,
  )
  process.stdout.write(
    `checkout  ${
      result.currentCheckout === null
        ? `none`
        : `${result.currentCheckout.isMain ? `main` : (result.currentCheckout.branch ?? basename(result.currentCheckout.path))}  ${result.currentCheckout.path}`
    }\n`,
  )

  for (const command of result.commands) {
    process.stdout.write(
      `command  ${command.key}  ${command.available ? `ok` : `missing`}  ${command.configured}\n`,
    )
  }
}

const printExplain = async (
  context: { cwd: string; env: NodeJS.ProcessEnv },
  json: boolean,
  parsed: ParsedArgs,
  rest: string[],
): Promise<void> => {
  const [subject, ...subjectArgs] = rest

  if (subject === undefined) {
    throw new FloError(`CLI_USAGE`, `flo explain requires a subject.\n\n${usage}`)
  }

  if (subject === `open`) {
    const [selector] = subjectArgs
    if (selector !== undefined && parsed.booleans.has(`last`)) {
      throw new FloError(
        `CLI_USAGE`,
        `flo explain open accepts either a selector or --last, not both.`,
      )
    }

    const result = await explainOpen({
      context,
      ...(selector === undefined ? {} : { selector }),
      ...(parsed.booleans.has(`last`) ? { last: true } : {}),
    })

    if (json) {
      printResult(result)
      return
    }

    process.stdout.write(`command  open\n`)
    process.stdout.write(`project  ${result.project.name}  ${result.project.path}\n`)
    process.stdout.write(
      `checkout  ${
        result.checkout.isMain ? `main` : (result.checkout.branch ?? basename(result.checkout.path))
      }  ${result.checkout.path}\n`,
    )
    process.stdout.write(
      `workspace  ${result.workspace.title}  ${result.workspace.identity}  ${result.workspace.action}\n`,
    )
    process.stdout.write(
      `init  split=${result.init.layout.splitDirection} focus=${result.init.layout.focus} secondary=${result.init.layout.secondaryPane ?? `none`}\n`,
    )
    process.stdout.write(
      `editor  ${result.init.editor.sessionName}  ${result.init.editor.command}\n`,
    )
    if (result.init.claude !== undefined) {
      process.stdout.write(
        `claude  ${result.init.claude.sessionName}  ${result.init.claude.command}\n`,
      )
    }
    return
  }

  if (subject === `start`) {
    const [selector] = subjectArgs
    if (selector === undefined) {
      throw new FloError(`CLI_USAGE`, `flo explain start requires a selector.\n\n${usage}`)
    }
    const explainProjectSelector = parsed.named.get(`project`)

    const result = await explainStart({
      context,
      selector,
      ...(explainProjectSelector === undefined ? {} : { projectSelector: explainProjectSelector }),
    })

    if (json) {
      printResult(result)
      return
    }

    process.stdout.write(`command  start\n`)
    process.stdout.write(`selector  ${result.selector}\n`)
    process.stdout.write(`project  ${result.project.name}  ${result.project.path}\n`)
    process.stdout.write(
      `checkout  ${
        result.checkout.isMain ? `main` : (result.checkout.branch ?? basename(result.checkout.path))
      }  ${result.checkout.path}\n`,
    )
    process.stdout.write(`checkout-action  ${result.createdCheckout ? `create` : `reuse`}\n`)
    process.stdout.write(
      `workspace  ${result.workspace.title}  ${result.workspace.identity}  ${result.workspace.action}\n`,
    )
    process.stdout.write(
      `init  split=${result.init.layout.splitDirection} focus=${result.init.layout.focus} secondary=${result.init.layout.secondaryPane ?? `none`}\n`,
    )
    process.stdout.write(
      `editor  ${result.init.editor.sessionName}  ${result.init.editor.command}\n`,
    )
    if (result.init.claude !== undefined) {
      process.stdout.write(
        `claude  ${result.init.claude.sessionName}  ${result.init.claude.command}\n`,
      )
    }
    if (result.issue !== undefined) {
      process.stdout.write(`issue  #${result.issue.number}  ${result.issue.title}\n`)
    }
    return
  }

  if (subject === `end`) {
    const [selector] = subjectArgs
    const result = await explainEnd({
      context,
      ...(selector === undefined ? {} : { selector }),
      ...(parsed.booleans.has(`force`) ? { force: true } : {}),
      ...(parsed.booleans.has(`open-main`) ? { openMain: true } : {}),
    })

    if (json) {
      printResult(result)
      return
    }

    process.stdout.write(`command  end\n`)
    process.stdout.write(`project  ${result.project.name}  ${result.project.path}\n`)
    process.stdout.write(
      `checkout  ${
        result.checkout.isMain ? `main` : (result.checkout.branch ?? basename(result.checkout.path))
      }  ${result.checkout.path}\n`,
    )
    process.stdout.write(
      `workspace  ${result.workspace.title}  ${result.workspace.identity}  ${result.workspace.action}\n`,
    )
    process.stdout.write(`editor-session  ${result.sessions.editor}\n`)
    process.stdout.write(`claude-session  ${result.sessions.claude}\n`)
    process.stdout.write(`remove-checkout  yes\n`)
    process.stdout.write(`dirty-checkout  ${result.dirtyCheckoutAllowed ? `allow` : `block`}\n`)
    if (result.reopensMainWorkspace !== undefined) {
      process.stdout.write(
        `reopen-main  ${result.reopensMainWorkspace.title}  ${result.reopensMainWorkspace.action}\n`,
      )
    }
    return
  }

  throw new FloError(`CLI_USAGE`, `Unknown flo explain subject.\n\n${usage}`)
}

const printInitPreview = async (
  context: { cwd: string; env: NodeJS.ProcessEnv },
  json: boolean,
  parsed: ParsedArgs,
  rest: string[],
): Promise<void> => {
  const [subcommand, subject, ...subjectArgs] = rest
  if (subcommand !== `preview` || subject === undefined) {
    throw new FloError(`CLI_USAGE`, `flo init requires the preview subcommand.\n\n${usage}`)
  }

  if (subject === `open`) {
    const [selector] = subjectArgs
    if (selector !== undefined && parsed.booleans.has(`last`)) {
      throw new FloError(
        `CLI_USAGE`,
        `flo init preview open accepts either a selector or --last, not both.`,
      )
    }

    const result = await previewInitOpen({
      context,
      ...(selector === undefined ? {} : { selector }),
      ...(parsed.booleans.has(`last`) ? { last: true } : {}),
    })

    if (json) {
      printResult(result)
      return
    }

    process.stdout.write(`command  init-preview open\n`)
    process.stdout.write(`project  ${result.project.name}  ${result.project.path}\n`)
    process.stdout.write(
      `checkout  ${
        result.checkout.isMain ? `main` : (result.checkout.branch ?? basename(result.checkout.path))
      }  ${result.checkout.path}\n`,
    )
    process.stdout.write(
      `workspace  ${result.workspace.title}  ${result.workspace.identity}  ${result.workspace.action}\n`,
    )
    process.stdout.write(`applies-now  ${result.appliesNow ? `yes` : `no`}\n`)
    process.stdout.write(
      `init  split=${result.init.layout.splitDirection} focus=${result.init.layout.focus} secondary=${result.init.layout.secondaryPane ?? `none`}\n`,
    )
    process.stdout.write(
      `editor  ${result.init.editor.sessionName}  ${result.init.editor.command}\n`,
    )
    if (result.init.claude !== undefined) {
      process.stdout.write(
        `claude  ${result.init.claude.sessionName}  ${result.init.claude.command}\n`,
      )
    }
    return
  }

  if (subject === `start`) {
    const [selector] = subjectArgs
    if (selector === undefined) {
      throw new FloError(`CLI_USAGE`, `flo init preview start requires a selector.\n\n${usage}`)
    }
    const initProjectSelector = parsed.named.get(`project`)
    const result = await previewInitStart({
      context,
      selector,
      ...(initProjectSelector === undefined ? {} : { projectSelector: initProjectSelector }),
    })

    if (json) {
      printResult(result)
      return
    }

    process.stdout.write(`command  init-preview start\n`)
    process.stdout.write(`selector  ${result.selector}\n`)
    process.stdout.write(`project  ${result.project.name}  ${result.project.path}\n`)
    process.stdout.write(
      `checkout  ${
        result.checkout.isMain ? `main` : (result.checkout.branch ?? basename(result.checkout.path))
      }  ${result.checkout.path}\n`,
    )
    process.stdout.write(
      `workspace  ${result.workspace.title}  ${result.workspace.identity}  ${result.workspace.action}\n`,
    )
    process.stdout.write(`applies-now  ${result.appliesNow ? `yes` : `no`}\n`)
    process.stdout.write(
      `init  split=${result.init.layout.splitDirection} focus=${result.init.layout.focus} secondary=${result.init.layout.secondaryPane ?? `none`}\n`,
    )
    process.stdout.write(
      `editor  ${result.init.editor.sessionName}  ${result.init.editor.command}\n`,
    )
    if (result.init.claude !== undefined) {
      process.stdout.write(
        `claude  ${result.init.claude.sessionName}  ${result.init.claude.command}\n`,
      )
    }
    if (result.issue !== undefined) {
      process.stdout.write(`issue  #${result.issue.number}  ${result.issue.title}\n`)
    }
    return
  }

  throw new FloError(`CLI_USAGE`, `Unknown flo init preview subject.\n\n${usage}`)
}

const printStatus = async (
  context: { cwd: string; env: NodeJS.ProcessEnv },
  json: boolean,
): Promise<void> => {
  const result = await statusFlo({ context })

  if (json) {
    printResult(result)
    return
  }

  process.stdout.write(`cwd  ${result.currentDirectory}\n`)
  process.stdout.write(`cmux  ${result.cmuxAvailable ? `available` : `unavailable`}\n`)
  process.stdout.write(
    `project  ${result.currentProject === null ? `none` : `${result.currentProject.name}  ${result.currentProject.path}`}\n`,
  )
  process.stdout.write(
    `checkout  ${
      result.currentCheckout === null
        ? `none`
        : `${result.currentCheckout.isMain ? `main` : (result.currentCheckout.branch ?? basename(result.currentCheckout.path))}  ${result.currentCheckout.path}`
    }\n`,
  )
  process.stdout.write(
    `workspace  ${
      result.expectedWorkspace === null
        ? `none`
        : `${result.expectedWorkspace.title}  ${result.expectedWorkspace.identity}`
    }\n`,
  )
  process.stdout.write(
    `active  ${
      result.activeWorkspace === null
        ? `closed`
        : `${result.activeWorkspace.id}  ${result.activeWorkspace.title}`
    }\n`,
  )

  if (result.issue !== undefined) {
    process.stdout.write(`issue  #${result.issue.number}  ${result.issue.title}\n`)
  }
}

const parseAgentsOption = (value: string): number | null => {
  if (value === `clear`) return null

  const parsed = Number.parseInt(value, 10)
  if (Number.isNaN(parsed) || parsed < 0) {
    throw new FloError(`CLI_USAGE`, `--agents must be a non-negative integer or "clear".`)
  }

  return parsed
}

const parseLimitOption = (value: string): number => {
  const parsed = Number.parseInt(value, 10)
  if (Number.isNaN(parsed) || parsed <= 0) {
    throw new FloError(`CLI_USAGE`, `--limit must be a positive integer.`)
  }

  return parsed
}

const normalizeOptionalStatus = (value: string): string | null => (value === `clear` ? null : value)

const main = async (): Promise<void> => {
  const parsed = parseArgs(process.argv.slice(2))
  const json = parsed.booleans.has(`json`)
  const dryRun = parsed.booleans.has(`dry-run`)
  const force = parsed.booleans.has(`force`)
  const projectSelector = parsed.named.get(`project`)
  const limit = parsed.named.get(`limit`)
  const phase = parsed.named.get(`phase`)
  const agents = parsed.named.get(`agents`)
  const claude = parsed.named.get(`claude`)
  const level = parsed.named.get(`level`)
  const source = parsed.named.get(`source`)
  const subtitle = parsed.named.get(`subtitle`)
  const body = parsed.named.get(`body`)
  const [command, ...rest] = parsed.positional
  const context = {
    cwd: process.cwd(),
    env: process.env,
  }

  switch (command) {
    case undefined: {
      const selection = await launchInteractive({
        context,
        dryRun,
      })

      if (selection === null) return

      if (json || dryRun) {
        printResult(selection)
        return
      }

      const result = await openWorkspace({
        context,
        selector: selection.checkout.isMain
          ? selection.project.name
          : `${selection.project.name}@${selection.checkout.branch ?? basename(selection.checkout.path)}`,
      })
      printResult(result)
      return
    }
    case `open`: {
      const [selector] = rest
      if (selector !== undefined && parsed.booleans.has(`last`)) {
        throw new FloError(`CLI_USAGE`, `flo open accepts either a selector or --last, not both.`)
      }
      const result = parsed.booleans.has(`last`)
        ? await openLastWorkspace({
            context,
            dryRun,
          })
        : await openWorkspace({
            context,
            ...(selector === undefined ? {} : { selector }),
            dryRun,
          })

      if (json || dryRun) {
        printResult(result)
        return
      }

      process.stdout.write(`${result.workspaceTitle}\n`)
      return
    }
    case `start`: {
      const [selector] = rest
      if (selector === undefined) {
        throw new FloError(`CLI_USAGE`, `flo start requires a selector.\n\n${usage}`)
      }

      const result = await startWork({
        context,
        selector,
        ...(projectSelector === undefined ? {} : { projectSelector }),
        dryRun,
      })

      if (json || dryRun) {
        printResult(result)
        return
      }

      process.stdout.write(`${result.workspaceTitle}\n`)
      return
    }
    case `explain`:
      await printExplain(context, json, parsed, rest)
      return
    case `init`:
      await printInitPreview(context, json, parsed, rest)
      return
    case `list`:
      await printList(context, json, projectSelector, parsed.booleans.has(`open`))
      return
    case `recent`:
      await printRecents(
        context,
        json,
        projectSelector,
        limit === undefined ? undefined : parseLimitOption(limit),
      )
      return
    case `context`: {
      if (json && parsed.booleans.has(`env`)) {
        throw new FloError(`CLI_USAGE`, `flo context accepts either --json or --env, not both.`)
      }

      const result = await getFloContext({ context })

      if (json) {
        printResult(result)
        return
      }

      if (parsed.booleans.has(`env`)) {
        process.stdout.write(`${formatFloContextEnv(result)}\n`)
        return
      }

      process.stdout.write(`${result.workspaceTitle}\n`)
      return
    }
    case `status`:
      await printStatus(context, json)
      return
    case `doctor`:
      await printDoctor(context, json)
      return
    case `config`: {
      const [subcommand] = rest
      if (subcommand !== `init`) {
        throw new FloError(`CLI_USAGE`, `Unknown flo config subcommand.\n\n${usage}`)
      }

      const result = await initConfig({
        context,
        force,
      })
      printResult(result)
      return
    }
    case `claude`: {
      const [subcommand] = rest
      if (subcommand !== `install-hooks`) {
        throw new FloError(`CLI_USAGE`, `Unknown flo claude subcommand.\n\n${usage}`)
      }

      const result = await installClaudeHooks({
        context,
      })
      printResult(result)
      return
    }
    case `end`: {
      const [selector] = rest
      const result = await endWork({
        context,
        ...(selector === undefined ? {} : { selector }),
        dryRun,
        force,
        openMain: parsed.booleans.has(`open-main`),
      })

      if (json || dryRun) {
        printResult(result)
        return
      }

      process.stdout.write(`${result.workspaceTitle}\n`)
      return
    }
    case `prune`: {
      const result = await pruneFloState({
        context,
        dryRun,
      })

      if (json || dryRun) {
        printResult(result)
        return
      }

      process.stdout.write(
        `pruned ${result.projects.length} project(s); closed ${result.closedWorkspaces.length} workspace(s)\n`,
      )
      return
    }
    case `ui`: {
      const [uiCommand] = rest
      const workspaceId = parsed.named.get(`workspace`)

      switch (uiCommand) {
        case undefined:
          throw new FloError(`CLI_USAGE`, `flo ui requires a subcommand.\n\n${usage}`)
        case `sync`: {
          const result = await syncFloUi({
            context,
            ...(workspaceId === undefined ? {} : { workspaceId }),
            ...(phase === undefined ? {} : { phase: normalizeOptionalStatus(phase) }),
            ...(agents === undefined ? {} : { agents: parseAgentsOption(agents) }),
            ...(claude === undefined ? {} : { claude: normalizeOptionalStatus(claude) }),
          })

          if (json) {
            printResult(result)
          }

          return
        }
        case `log`: {
          const message = rest.slice(1).join(` `).trim()
          if (message.length === 0) {
            throw new FloError(`CLI_USAGE`, `flo ui log requires a message.\n\n${usage}`)
          }

          const result = await logFloUi({
            context,
            ...(workspaceId === undefined ? {} : { workspaceId }),
            message,
            ...(level === undefined ? {} : { level }),
            ...(source === undefined ? {} : { source }),
          })

          if (json) {
            printResult(result)
          }

          return
        }
        case `notify`: {
          const title = parsed.named.get(`title`)
          if (title === undefined) {
            throw new FloError(`CLI_USAGE`, `flo ui notify requires --title.\n\n${usage}`)
          }

          const result = await notifyFloUi({
            context,
            ...(workspaceId === undefined ? {} : { workspaceId }),
            title,
            ...(subtitle === undefined ? {} : { subtitle }),
            ...(body === undefined ? {} : { body }),
          })

          if (json) {
            printResult(result)
          }

          return
        }
        case `claude-hook`: {
          const hook = rest[1]
          if (
            hook !== `notification` &&
            hook !== `session-start` &&
            hook !== `pre-compact` &&
            hook !== `subagent-start` &&
            hook !== `subagent-stop`
          ) {
            throw new FloError(
              `CLI_USAGE`,
              `flo ui claude-hook requires a supported hook name.\n\n${usage}`,
            )
          }

          const result = await handleClaudeHook({
            context,
            ...(workspaceId === undefined ? {} : { workspaceId }),
            hook,
            input: await readStdin(),
          })

          if (json) {
            printResult(result)
          }

          return
        }
        default:
          throw new FloError(`CLI_USAGE`, `Unknown ui command "${uiCommand}".\n\n${usage}`)
      }
    }
    case `help`:
    case `--help`:
    case `-h`:
      process.stdout.write(usage)
      return
    default:
      throw new FloError(`CLI_USAGE`, `Unknown command "${command}".\n\n${usage}`)
  }
}

await main().catch((error: unknown) => {
  if (error instanceof FloError) {
    process.stderr.write(`${error.message}\n`)
    process.exitCode = 1
    return
  }

  process.stderr.write(`${String(error)}\n`)
  process.exitCode = 1
})
