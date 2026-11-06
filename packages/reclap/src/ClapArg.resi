/*** The definition of one command line argument.

Mirrors `clap::Arg`. Every function returns a new definition; nothing is mutated.
An argument without `short` and `long` is positional. */

/** What happens when the argument occurs. Mirrors `clap::ArgAction`. */
type action =
  /** Stores one value. A second occurrence is an error. */
  | Set
  /** Appends every value of every occurrence. */
  | Append
  /** A flag that reads as `true` when present. */
  | SetTrue
  /** A flag that reads as `false` when present. */
  | SetFalse
  /** Counts the occurrences, as in `-vvv`. */
  | Count
  /** Prints help and stops. */
  | Help
  /** Prints the version and stops. */
  | Version

type t = {
  id: string,
  short: option<string>,
  long: option<string>,
  aliases: array<string>,
  visibleAliases: array<string>,
  help: option<string>,
  longHelp: option<string>,
  valueName: option<string>,
  required: bool,
  action: action,
  defaultValues: array<string>,
  env: option<string>,
  possibleValues: array<ClapPossibleValue.t>,
  validate: string => result<unit, string>,
  hidden: bool,
}

/** Creates a positional, optional `Set` argument with the given id that accepts any string. */
let make: string => t

/** Sets the one-character short name, without the dash. */
let short: (t, string) => t

/** Sets the long name, without the dashes. */
let long: (t, string) => t

/** Adds a hidden alternative long name. */
let alias: (t, string) => t

/** Adds an alternative long name that help shows as `[aliases: --x]`. */
let visibleAlias: (t, string) => t

/** Sets the help shown by `-h`. */
let help: (t, string) => t

/** Sets the help shown by `--help`. */
let longHelp: (t, string) => t

/** Sets the placeholder shown in usage and help, such as `FILE` in `--input <FILE>`. */
let valueName: (t, string) => t

/** Sets whether parsing fails when the argument has no value from the command line, the environment or a default. */
let required: (t, bool) => t

/** Sets the action. */
let action: (t, action) => t

/** Reads the value from this environment variable when the argument is absent from the command line. */
let env: (t, string) => t

/** Hides the argument from help and usage. */
let hide: t => t

/** Validates values with the value parser and lists its possible values in help and errors. */
let valueParser: (t, ClapValueParser.t<'value>) => t

/** Sets one default value, stored as `ClapValueParser.format(parser, value)`. Mirrors `default_value_t`. */
let defaultValue: (t, ClapValueParser.t<'value>, 'value) => t

/** Sets several default values for an `Append` argument. Mirrors `default_values_t`. */
let defaultValues: (t, ClapValueParser.t<'value>, array<'value>) => t

/** Returns whether the argument has neither a short nor a long name. */
let isPositional: t => bool

/** Returns whether the action consumes values, which holds for `Set` and `Append`. */
let takesValue: t => bool

/** Renders the argument as clap does in errors: `--name <NAME>`, `-n <NAME>`, `<NAME>`,
`--verbose` or `-v...` for a counter. */
let display: t => string

/** Returns the value placeholder without brackets: the value name, or the id as clap does. */
let placeholder: t => string

/** Renders a positional argument as `<NAME>` when `required` holds and `[NAME]` otherwise,
followed by `...` for `Append`, as clap does in usage lines. */
let displayPositional: (t, ~required: bool) => string

/** Renders the name of a named argument, preferring the long name: `--name` or `-n`. */
let displayName: t => string
