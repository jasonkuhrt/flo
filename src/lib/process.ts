import { execa } from 'execa'

export interface CommandResult {
  stdout: string
  stderr: string
  exitCode: number
}

export interface CommandOptions {
  cwd?: string
  input?: string
}

export type CommandRunner = (
  command: string,
  args?: string[],
  options?: CommandOptions,
) => Promise<CommandResult>

export const systemRunner: CommandRunner = async (command, args = [], options = {}) => {
  const result = await execa(command, args, {
    ...(options.cwd === undefined ? {} : { cwd: options.cwd }),
    ...(options.input === undefined ? {} : { input: options.input }),
    reject: false,
    stderr: `pipe`,
    stdout: `pipe`,
  })

  return {
    stdout: result.stdout,
    stderr: result.stderr,
    exitCode: result.exitCode ?? 0,
  }
}
