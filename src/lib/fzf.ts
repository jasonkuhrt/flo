import { FloError } from '#lib/errors'
import type { CommandRunner } from '#lib/process'

export interface LauncherItem {
  selector: string
  label: string
  path: string
}

export const runFzf = async (args: {
  runner: CommandRunner
  fzfBin: string
  items: LauncherItem[]
}): Promise<LauncherItem | null> => {
  if (args.items.length === 0) {
    throw new FloError(`LAUNCHER_EMPTY`, `No projects or checkouts are available to launch.`)
  }

  const input = args.items
    .map((item) => [item.selector, item.label, item.path].join(`\t`))
    .join(`\n`)

  const result = await args.runner(
    args.fzfBin,
    [`--delimiter`, `\t`, `--with-nth`, `2..`, `--prompt`, `flo > `],
    { input },
  )

  if (result.exitCode === 130 || result.stdout.trim().length === 0) {
    return null
  }

  if (result.exitCode !== 0) {
    throw new FloError(`FZF_FAILED`, `fzf failed: ${result.stderr || result.stdout}`)
  }

  const [selector] = result.stdout.trim().split(`\t`)
  const selectedItem = args.items.find((item) => item.selector === selector)

  if (selectedItem === undefined) {
    throw new FloError(`FZF_INVALID_SELECTION`, `fzf returned an unknown selection.`)
  }

  return selectedItem
}
