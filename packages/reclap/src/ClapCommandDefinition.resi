/*** The command definition record and the queries that the parser and the help renderer
share. Internal to reclap: `ClapCommand` re-exports the type; this module exists so that
`ClapHelp` can render a command before `ClapCommand` is defined. */

type rec t = {
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

/** Returns a command with no arguments, subcommands or texts. */
let make: string => t

/** Returns whether this is the automatic `help` subcommand that `build` adds. */
let isHelpSubcommand: t => bool

/** Adds `-h, --help`, `-V, --version` when a version is set, and the `help` subcommand when
there are subcommands, unless the command already defines them. Mirrors `Command::build` for
one level. Idempotent. */
let build: t => t

/** Returns the positional arguments in index order. */
let positionals: t => array<ClapArg.t>

/** Returns the arguments with a short or long name, in declaration order. */
let named: t => array<ClapArg.t>

/** Finds the argument with this long name or alias. */
let findLong: (t, string) => option<ClapArg.t>

/** Finds the argument with this short name. */
let findShort: (t, string) => option<ClapArg.t>

/** Finds the subcommand with this name or alias. */
let findSubcommand: (t, string) => option<t>

/** Lists every subcommand name and alias, hidden ones too, as clap's `MissingSubcommand`
does. */
let allSubcommandNames: t => array<string>
