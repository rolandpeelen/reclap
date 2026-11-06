/*** A complete, typed command line parser. Mirrors `clap::Parser` + `clap::CommandFactory`.

`@clap.parser` generates a value of this type. Run it with `Clap.parse`. */

type t<'value> = {
  command: ClapCommand.t,
  fromMatches: ClapMatches.t => result<'value, ClapError.t>,
}

/** Creates a parser for a command whose arguments come from a record. */
let fromArgs: (ClapCommand.t, ClapArgs.t<'value>) => t<'value>

/** Creates a parser for a command whose subcommands come from a variant. A subcommand is required. */
let fromSubcommand: (ClapCommand.t, ClapSubcommand.t<'value>) => t<'value>

/** Returns the command definition, for help rendering or for extending with the builder API. */
let command: t<'value> => ClapCommand.t
