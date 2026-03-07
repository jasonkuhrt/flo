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
  /** Preferences accessible in the `recent-work` command */
  export type RecentWork = ExtensionPreferences & {
  /** Flo Binary - Path or command name for the Flo CLI. */
  "floBinary": string
}
  /** Preferences accessible in the `end-work` command */
  export type EndWork = ExtensionPreferences & {
  /** Flo Binary - Path or command name for the Flo CLI. */
  "floBinary": string
}
  /** Preferences accessible in the `open-last` command */
  export type OpenLast = ExtensionPreferences & {
  /** Flo Binary - Path or command name for the Flo CLI. */
  "floBinary": string
}
}

declare namespace Arguments {
  /** Arguments passed to the `open-workspace` command */
  export type OpenWorkspace = {}
  /** Arguments passed to the `start-work` command */
  export type StartWork = {}
  /** Arguments passed to the `recent-work` command */
  export type RecentWork = {}
  /** Arguments passed to the `end-work` command */
  export type EndWork = {}
  /** Arguments passed to the `open-last` command */
  export type OpenLast = {}
}

