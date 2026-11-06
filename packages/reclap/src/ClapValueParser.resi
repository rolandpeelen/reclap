/*** Typed conversion between raw argument strings and values.

Mirrors `clap::value_parser!`. The derive picks a value parser from the field type.
`format` must round-trip with `parse`: typed default values are stored as strings,
like `default_value_t` in clap, and parsed again when they are read. */

type t<'value> = {
  parse: string => result<'value, string>,
  format: 'value => string,
  possibleValues: array<ClapPossibleValue.t>,
}

/** Creates a value parser from a parse function and its inverse `format`.

**Errors**: `parse` returns `Error(reason)`, where `reason` completes the sentence
`invalid value 'x' for '--arg <ARG>': <reason>`. */
let make: (string => result<'value, string>, 'value => string) => t<'value>

/** Accepts any string. */
let string: t<string>

/** Accepts optionally signed base-10 integers in the 32-bit range, such as `-3` and `42`. Rejects `1.5` and `12abc`. */
let int: t<int>

/** Accepts decimal and exponent float literals, such as `1`, `-0.5` and `2e3`. Rejects trailing garbage. */
let float: t<float>

/** Accepts exactly `true` and `false`. */
let bool: t<bool>

/** Accepts the name or an alias of each listed possible value and returns the paired value.

The possible values are listed in help and in errors, like clap's `ValueEnum`.
Values are compared with `===` when formatted, which is exact for the constant
constructors that `@clap.valueEnum` accepts. A value that is not listed formats as `""`. */
let enum: array<('value, ClapPossibleValue.t)> => t<'value>

/** Parses one raw string. **Errors**: the reason from the parser. */
let parse: (t<'value>, string) => result<'value, string>

/** Formats one value as the string that `parse` accepts. */
let format: (t<'value>, 'value) => string
