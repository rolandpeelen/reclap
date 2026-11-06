/*** The definition of a program or subcommand.

Mirrors `clap::Command`. Every function returns a new definition. The parser adds
`-h, --help`, `-V, --version` (when a version is set) and a `help` subcommand (when
there are subcommands) unless arguments or subcommands with those names exist. */

/** The fields are public; the equation with the internal `ClapCommandDefinition.t` lets the
parser and the help renderer share the type without a module cycle. */
type rec t = ClapCommandDefinition.t = {
  name: string,
  aliases: array<string>,
  visibleAliases: array<string>,
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

/** Sets the author. Stored on the command; help rendering does not print it. */
let author: (t, string) => t

/** Adds a hidden alternative name for a subcommand. */
let alias: (t, string) => t

/** Adds an alternative name for a subcommand that help shows as `[alias: x]`. */
let visibleAlias: (t, string) => t

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

/** Adds `-h, --help`, `-V, --version` (when a version is set) and the `help` subcommand (when
there are subcommands) unless the command defines them already. Mirrors `Command::build` for
one level; it is idempotent, and the parser applies it to each command it enters. */
let build: t => t

/** Renders the help that `-h` prints. */
let renderHelp: t => string

/** Renders the help that `--help` prints. */
let renderLongHelp: t => string

/** Renders the usage line, without the `Usage: ` prefix. */
let renderUsage: t => string

/** Renders the version line that `-V` prints, such as `greet 1.0.0`. */
let renderVersion: t => string
