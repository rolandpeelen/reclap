type t<'value> = {
  parse: string => result<'value, string>,
  format: 'value => string,
  possibleValues: array<ClapPossibleValue.t>,
}

let make = (parse, format) => {parse, format, possibleValues: []}

let string = make(input => Ok(input), value => value)

// The messages are the `Display` texts of Rust's `ParseIntError` and of clap's range
// check, which clap appends to `invalid value 'x' for '--arg <ARG>': `.
let integerPattern = /^[+-]?[0-9]+$/
let minimumInt = -2147483648.
let maximumInt = 2147483647.

let parseInt = input =>
  switch input {
  | "" => Error("cannot parse integer from empty string")
  | input if !RegExp.test(integerPattern, input) => Error("invalid digit found in string")
  | input =>
    switch Float.fromString(input) {
    | Some(number) if number >= minimumInt && number <= maximumInt => Ok(Float.toInt(number))
    | Some(_) | None => Error(`${input} is not in -2147483648..=2147483647`)
    }
  }

let int = make(parseInt, value => Int.toString(value))

// Rust's `f64::from_str` grammar: decimal or exponent literals, `inf`, `infinity` and
// `nan`, with an optional sign and no surrounding whitespace.
let floatPattern = /^[+-]?([0-9]+\.?[0-9]*([eE][+-]?[0-9]+)?|\.[0-9]+([eE][+-]?[0-9]+)?|inf|infinity|nan)$/i

let parseFloat = input =>
  switch input {
  | "" => Error("cannot parse float from empty string")
  | input if !RegExp.test(floatPattern, input) => Error("invalid float literal")
  | input => Ok(Float.parseFloat(input))
  }

let float = make(parseFloat, value => Float.toString(value))

let enum = pairs => {
  parse: input =>
    switch pairs->Array.find(((_, possibleValue)) =>
      ClapPossibleValue.matches(possibleValue, input)
    ) {
    | Some((value, _)) => Ok(value)
    | None => Error("invalid value")
    },
  format: value =>
    switch pairs->Array.find(((candidate, _)) => candidate === value) {
    | Some((_, possibleValue)) => possibleValue.name
    | None => ""
    },
  possibleValues: pairs->Array.map(((_, possibleValue)) => possibleValue),
}

let bool = enum([(true, ClapPossibleValue.make("true")), (false, ClapPossibleValue.make("false"))])

let parse = (valueParser, input) => valueParser.parse(input)

let format = (valueParser, value) => valueParser.format(value)
