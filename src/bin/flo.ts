#!/usr/bin/env node

import { basename } from 'node:path'

import { FloError } from '#lib/errors'
import { launchInteractive, listFloState, openWorkspace, startWork } from '#lib/flo'

const usage = `flo

Usage:
  flo
  flo open [selector] [--dry-run] [--json]
  flo start <selector> [--dry-run] [--json]
  flo list [--json]
  flo help

Examples:
  flo
  flo open dotfiles
  flo open heartbeat@feat-auth
  flo start 123
  flo start gh:123
  flo start feat/cmux-launcher
  flo list --json
`

interface CliOptions {
  json: boolean
  dryRun: boolean
}

const parseOptions = (args: string[]): { options: CliOptions; positional: string[] } => {
  const positional: string[] = []
  const options: CliOptions = {
    json: false,
    dryRun: false,
  }

  for (const arg of args) {
    if (arg === `--json`) options.json = true
    else if (arg === `--dry-run`) options.dryRun = true
    else positional.push(arg)
  }

  return { options, positional }
}

const printResult = (value: unknown): void => {
  process.stdout.write(`${JSON.stringify(value, null, 2)}\n`)
}

const printList = async (json: boolean): Promise<void> => {
  const result = await listFloState({
    context: {
      cwd: process.cwd(),
      env: process.env,
    },
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

const main = async (): Promise<void> => {
  const { options, positional } = parseOptions(process.argv.slice(2))
  const [command, ...rest] = positional
  const context = {
    cwd: process.cwd(),
    env: process.env,
  }

  switch (command) {
    case undefined: {
      const selection = await launchInteractive({
        context,
        dryRun: options.dryRun,
      })

      if (selection === null) return

      if (options.json || options.dryRun) {
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
      const result = await openWorkspace({
        context,
        ...(selector === undefined ? {} : { selector }),
        dryRun: options.dryRun,
      })

      if (options.json || options.dryRun) {
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
        dryRun: options.dryRun,
      })

      if (options.json || options.dryRun) {
        printResult(result)
        return
      }

      process.stdout.write(`${result.workspaceTitle}\n`)
      return
    }
    case `list`:
      await printList(options.json)
      return
    case `end`:
    case `prune`:
      throw new FloError(
        `CLI_UNIMPLEMENTED`,
        `flo ${command} is planned but not implemented in v1 yet.`,
      )
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
