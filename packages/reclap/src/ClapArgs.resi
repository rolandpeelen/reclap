/*** A typed set of arguments derived from a record. Mirrors `clap::Args` + `clap::FromArgMatches`.

`@clap.args` and `@clap.parser` on a record generate a value of this type. */

type t<'value> = {
  augment: ClapCommand.t => ClapCommand.t,
  fromMatches: ClapMatches.t => result<'value, ClapError.t>,
}

/** Creates the argument set from a function that adds the arguments to a command and a decoder. */
let make: (ClapCommand.t => ClapCommand.t, ClapMatches.t => result<'value, ClapError.t>) => t<'value>

/** Adds the arguments to a command. Mirrors `Args::augment_args`. */
let augment: (t<'value>, ClapCommand.t) => ClapCommand.t

/** Builds the typed value from the matches of the command that `augment` extended. */
let fromMatches: (t<'value>, ClapMatches.t) => result<'value, ClapError.t>
