/*** The definition of a program or subcommand.

Mirrors `clap::Command`. Every function returns a new definition. The parser adds
`-h, --help`, `-V, --version` (when a version is set) and a `help` subcommand (when
there are subcommands) unless arguments or subcommands with those names exist. */

type rec t = {
  name: string,
  aliases: array<string>,
  version: option<string>,
  about: option<string>,
  longAbout: option<string>,
  author: option<string>,
  args: array<ClapArg.t>,
  subcommands: array<t>,
  subcommandRequired: bool,
  argRequiredElseHelp: bool,
  hidden: bool,
}

/** Creates a command with the given name and no arguments. */
let make: string => t

/** Sets the version printed by `-V, --version`. */
let version: (t, string) => t

/** Sets the description shown by `-h` and in the parent's command list. */
let about: (t, string) => t

/** Sets the description shown by `--help`. */
let longAbout: (t, string) => t

/** Sets the author. */
let author: (t, string) => t

/** Adds a hidden alternative name for a subcommand. */
let alias: (t, string) => t

/** Appends an argument. */
let arg: (t, ClapArg.t) => t

/** Appends a subcommand. */
let subcommand: (t, t) => t

/** Sets whether parsing fails when no subcommand is given. */
let subcommandRequired: (t, bool) => t

/** Sets whether a call without any arguments prints help to stderr and fails. */
let argRequiredElseHelp: (t, bool) => t

/** Hides a subcommand from its parent's help. */
let hide: t => t

/** Renders the help that `-h` prints. */
let renderHelp: t => string

/** Renders the help that `--help` prints. */
let renderLongHelp: t => string

/** Renders the usage line, without the `Usage: ` prefix. */
let renderUsage: t => string

/** Renders the version line that `-V` prints, such as `greet 1.0.0`. */
let renderVersion: t => string
