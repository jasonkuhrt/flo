import * as Command from '@effect/platform/Command'
import { NodeContext } from '@effect/platform-node'
import * as Chunk from 'effect/Chunk'
import { Deferred, Effect, Ref, Stream } from 'effect'

export interface CommandResult {
  stdout: string
  stderr: string
  exitCode: number
}

export interface CommandOptions {
  cwd?: string
  input?: string
}

export type CommandSignal = `SIGINT` | `SIGTERM`

export interface CommandUntilOptions extends CommandOptions {
  readyWhen: string | RegExp | ((output: string) => boolean)
  terminateSignal?: CommandSignal
}

export type CommandRunner = (
  command: string,
  args?: string[],
  options?: CommandOptions,
) => Promise<CommandResult>

export interface CommandUntilResult extends CommandResult {
  matched: boolean
}

export type CommandUntilRunner = (
  command: string,
  args?: string[],
  options?: CommandUntilOptions,
) => Promise<CommandUntilResult>

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

const outputMatcher = (
  readyWhen: CommandUntilOptions[`readyWhen`],
): ((output: string) => boolean) => {
  if (typeof readyWhen === `string`) {
    return (output) => output.includes(readyWhen)
  }

  if (readyWhen instanceof RegExp) {
    return (output) => readyWhen.test(output)
  }

  return readyWhen
}

export const systemRunnerUntil: CommandUntilRunner = async (command, args = [], options) =>
  Effect.runPromise(
    Effect.scoped(
      Effect.gen(function* () {
        if (options === undefined) {
          return {
            stdout: ``,
            stderr: `Missing readyWhen option`,
            exitCode: 127,
            matched: false,
          }
        }

        const ready = outputMatcher(options.readyWhen)
        const state = yield* Ref.make({
          stdout: ``,
          stderr: ``,
          combined: ``,
        })
        const matchedRef = yield* Ref.make(false)
        const matchedDeferred = yield* Deferred.make<void>()

        const append =
          (channel: `stdout` | `stderr`) =>
          (chunk: Uint8Array): Effect.Effect<void> =>
            Effect.gen(function* () {
              const text = new TextDecoder().decode(chunk)
              const next = yield* Ref.updateAndGet(state, (current) => ({
                stdout: channel === `stdout` ? current.stdout + text : current.stdout,
                stderr: channel === `stderr` ? current.stderr + text : current.stderr,
                combined: current.combined + text,
              }))
              const alreadyMatched = yield* Ref.get(matchedRef)

              if (!alreadyMatched && ready(next.combined)) {
                yield* Ref.set(matchedRef, true)
                yield* Effect.ignore(Deferred.succeed(matchedDeferred, undefined))
              }
            })

        let program = Command.make(command, ...args)

        if (options.cwd !== undefined) {
          program = Command.workingDirectory(program, options.cwd)
        }

        if (options.input !== undefined) {
          program = Command.feed(program, options.input)
        }

        const process = yield* Command.start(program)

        yield* Effect.forkScoped(Stream.runForEach(process.stdout, append(`stdout`)))
        yield* Effect.forkScoped(Stream.runForEach(process.stderr, append(`stderr`)))

        const race = yield* Effect.raceFirst(
          Deferred.await(matchedDeferred).pipe(Effect.as({ matched: true as const })),
          process.exitCode.pipe(Effect.map((exitCode) => ({ matched: false as const, exitCode }))),
        )

        if (race.matched) {
          yield* Effect.ignore(process.kill(options.terminateSignal ?? `SIGINT`))
        }

        const snapshot = yield* Ref.get(state)
        const matched = yield* Ref.get(matchedRef)
        const exitCode = race.matched ? 0 : Number(race.exitCode)

        return {
          stdout: snapshot.stdout,
          stderr: snapshot.stderr,
          exitCode,
          matched,
        }
      }).pipe(
        Effect.provide(NodeContext.layer),
        Effect.catchAll((error) =>
          Effect.succeed({
            stdout: ``,
            stderr: String(error),
            exitCode: 127,
            matched: false,
          }),
        ),
      ),
    ),
  )
