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
  entries: Dict.t<entry>,
  subcommand: option<(string, t)>,
}

let findArg = (matches, id) => matches.command.args->Array.find(arg => arg.id == id)

let displayArg = (matches, id) => findArg(matches, id)->Option.mapOr(id, ClapArg.display)

let getFlag = (matches, id) =>
  switch (matches.entries->Dict.get(id), findArg(matches, id)) {
  | (Some({values, _}), _) => values->Array.last->Option.mapOr(false, value => value == "true")
  | (None, Some({action: SetFalse, _})) => true
  | (None, Some({action: Set | Append | SetTrue | Count | Help | Version, _})) | (None, None) =>
    false
  }

let getCount = (matches, id) =>
  switch matches.entries->Dict.get(id) {
  | Some({occurrences, source: CommandLine, _}) => occurrences
  | Some({values, source: EnvVariable | DefaultValue, _}) =>
    values->Array.last->Option.flatMap(value => Int.fromString(value))->Option.getOr(0)
  | None => 0
  }

let parseValue = (matches, id, valueParser, value) =>
  switch ClapValueParser.parse(valueParser, value) {
  | Ok(parsed) => Ok(parsed)
  | Error(reason) =>
    Error(
      ClapError.InvalidValue({
        context: matches.context,
        argument: displayArg(matches, id),
        value,
        reason,
        possibleValues: valueParser.possibleValues
        ->Array.filter(possibleValue => !possibleValue.hidden)
        ->Array.map(possibleValue => possibleValue.name),
        suggestion: None,
      }),
    )
  }

let parseValues = (matches, id, valueParser, values) =>
  values->Array.reduce(Ok([]), (parsed, value) =>
    switch parsed {
    | Error(error) => Error(error)
    | Ok(parsed) =>
      parseValue(matches, id, valueParser, value)->Result.map(value =>
        Array.concat(parsed, [value])
      )
    }
  )

let getOne = (matches, id, valueParser) =>
  switch matches.entries->Dict.get(id)->Option.flatMap(entry => entry.values->Array.last) {
  | None => Ok(None)
  | Some(value) => parseValue(matches, id, valueParser, value)->Result.map(value => Some(value))
  }

let getRequired = (matches, id, valueParser) =>
  switch getOne(matches, id, valueParser) {
  | Ok(Some(value)) => Ok(value)
  | Ok(None) =>
    Error(
      ClapError.MissingRequiredArguments({
        context: matches.context,
        arguments: [displayArg(matches, id)],
      }),
    )
  | Error(error) => Error(error)
  }

let getManyOptional = (matches, id, valueParser) =>
  switch matches.entries->Dict.get(id) {
  | None => Ok(None)
  | Some({values, _}) => parseValues(matches, id, valueParser, values)->Result.map(values => Some(values))
  }

let getMany = (matches, id, valueParser) =>
  getManyOptional(matches, id, valueParser)->Result.map(values => values->Option.getOr([]))

let contains = (matches, id) => matches.entries->Dict.get(id)->Option.isSome

let valueSource = (matches, id) => matches.entries->Dict.get(id)->Option.map(entry => entry.source)

let subcommand = matches => matches.subcommand

/** Lists every subcommand name and alias, hidden ones too, as clap's `MissingSubcommand` does. */
let allSubcommandNames = (command: ClapCommand.t) =>
  command.subcommands->Array.flatMap(subcommand =>
    Array.concatMany([subcommand.name], [subcommand.aliases, subcommand.visibleAliases])
  )

let missingSubcommand = matches => Error(
  ClapError.MissingSubcommand({
    context: matches.context,
    name: matches.context.path->Array.join(" "),
    subcommands: allSubcommandNames(ClapCommand.build(matches.command)),
  }),
)
