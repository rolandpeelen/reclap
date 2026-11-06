/*** Renders help, usage and version text exactly as clap 4 does with colour and wrapping off.

The rules are specified in `docs/clap-output-format.md`; section numbers below refer to it.
Every function expects a command that `ClapCommandDefinition.build` has completed, so that
`-h, --help` and the `help` subcommand are present. `binName` is the name that starts the
usage line: the program name, or the parent's usage name and the subcommand's name. */

type mode =
  | Short
  | Long

// Long help puts each item's text on its own line, indented by 10 spaces (3.6).
let longIndent = String.repeat(" ", 10)
let longNewline = "\n" ++ longIndent

let isVisible = (arg: ClapArg.t) => !arg.hidden

let visiblePossibleValues = (arg: ClapArg.t) =>
  arg.possibleValues->Array.filter(possibleValue => !possibleValue.hidden)

let possibleValueHasHelp = (possibleValue: ClapPossibleValue.t) => Option.isSome(possibleValue.help)

/** Returns whether `--help` differs from `-h`: the command has a long about, or a visible
argument has long help or a possible value with help (3.1). */
let hasLongHelp = (command: ClapCommandDefinition.t) =>
  Option.isSome(command.longAbout) ||
  command.args->Array.some(arg =>
    isVisible(arg) &&
    (Option.isSome(arg.longHelp) || visiblePossibleValues(arg)->Array.some(possibleValueHasHelp))
  )

let isAutomatic = (arg: ClapArg.t) =>
  switch arg.action {
  | Help | Version => true
  | Set | Append | SetTrue | SetFalse | Count => false
  }

/** Renders a named argument as in usage lines and messages, without its short name when it
has a long one: `--name <NAME>`, `--shout`, `-v...` (4.2). */
let renderUsageSpec = (arg: ClapArg.t) =>
  switch arg.action {
  | Set | Append => `${ClapArg.displayName(arg)} <${ClapArg.placeholder(arg)}>`
  | Count => ClapArg.displayName(arg) ++ "..."
  | SetTrue | SetFalse | Help | Version => ClapArg.displayName(arg)
  }

let visibleSubcommands = (command: ClapCommandDefinition.t) =>
  command.subcommands->Array.filter(subcommand => !subcommand.hidden)

let needsOptionsTag = (command: ClapCommandDefinition.t) =>
  ClapCommandDefinition.named(command)->Array.some(arg =>
    isVisible(arg) && !arg.required && !isAutomatic(arg)
  )

let joinWords = words => words->Array.filter(word => word != "")->Array.join(" ")

/** Renders the usage line that help and most errors show, without `Usage: ` (4.1). */
let renderUsage = (command: ClapCommandDefinition.t, ~binName) => {
  let requiredNamed =
    ClapCommandDefinition.named(command)
    ->Array.filter(arg => arg.required && isVisible(arg))
    ->Array.map(renderUsageSpec)
  let positionals =
    ClapCommandDefinition.positionals(command)
    ->Array.filter(isVisible)
    ->Array.map(arg => ClapArg.displayPositional(arg, ~required=arg.required))
  let subcommandPlaceholder = switch visibleSubcommands(command) {
  | [] => ""
  | _ if command.subcommandRequired => "<COMMAND>"
  | _ => "[COMMAND]"
  }
  joinWords(
    Array.concatMany(
      [binName, needsOptionsTag(command) ? "[OPTIONS]" : ""],
      [requiredNamed, positionals, [subcommandPlaceholder]],
    ),
  )
}

/** Renders the usage line built from the required arguments and the arguments with ids in
`used`, in that order, as clap does for some errors (4.2). */
let renderSmartUsage = (command: ClapCommandDefinition.t, ~binName, ~used: array<string>) => {
  let isUsed = (arg: ClapArg.t) => used->Array.includes(arg.id)
  let named = ClapCommandDefinition.named(command)
  let requiredNamed = named->Array.filter(arg => arg.required)
  let usedNamed =
    used->Array.filterMap(id =>
      named->Array.find(arg => arg.id == id && !arg.required && isVisible(arg))
    )
  let positionals =
    ClapCommandDefinition.positionals(command)
    ->Array.filter(isVisible)
    ->Array.map(arg => ClapArg.displayPositional(arg, ~required=arg.required || isUsed(arg)))
  joinWords(
    Array.concatMany(
      [binName],
      [
        Array.concat(requiredNamed, usedNamed)->Array.map(renderUsageSpec),
        positionals,
        [command.subcommandRequired ? "<COMMAND>" : ""],
      ],
    ),
  )
}

