/*** One value that an argument accepts, shown in help and checked during parsing.

Mirrors `clap::builder::PossibleValue`. */

type t = {
  name: string,
  help: option<string>,
  aliases: array<string>,
  hidden: bool,
}

/** Creates a visible possible value with the given name, no help and no aliases. */
let make: string => t

/** Sets the help text shown next to the value in long help. */
let help: (t, string) => t

/** Adds an alternative spelling that parses to the same value. It is not shown in help. */
let alias: (t, string) => t

/** Hides the value from help and from the `[possible values: ...]` list. It still parses. */
let hide: t => t

/** Returns whether `input` equals the name or one of the aliases. The comparison is case sensitive. */
let matches: (t, string) => bool
