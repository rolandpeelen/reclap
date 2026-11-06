/*** Renders help, usage and version text exactly as clap 4 does with colour and wrapping off.
Internal to reclap; the rules are specified in `docs/clap-output-format.md`.

Every function expects a command that `ClapCommandDefinition.build` has completed. `binName`
is the name that starts the usage line: the program name, or the parent's usage name and the
subcommand's name. */

/** `-h` output (`Short`) or `--help` output (`Long`). */
type mode =
  | Short
  | Long

/** Joins the non-empty words with single spaces. */
let joinWords: array<string> => string

/** Renders a named argument as in usage lines: `--name <NAME>`, `--shout`, `-v...`. */
let renderUsageSpec: ClapArg.t => string

/** Renders the usage line that help and most errors show, without `Usage: `. */
let renderUsage: (ClapCommandDefinition.t, ~binName: string) => string

/** Renders the usage line built from the required arguments and the arguments with ids in
`used`, as clap does for some errors. When `used` is empty callers show `renderUsage`. */
let renderSmartUsage: (ClapCommandDefinition.t, ~binName: string, ~used: array<string>) => string

/** Renders help output, ending in exactly one newline. `env` supplies the values shown in
`[env: NAME=VALUE]`. */
let render: (ClapCommandDefinition.t, ~binName: string, ~mode: mode, ~env: Dict.t<string>) => string

/** Renders the version line, `name version` and a newline. */
let renderVersion: ClapCommandDefinition.t => string
