/*** Derive command line parsers from types, in the style of Rust's clap.

The `@clap.*` attributes generate `ClapArgs.t`, `ClapSubcommand.t`, `ClapValueParser.t`
and `ClapParser.t` values. This module runs them. */

module PossibleValue = ClapPossibleValue
module ValueParser = ClapValueParser
module Arg = ClapArg
module Command = ClapCommand
module Error = ClapError
module Matches = ClapMatches
module Args = ClapArgs
module Subcommand = ClapSubcommand
module Parser = ClapParser

/** Parses `argv` against a command definition without decoding. Mirrors `Command::try_get_matches_from`.

The first element of `argv` is the program name and is ignored, as in clap.
Environment variables are read from `env`, which defaults to `process.env`.

**Errors**: every `ClapError.t` case, including help and version requests. */
let getMatchesFrom: (
  ClapCommand.t,
  array<string>,
  ~env: Dict.t<string>=?,
) => result<ClapMatches.t, ClapError.t>

/** Parses and decodes `argv`. Mirrors `Parser::try_parse_from`; the first element is the program name.

**Errors**: every `ClapError.t` case, including help and version requests. */
let tryParseFrom: (
  ClapParser.t<'value>,
  array<string>,
  ~env: Dict.t<string>=?,
) => result<'value, ClapError.t>

/** Parses and decodes `process.argv`. Mirrors `Parser::try_parse`. **Errors**: as `tryParseFrom`. */
let tryParse: ClapParser.t<'value> => result<'value, ClapError.t>

/** Parses and decodes `process.argv`, or prints the error, help or version and exits. Mirrors `Parser::parse`. */
let parse: ClapParser.t<'value> => 'value
