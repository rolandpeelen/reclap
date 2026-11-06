/*** The raw result of parsing one command level. Mirrors `clap::ArgMatches`.

Values are kept as strings and converted with a value parser when read. The parser
already validated them, so the typed getters fail only for programming errors such as
a default value whose `format` does not round-trip. */

type valueSource =
  | CommandLine
  | EnvVariable
  | DefaultValue

type entry = {
  values: array<string>,
  occurrences: int,
  source: valueSource,
}

type rec t = {
  command: ClapCommand.t,
  context: ClapError.context,
  /** Read-only. Keyed by argument id; absent arguments have no entry. */
  entries: Dict.t<entry>,
  subcommand: option<(string, t)>,
}

/** Reads a `SetTrue` or `SetFalse` flag. An absent `SetTrue` flag is `false`; an absent `SetFalse` flag is `true`. */
let getFlag: (t, string) => bool

/** Reads the number of occurrences of a `Count` argument. */
let getCount: (t, string) => int

/** Reads the single value of an optional argument. **Errors**: `InvalidValue` when the value does not parse. */
let getOne: (t, string, ClapValueParser.t<'value>) => result<option<'value>, ClapError.t>

/** Reads the single value of a required argument.

**Errors**: `MissingRequiredArguments` when absent, `InvalidValue` when the value does not parse. */
let getRequired: (t, string, ClapValueParser.t<'value>) => result<'value, ClapError.t>

/** Reads every value of an `Append` argument, `[]` when absent. **Errors**: `InvalidValue`. */
let getMany: (t, string, ClapValueParser.t<'value>) => result<array<'value>, ClapError.t>

/** Reads every value of an `Append` argument, `None` when absent. **Errors**: `InvalidValue`. */
let getManyOptional: (
  t,
  string,
  ClapValueParser.t<'value>,
) => result<option<array<'value>>, ClapError.t>

/** Returns the unparsed values of the argument as stored, or `None` when it has no entry.

Mirrors `ArgMatches::get_raw`. Flags store `"true"`/`"false"` and counters the count; absent
flags and counters have a `DefaultValue` entry of `"false"` (`"true"` for `SetFalse`) or `"0"`,
and values read from the environment are stored as given. */
let getRaw: (t, string) => option<array<string>>

/** Returns the ids of every argument with an entry, defaulted ones included, sorted. Mirrors
`ArgMatches::ids`, which lists them in insertion order instead. */
let ids: t => array<string>

/** Returns whether the argument has a value from any source. As in clap, this holds for every
flag and counter, which default to `false` and `0`. */
let contains: (t, string) => bool

/** Returns where the argument's value came from. */
let valueSource: (t, string) => option<valueSource>

/** Returns the name and matches of the subcommand that was given, if any. */
let subcommand: t => option<(string, t)>

/** Returns the `MissingSubcommand` error for this command level. */
let missingSubcommand: t => result<'value, ClapError.t>