let renderItemSpec = (arg: ClapArg.t) =>
  switch (ClapArg.isPositional(arg), arg.short, arg.long) {
  | (true, _, _) => ClapArg.displayPositional(arg, ~required=arg.required)
  | (false, short, long) =>
    let names = switch (short, long) {
    | (Some(short), Some(long)) => `-${short}, --${long}`
    | (None, Some(long)) => `    --${long}`
    | (Some(short), None) => "-" ++ short
    | (None, None) => ""
    }
    switch arg.action {
    | Set | Append => `${names} <${ClapArg.placeholder(arg)}>`
    | Count => names ++ "..."
    | SetTrue | SetFalse | Help | Version => names
    }
  }

let automaticHelpText = (command, arg: ClapArg.t, mode) =>
  switch (arg.action, mode, hasLongHelp(command)) {
  | (Help, Short, true) => Some("Print help (see more with '--help')")
  | (Help, Long, true) => Some("Print help (see a summary with '-h')")
  | (Help, Short | Long, false) => Some("Print help")
  | (Version, Short | Long, _) => Some("Print version")
  | (Set | Append | SetTrue | SetFalse | Count, Short | Long, _) => None
  }

let helpText = (command, arg: ClapArg.t, mode) =>
  switch (arg.help, arg.longHelp, mode) {
  | (Some(help), _, Short) | (_, Some(help), Long) | (None, Some(help), Short) => Some(help)
  | (Some(help), None, Long) => Some(help)
  | (None, None, Short | Long) => automaticHelpText(command, arg, mode)
  }

let renderAliases = (~singular, ~plural, aliases) =>
  switch aliases {
  | [] => None
  | [alias] => Some(`[${singular}: ${alias}]`)
  | aliases => Some(`[${plural}: ${aliases->Array.join(", ")}]`)
  }

/** Returns the bracketed facts after an argument's help, in clap's order (3.5). */
let specValues = (arg: ClapArg.t, ~env, ~includePossibleValues) => {
  let envValue =
    arg.env->Option.map(name => `[env: ${name}=${env->Dict.get(name)->Option.getOr("")}]`)
  let defaultValue = switch arg.defaultValues {
  | [] => None
  | _ if !ClapArg.takesValue(arg) => None
  | defaults => Some(`[default: ${defaults->Array.join(" ")}]`)
  }
  let aliases = renderAliases(
    ~singular="alias",
    ~plural="aliases",
    arg.visibleAliases->Array.map(alias => "--" ++ alias),
  )
  let possibleValues = switch visiblePossibleValues(arg) {
  | [] => None
  | _ if !includePossibleValues => None
  | values => Some(`[possible values: ${values->Array.map(value => value.name)->Array.join(", ")}]`)
  }
  [envValue, defaultValue, aliases, possibleValues]->Array.keepSome
}

let width = String.length

let renderShortItems = (items: array<(string, string)>) => {
  let longest = items->Array.reduce(2, (longest, (spec, _)) => Math.Int.max(longest, width(spec)))
  let continuation = "\n" ++ String.repeat(" ", longest + 4)
  items
  ->Array.map(((spec, text)) =>
    "  " ++
    spec ++
    String.repeat(" ", longest - width(spec) + 2) ++
    text->String.replaceAll("\n", continuation)
  )
  ->Array.join("\n")
}

let renderShortArgText = (command, arg, ~env) =>
  joinWords(
    Array.concat(
      helpText(command, arg, Short)->Option.mapOr([], text => [text]),
      specValues(arg, ~env, ~includePossibleValues=true),
    ),
  )

