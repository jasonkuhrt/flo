import { FileSystem } from '@effect/platform'
import { NodeContext } from '@effect/platform-node'
import { Effect } from 'effect'
import { join } from 'pathe'

export interface DirectoryEntry {
  name: string
  type: FileSystem.File.Type
}

export const pathExists = (path: string): Promise<boolean> =>
  Effect.runPromise(
    Effect.gen(function* () {
      const fs = yield* FileSystem.FileSystem
      return yield* fs.exists(path)
    }).pipe(Effect.provide(NodeContext.layer)),
  )

export const readFileString = (path: string): Promise<string> =>
  Effect.runPromise(
    Effect.gen(function* () {
      const fs = yield* FileSystem.FileSystem
      return yield* fs.readFileString(path)
    }).pipe(Effect.provide(NodeContext.layer)),
  )

export const writeFileString = (path: string, contents: string): Promise<void> =>
  Effect.runPromise(
    Effect.gen(function* () {
      const fs = yield* FileSystem.FileSystem
      yield* fs.writeFileString(path, contents)
    }).pipe(Effect.provide(NodeContext.layer)),
  )

export const makeDirectoryRecursive = (path: string): Promise<void> =>
  Effect.runPromise(
    Effect.gen(function* () {
      const fs = yield* FileSystem.FileSystem
      yield* fs.makeDirectory(path, { recursive: true })
    }).pipe(Effect.provide(NodeContext.layer)),
  )

export const realPath = (path: string): Promise<string> =>
  Effect.runPromise(
    Effect.gen(function* () {
      const fs = yield* FileSystem.FileSystem
      return yield* fs.realPath(path)
    }).pipe(Effect.provide(NodeContext.layer)),
  )

export const readDirectoryEntries = (path: string): Promise<DirectoryEntry[]> =>
  Effect.runPromise(
    Effect.gen(function* () {
      const fs = yield* FileSystem.FileSystem
      const names = yield* fs.readDirectory(path)

      return yield* Effect.all(
        names.map((name) =>
          fs.stat(join(path, name)).pipe(
            Effect.map((info) => ({
              name,
              type: info.type,
            })),
          ),
        ),
        { concurrency: `unbounded` },
      )
    }).pipe(Effect.provide(NodeContext.layer)),
  )
