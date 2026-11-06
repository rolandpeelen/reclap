type context = {
  path: array<string>,
  usage: string,
}

type t =
  | DisplayHelp({output: string})
  | DisplayVersion({output: string})
  | DisplayHelpOnMissingArgumentOrSubcommand({output: string})
  | UnknownArgument({
      context: context,
      argument: string,
      suggestion: option<string>,
      tips: array<string>,
    })
  | InvalidSubcommand({
      context: context,
      name: string,
      suggestion: option<string>,
      tips: array<string>,
    })
  | InvalidValue({
      context: context,
      argument: string,
      value: string,
      reason: string,
      possibleValues: array<string>,
      suggestion: option<string>,
    })
  | MissingValue({context: context, argument: string, possibleValues: array<string>})
  | UnexpectedValue({context: context, argument: string, value: string})
  | MissingRequiredArguments({context: context, arguments: array<string>})
  | MissingSubcommand({context: context, name: string, subcommands: array<string>})
  | UsedMultipleTimes({context: context, argument: string})

// clap separates the message, the tips, the usage and the footer with blank lines and
// indents tips and value lists by two spaces.
let indent = "  "

let renderValuesList = (listName, values) =>
  switch values {
  | [] => ""
  | values => `\n${indent}[${listName}: ${values->Array.join(", ")}]`
  }

let renderTips = (~suggestionKind, ~suggestion, ~tips) => {
  let suggestionTips = switch suggestion {
  | None => []
  | Some(suggestion) => [`a similar ${suggestionKind} exists: '${suggestion}'`]
  }
  switch Array.concat(suggestionTips, tips) {
  | [] => ""
  | allTips => "\n" ++ allTips->Array.map(tip => `\n${indent}tip: ${tip}`)->Array.join("")
  }
}

let renderUsage = (context: context) => `\n\nUsage: ${context.usage}`

let footer = "\n\nFor more information, try '--help'.\n"

let renderMissingValue = (argument, possibleValues) =>
  `a value is required for '${argument}' but none was supplied` ++
  renderValuesList("possible values", possibleValues)

let renderInvalidValue = (~argument, ~value, ~reason, ~possibleValues, ~suggestion) =>
  switch possibleValues {
  | [] => `invalid value '${value}' for '${argument}': ${reason}`
  | possibleValues if value == "" => renderMissingValue(argument, possibleValues)
  | possibleValues =>
    `invalid value '${value}' for '${argument}'` ++
    renderValuesList("possible values", possibleValues) ++
    renderTips(~suggestionKind="value", ~suggestion, ~tips=[])
  }

let render = error =>
  switch error {
  | DisplayHelp({output})
  | DisplayVersion({output})
  | DisplayHelpOnMissingArgumentOrSubcommand({output}) => output
  | UnknownArgument({context, argument, suggestion, tips}) =>
    `error: unexpected argument '${argument}' found` ++
    renderTips(~suggestionKind="argument", ~suggestion, ~tips) ++
    renderUsage(context) ++
    footer
  | InvalidSubcommand({context, name, suggestion, tips}) =>
    `error: unrecognized subcommand '${name}'` ++
    renderTips(~suggestionKind="subcommand", ~suggestion, ~tips) ++
    renderUsage(context) ++
    footer
  | InvalidValue({argument, value, reason, possibleValues, suggestion, context: _}) =>
    "error: " ++
    renderInvalidValue(~argument, ~value, ~reason, ~possibleValues, ~suggestion) ++
    footer
  | MissingValue({argument, possibleValues, context: _}) =>
    "error: " ++ renderMissingValue(argument, possibleValues) ++ footer
  | UnexpectedValue({context, argument, value}) =>
    `error: unexpected value '${value}' for '${argument}' found; no more were expected` ++
    renderUsage(context) ++
    footer
  | MissingRequiredArguments({context, arguments}) =>
    "error: the following required arguments were not provided:" ++
    arguments->Array.map(argument => `\n${indent}${argument}`)->Array.join("") ++
    renderUsage(context) ++
    footer
  | MissingSubcommand({context, name, subcommands}) =>
    `error: '${name}' requires a subcommand but one was not provided` ++
    renderValuesList("subcommands", subcommands) ++
    renderUsage(context) ++
    footer
  | UsedMultipleTimes({context, argument}) =>
    `error: the argument '${argument}' cannot be used multiple times` ++
    renderUsage(context) ++
    footer
  }

let exitCode = error =>
  switch error {
  | DisplayHelp(_) | DisplayVersion(_) => 0
  | DisplayHelpOnMissingArgumentOrSubcommand(_)
  | UnknownArgument(_)
  | InvalidSubcommand(_)
  | InvalidValue(_)
  | MissingValue(_)
  | UnexpectedValue(_)
  | MissingRequiredArguments(_)
  | MissingSubcommand(_)
  | UsedMultipleTimes(_) => 2
  }

let usesStderr = error => exitCode(error) != 0

let exit = error => {
  let stream = usesStderr(error) ? NodeProcess.stderr : NodeProcess.stdout
  let _written = stream->NodeProcess.write(render(error))
  NodeProcess.exit(exitCode(error))
}