let renderPossibleValuesBlock = (values: array<ClapPossibleValue.t>) => {
  let longest =
    values->Array.reduce(0, (longest, value) => Math.Int.max(longest, width(value.name)))
  let lines = values->Array.map(value =>
    switch value.help {
    | None => `${longNewline}- ${value.name}`
    | Some(help) =>
      `${longNewline}- ${value.name}: ${String.repeat(" ", longest - width(value.name))}${help}`
    }
  )
  "Possible values:" ++ lines->Array.join("")
}

let renderLongArgText = (command, arg, ~env) => {
  let text =
    helpText(command, arg, Long)->Option.mapOr("", text =>
      text->String.replaceAll("\n", longNewline)
    )
  let values = visiblePossibleValues(arg)
  let hasBlock = values->Array.some(possibleValueHasHelp)
  let textWithBlock = switch (text, hasBlock) {
  | (text, false) => text
  | ("", true) => renderPossibleValuesBlock(values)
  | (text, true) => text ++ "\n" ++ longNewline ++ renderPossibleValuesBlock(values)
  }
  switch (textWithBlock, specValues(arg, ~env, ~includePossibleValues=!hasBlock)) {
  | (text, []) => text
  | ("", specs) => specs->Array.join(longNewline)
  | (text, specs) => text ++ longNewline ++ longNewline ++ specs->Array.join(longNewline)
  }
}

let renderArgItems = (command, args, ~mode, ~env) =>
  switch (mode, hasLongHelp(command)) {
  | (Long, true) =>
    args
    ->Array.map(arg =>
      `  ${renderItemSpec(arg)}${longNewline}${renderLongArgText(command, arg, ~env)}`
    )
    ->Array.join("\n\n")
  | (Short, _) | (Long, false) =>
    renderShortItems(
      args->Array.map(arg => (renderItemSpec(arg), renderShortArgText(command, arg, ~env))),
    )
  }

let renderSubcommandItems = subcommands =>
  renderShortItems(
    subcommands->Array.map((subcommand: ClapCommandDefinition.t) => {
      let about = switch (subcommand.about, subcommand.longAbout) {
      | (Some(about), _) | (None, Some(about)) => [about]
      | (None, None) => []
      }
      let aliases =
        renderAliases(
          ~singular="alias",
          ~plural="aliases",
          subcommand.visibleAliases,
        )->Option.mapOr([], aliases => [aliases])
      (subcommand.name, joinWords(Array.concat(about, aliases)))
    }),
  )

let renderSection = (heading, items) =>
  switch items {
  | "" => None
  | items => Some(`${heading}:\n${items}`)
  }

/** Renders `-h` (`mode` is `Short`) or `--help` (`mode` is `Long`) output, ending in exactly
one newline. `env` supplies the values shown in `[env: NAME=VALUE]`. */
let render = (command: ClapCommandDefinition.t, ~binName, ~mode, ~env) => {
  let about = switch mode {
  | Short => command.about
  | Long => command.longAbout->Option.orElse(command.about)
  }
  let visibleArgs = command.args->Array.filter(isVisible)
  let subcommands = visibleSubcommands(command)
  let positionals = visibleArgs->Array.filter(ClapArg.isPositional)
  let named = visibleArgs->Array.filter(arg => !ClapArg.isPositional(arg))
  let sections =
    [
      subcommands->Array.length > 0
        ? renderSection("Commands", renderSubcommandItems(subcommands))
        : None,
      positionals->Array.length > 0
        ? renderSection("Arguments", renderArgItems(command, positionals, ~mode, ~env))
        : None,
      named->Array.length > 0
        ? renderSection("Options", renderArgItems(command, named, ~mode, ~env))
        : None,
    ]->Array.keepSome
  let parts = Array.concatMany(
    about->Option.mapOr([], about => [about]),
    [[`Usage: ${renderUsage(command, ~binName)}`], sections],
  )
  parts->Array.join("\n\n")->String.trimEnd ++ "\n"
}

/** Renders the version line, `name version` and a newline (2). */
let renderVersion = (command: ClapCommandDefinition.t) =>
  switch command.version {
  | Some(version) => `${command.name} ${version}\n`
  | None => command.name ++ "\n"
  }
