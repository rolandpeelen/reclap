type action =
  | Set
  | Append
  | SetTrue
  | SetFalse
  | Count
  | Help
  | Version

type t = {
  id: string,
  short: option<string>,
  long: option<string>,
  aliases: array<string>,
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

let make = id => {
  id,
  short: None,
  long: None,
  aliases: [],
  help: None,
  longHelp: None,
  valueName: None,
  required: false,
  action: Set,
  defaultValues: [],
  env: None,
  possibleValues: [],
  validate: _ => Ok(),
  hidden: false,
}

let short = (arg, short) => {...arg, short: Some(short)}

let long = (arg, long) => {...arg, long: Some(long)}

let alias = (arg, alias) => {...arg, aliases: Array.concat(arg.aliases, [alias])}

let help = (arg, help) => {...arg, help: Some(help)}

let longHelp = (arg, longHelp) => {...arg, longHelp: Some(longHelp)}

let valueName = (arg, valueName) => {...arg, valueName: Some(valueName)}

let required = (arg, required) => {...arg, required}

let action = (arg, action) => {...arg, action}

let env = (arg, env) => {...arg, env: Some(env)}

let hide = arg => {...arg, hidden: true}

let valueParser = (arg, valueParser: ClapValueParser.t<'value>) => {
  ...arg,
  possibleValues: valueParser.possibleValues,
  validate: input => ClapValueParser.parse(valueParser, input)->Result.map(_ => ()),
}

let defaultValue = (arg, valueParser, value) => {
  ...arg,
  defaultValues: [ClapValueParser.format(valueParser, value)],
}

let defaultValues = (arg, valueParser, values) => {
  ...arg,
  defaultValues: values->Array.map(value => ClapValueParser.format(valueParser, value)),
}

let isPositional = arg =>
  switch (arg.short, arg.long) {
  | (None, None) => true
  | (Some(_), _) | (_, Some(_)) => false
  }

let takesValue = arg =>
  switch arg.action {
  | Set | Append => true
  | SetTrue | SetFalse | Count | Help | Version => false
  }

let placeholder = arg => arg.valueName->Option.getOr(arg.id)

let displayPositional = (arg, ~required) => {
  let bracketed = required ? `<${placeholder(arg)}>` : `[${placeholder(arg)}]`
  switch arg.action {
  | Append => bracketed ++ "..."
  | Set | SetTrue | SetFalse | Count | Help | Version => bracketed
  }
}

let displayName = arg =>
  switch (arg.long, arg.short) {
  | (Some(long), _) => "--" ++ long
  | (None, Some(short)) => "-" ++ short
  | (None, None) => placeholder(arg)
  }

let display = arg =>
  switch isPositional(arg) {
  | true => displayPositional(arg, ~required=arg.required)
  | false if takesValue(arg) => `${displayName(arg)} <${placeholder(arg)}>`
  | false => displayName(arg)
  }
