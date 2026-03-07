import * as Command from "@effect/platform/Command";
import { NodeContext } from "@effect/platform-node";
import * as Chunk from "effect/Chunk";
import { Effect, Stream } from "effect";
import { basename } from "pathe";

import { getPreferenceValues } from "@raycast/api";

interface Preferences {
  floBinary?: string;
}

export interface FloListCheckout {
  path: string;
  branch: string | null;
  isMain: boolean;
  workspaceIdentity: string;
  workspaceTitle: string;
  workspaceOpen: boolean | null;
}

export interface FloListProject {
  name: string;
  path: string;
  defaultSource?: string;
  githubRepo?: string;
  checkouts: FloListCheckout[];
}

export interface FloListResult {
  projects: FloListProject[];
}

const floBinary = (): string =>
  getPreferenceValues<Preferences>().floBinary ?? "flo";

const decodeUtf8 = (chunks: ReadonlyArray<Uint8Array>): string => {
  const size = chunks.reduce((total, chunk) => total + chunk.byteLength, 0);
  const output = new Uint8Array(size);
  let offset = 0;

  for (const chunk of chunks) {
    output.set(chunk, offset);
    offset += chunk.byteLength;
  }

  return new TextDecoder().decode(output);
};

const collectOutput = (stream: Stream.Stream<Uint8Array, unknown>) =>
  Stream.runCollect(stream).pipe(
    Effect.map((chunks) => decodeUtf8(Chunk.toReadonlyArray(chunks))),
  );

const runCommand = (
  command: string,
  args: ReadonlyArray<string>,
): Promise<string> =>
  Effect.runPromise(
    Effect.scoped(
      Effect.gen(function* () {
        const process = yield* Command.start(Command.make(command, ...args));
        const [stdout, stderr, exitCode] = yield* Effect.all(
          [
            collectOutput(process.stdout),
            collectOutput(process.stderr),
            process.exitCode,
          ],
          { concurrency: `unbounded` },
        );

        if (Number(exitCode) !== 0) {
          return yield* Effect.fail(
            new Error(stderr.trim() || stdout.trim() || `Command failed`),
          );
        }

        return stdout.trim();
      }).pipe(Effect.provide(NodeContext.layer)),
    ),
  );

export const runFlo = async (args: string[]): Promise<string> =>
  runCommand(floBinary(), args);

export const runFloJson = async <T>(args: string[]): Promise<T> => {
  const stdout = await runFlo([...args, "--json"]);
  return JSON.parse(stdout) as T;
};

export const checkoutSelector = (
  project: FloListProject,
  checkout: FloListCheckout,
): string =>
  checkout.isMain
    ? project.name
    : `${project.name}@${checkout.branch ?? basename(checkout.path)}`;
