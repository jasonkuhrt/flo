/// <reference types="@raycast/api">

/* 🚧 🚧 🚧
 * This file is auto-generated from the extension's manifest.
 * Do not modify manually. Instead, update the `package.json` file.
 * 🚧 🚧 🚧 */

/* eslint-disable @typescript-eslint/ban-types */

type ExtensionPreferences = {}

/** Preferences accessible in all the extension's commands */
declare type Preferences = ExtensionPreferences

declare namespace Preferences {
  /** Preferences accessible in the `open-workspace` command */
  export type OpenWorkspace = ExtensionPreferences & {
  /** Flo Binary - Path or command name for the Flo CLI. */
  "floBinary": string
}
  /** Preferences accessible in the `start-work` command */
  export type StartWork = ExtensionPreferences & {
  /** Flo Binary - Path or command name for the Flo CLI. */
  "floBinary": string
}
}

declare namespace Arguments {
  /** Arguments passed to the `open-workspace` command */
  export type OpenWorkspace = {}
  /** Arguments passed to the `start-work` command */
  export type StartWork = {}
}

