/*** A typed set of subcommands derived from a variant. Mirrors `clap::Subcommand` + `clap::FromArgMatches`.

`@clap.subcommand` and `@clap.parser` on a variant generate a value of this type.
`fromMatches` receives the matches of the parent command and reads its subcommand. */

type t<'value> = {
  augment: ClapCommand.t => ClapCommand.t,
  fromMatches: ClapMatches.t => result<'value, ClapError.t>,
}

/** Creates the subcommand set from a function that adds the subcommands to a parent command and a decoder. */
let make: (ClapCommand.t => ClapCommand.t, ClapMatches.t => result<'value, ClapError.t>) => t<'value>

/** Adds the subcommands to a parent command without requiring one. */
let augment: (t<'value>, ClapCommand.t) => ClapCommand.t

/** Adds the subcommands and requires one, with help on an empty command line, as clap does for a non-`Option` subcommand field. */
let augmentRequired: (t<'value>, ClapCommand.t) => ClapCommand.t

/** Decodes the parent's subcommand. **Errors**: `MissingSubcommand` when none was given. */
let fromMatches: (t<'value>, ClapMatches.t) => result<'value, ClapError.t>

/** Decodes the parent's subcommand, or returns `None` when none was given. */
let fromMatchesOptional: (t<'value>, ClapMatches.t) => result<option<'value>, ClapError.t>
