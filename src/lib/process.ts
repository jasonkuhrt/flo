import * as Command from '@effect/platform/Command'
import { NodeContext } from '@effect/platform-node'
import * as Chunk from 'effect/Chunk'
import { Effect, Stream } from 'effect'

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

const decodeUtf8 = (chunks: ReadonlyArray<Uint8Array>): string => {
  const size = chunks.reduce((total, chunk) => total + chunk.byteLength, 0)
  const output = new Uint8Array(size)
  let offset = 0

  for (const chunk of chunks) {
    output.set(chunk, offset)
    offset += chunk.byteLength
  }

  return new TextDecoder().decode(output)
}

const collectOutput = (stream: Stream.Stream<Uint8Array, unknown>) =>
  Stream.runCollect(stream).pipe(Effect.map((chunks) => decodeUtf8(Chunk.toReadonlyArray(chunks))))

export const systemRunner: CommandRunner = async (command, args = [], options = {}) =>
  Effect.runPromise(
    Effect.scoped(
      Effect.gen(function* () {
        let program = Command.make(command, ...args)

        if (options.cwd !== undefined) {
          program = Command.workingDirectory(program, options.cwd)
        }

        if (options.input !== undefined) {
          program = Command.feed(program, options.input)
        }

        const process = yield* Command.start(program)
        const [stdout, stderr, exitCode] = yield* Effect.all(
          [collectOutput(process.stdout), collectOutput(process.stderr), process.exitCode],
          { concurrency: `unbounded` },
        )

        return {
          stdout,
          stderr,
          exitCode,
        }
      }).pipe(
        Effect.provide(NodeContext.layer),
        Effect.catchAll((error) =>
          Effect.succeed({
            stdout: ``,
            stderr: String(error),
            exitCode: 127,
          }),
        ),
      ),
    ),
  )
