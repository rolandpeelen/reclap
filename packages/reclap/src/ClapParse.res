/*** The command line parser behind `Clap.getMatchesFrom`. Mirrors clap 4's `Parser` and
`Validator` for the features reclap supports; `docs/clap-output-format.md` section 7 lists the
behaviour it reproduces. */

/** One command level being parsed. `command` is already built. */
type level = {
  command: ClapCommand.t,
  path: array<string>,
  binName: string,
  env: Dict.t<string>,
}

/** What the parser has seen so far at one level. `used` lists the ids of the arguments given
on the command line, in the order they were first seen. `isCollectingPositional` is set while
the last token was a value of an `Append` positional, clap's `ParseState::Pos`: a subcommand
name is then another value. */
type state = {
  entries: Dict.t<ClapMatches.entry>,
  used: array<string>,
  positionalIndex: int,
  isTrailing: bool,
  isCollectingPositional: bool,
}

let initialState = {
  entries: Dict.make(),
  used: [],
  positionalIndex: 0,
  isTrailing: false,
  isCollectingPositional: false,
}

let makeLevel = (command, ~path, ~binName, ~env) => {
  command: ClapCommand.build(command),
  path,
  binName,
  env,
}

let helpContext = (level): ClapError.context => {
  path: level.path,
  usage: ClapHelp.renderUsage(level.command, ~binName=level.binName),
}

// clap renders the help usage when nothing was used and the smart usage otherwise.
let usageContext = (level, ~used): ClapError.context =>
  switch used {
  | [] => helpContext(level)
  | used => {
      path: level.path,
      usage: ClapHelp.renderSmartUsage(level.command, ~binName=level.binName, ~used),
    }
  }

let renderHelp = (level, mode) =>
  ClapHelp.render(level.command, ~binName=level.binName, ~mode, ~env=level.env)

let hasPositionals = level => ClapCommandDefinition.positionals(level.command)->Array.length > 0

let addUnique = (items, item) => items->Array.includes(item) ? items : Array.concat(items, [item])

let findArg = (level, id) => level.command.args->Array.find((arg: ClapArg.t) => arg.id == id)

/** Keeps the ids of arguments that are not hidden; clap leaves hidden arguments out of the
usage it builds from the arguments used so far. */
let visibleIds = (level, ids) =>
  ids->Array.filter(id => findArg(level, id)->Option.mapOr(false, arg => !arg.hidden))

let withEntry = (entries, id, entry: ClapMatches.entry) => {
  let copy = entries->Dict.copy
  copy->Dict.set(id, entry)
  copy
}

let visiblePossibleValueNames = (arg: ClapArg.t) =>
  arg.possibleValues
  ->Array.filter(possibleValue => !possibleValue.hidden)
  ->Array.map(possibleValue => possibleValue.name)

let validateValue = (level, arg: ClapArg.t, value) => {
  let invalid = (~reason, ~possibleValues, ~suggestion) => Error(
    ClapError.InvalidValue({
      context: helpContext(level),
      argument: ClapArg.display(arg),
      value,
      reason,
      possibleValues,
      suggestion,
    }),
  )
  switch arg.possibleValues {
  | [] =>
    switch arg.validate(value) {
    | Ok() => Ok()
    | Error(reason) => invalid(~reason, ~possibleValues=[], ~suggestion=None)
    }
  | possibleValues if possibleValues->Array.some(ClapPossibleValue.matches(_, value)) => Ok()
  | _ =>
    let names = visiblePossibleValueNames(arg)
    invalid(~reason="", ~possibleValues=names, ~suggestion=ClapSuggest.best(value, names))
  }
}

/** Records one command line occurrence of `arg`, with its value for `Set` and `Append`.

**Errors**: `UsedMultipleTimes` for a second `Set`, `SetTrue` or `SetFalse` occurrence. */
let recordOccurrence = (level, state, arg: ClapArg.t, value) => {
  let existing = state.entries->Dict.get(arg.id)
  let record = (values, occurrences) => Ok({
    ...state,
    used: addUnique(state.used, arg.id),
    entries: state.entries->withEntry(arg.id, {values, occurrences, source: CommandLine}),
  })
  let usedTwice = () => Error(
    ClapError.UsedMultipleTimes({context: helpContext(level), argument: ClapArg.display(arg)}),
  )
  switch (arg.action, existing) {
  | (Set | SetTrue | SetFalse | Help | Version, Some(_)) => usedTwice()
  | (Set | Help | Version, None) => record([value], 1)
  | (SetTrue, None) => record(["true"], 1)
  | (SetFalse, None) => record(["false"], 1)
  | (Append, None) => record([value], 1)
  | (Append, Some({values, occurrences, _})) =>
    record(Array.concat(values, [value]), occurrences + 1)
  | (Count, None) => record(["1"], 1)
  | (Count, Some({occurrences, _})) => record([Int.toString(occurrences + 1)], occurrences + 1)
  }
}

let recordValue = (level, state, arg, value) =>
  switch validateValue(level, arg, value) {
  | Ok() => recordOccurrence(level, state, arg, value)
  | Error(error) => Error(error)
  }

/** Splits `--name=value` into the name and the optional value. */
let splitLong = token => {
  let body = token->String.slice(~start=2)
  switch body->String.indexOfOpt("=") {
  | None => (body, None)
  | Some(index) => (
      body->String.slice(~start=0, ~end=index),
      Some(body->String.slice(~start=index + 1)),
    )
  }
}

let isOptionLike = token => token->String.startsWith("-") && token != "-"

/** Returns whether `token` starts with a known option, which makes a pending option's value
missing. An unknown option is reported as unknown instead, as clap does. */
let isKnownOptionToken = (level, token) =>
  switch token {
  | "--" => true
  | token if token->String.startsWith("--") =>
    let (name, _) = splitLong(token)
    ClapCommandDefinition.findLong(level.command, name)->Option.isSome
  | token =>
    ClapText.codePoints(token)
    ->Array.get(1)
    ->Option.flatMap(short => ClapCommandDefinition.findShort(level.command, short))
    ->Option.isSome
  }

let missingValue = (level, arg) => Error(
  ClapError.MissingValue({
    context: helpContext(level),
    argument: ClapArg.display(arg),
    possibleValues: visiblePossibleValueNames(arg),
  }),
)

/** Takes the value of an option that has none attached from the next token. Returns the new
state and the index of the next unread token. */
let takeSeparateValue = (level, state, arg, tokens, nextIndex) =>
  switch tokens->Array.get(nextIndex) {
  | Some(token) if !isOptionLike(token) =>
    recordValue(level, state, arg, token)->Result.map(state => (state, nextIndex + 1))
  | Some(token) if !isKnownOptionToken(level, token) => Ok((state, nextIndex))
  | Some(_) | None => missingValue(level, arg)
  }

let longCandidates = (command: ClapCommand.t) =>
  command.args->Array.flatMap(arg =>
    Array.concatMany(arg.long->Option.mapOr([], long => [long]), [arg.aliases, arg.visibleAliases])
  )

/** Finds a subcommand that appears later on the command line and defines a long similar to
`name`, as clap's `did_you_mean_flag` does. */
let suggestFromSubcommands = (level, name, remaining) =>
  level.command.subcommands
  ->Array.filterMap(subcommand => {
    let built = ClapCommand.build(subcommand)
    switch (
      ClapSuggest.best(name, longCandidates(built)),
      remaining->Array.findIndexOpt(token => token == subcommand.name),
    ) {
    | (Some(candidate), Some(position)) => Some((position, subcommand.name, candidate))
    | (None, _) | (_, None) => None
    }
  })
  ->Array.reduce(None, (closest, (position, subcommandName, candidate)) =>
    switch closest {
    | Some((closestPosition, _, _)) if closestPosition <= position => closest
    | Some(_) | None => Some((position, subcommandName, candidate))
    }
  )

let trailingTip = argument => `to pass '${argument}' as a value, use '-- ${argument}'`

let unknownLong = (level, state, name, remaining) => {
  let argument = "--" ++ name
  switch ClapSuggest.best(name, longCandidates(level.command)) {
  | Some(candidate) =>
    let suggestedIds =
      ClapCommandDefinition.findLong(level.command, candidate)->Option.mapOr([], arg => [arg.id])
    Error(
      ClapError.UnknownArgument({
        context: usageContext(
          level,
          ~used=visibleIds(
            level,
            Array.concat(state.used, suggestedIds)->Array.reduce([], addUnique),
          ),
        ),
        argument,
        suggestion: Some("--" ++ candidate),
        tips: [],
      }),
    )
  | None =>
    let tips = switch suggestFromSubcommands(level, name, remaining) {
    | Some((_, subcommandName, candidate)) => [`'${subcommandName} --${candidate}' exists`]
    | None if hasPositionals(level) => [trailingTip(argument)]
    | None => []
    }
    Error(
      ClapError.UnknownArgument({
        context: usageContext(level, ~used=visibleIds(level, state.used)),
        argument,
        suggestion: None,
        tips,
      }),
    )
  }
}

let unknownShort = (level, short) => {
  let argument = "-" ++ short
  Error(
    ClapError.UnknownArgument({
      context: helpContext(level),
      argument,
      suggestion: None,
      tips: hasPositionals(level) ? [trailingTip(argument)] : [],
    }),
  )
}

/** Returns the help or version request for a `Help` or `Version` argument; any other action
also renders help, which callers rule out before calling. */
let displayHelpOrVersion = (level, arg: ClapArg.t, ~mode) =>
  switch arg.action {
  | Version => ClapError.DisplayVersion({output: ClapHelp.renderVersion(level.command)})
  | Help | Set | Append | SetTrue | SetFalse | Count =>
    ClapError.DisplayHelp({output: renderHelp(level, mode)})
  }

/** Reports `--flag=value` for an argument that takes no value. The usage lists the visible,
optional arguments used so far and `arg`, as clap's `parse_long_arg` does. */
let unexpectedValue = (level, state, arg: ClapArg.t, value) => {
  let used =
    state.used->Array.filter(id =>
      findArg(level, id)->Option.mapOr(false, used => !used.hidden && !used.required)
    )
  ClapError.UnexpectedValue({
    context: usageContext(level, ~used=addUnique(used, arg.id)),
    argument: ClapArg.display(arg),
    value,
  })
}

/** Parses `--name`, `--name=value` or `--name value` at `index`. Returns the new state and the
index of the next unread token. */
let parseLong = (level, state, tokens, index, token) => {
  let (name, attachedValue) = splitLong(token)
  switch ClapCommandDefinition.findLong(level.command, name) {
  | None => unknownLong(level, state, name, tokens->Array.slice(~start=index + 1))
  | Some(arg) =>
    switch (arg.action, attachedValue) {
    | (Set | Append, Some(value)) =>
      recordValue(level, state, arg, value)->Result.map(state => (state, index + 1))
    | (Set | Append, None) => takeSeparateValue(level, state, arg, tokens, index + 1)
    | (SetTrue | SetFalse | Count | Help | Version, Some(value)) =>
      Error(unexpectedValue(level, state, arg, value))
    | (Help | Version, None) => Error(displayHelpOrVersion(level, arg, ~mode=Long))
    | (SetTrue | SetFalse | Count, None) =>
      recordOccurrence(level, state, arg, "")->Result.map(state => (state, index + 1))
    }
  }
}

/** Parses a cluster of short flags such as `-vvv`, `-vn Ann` or `-nAnn` at `index`. `shorts`
holds the code points of the cluster that are still to parse. The first option that takes a
value consumes the rest of the cluster, minus one leading `=`. Returns the new state and the
index of the next unread token. */
let rec parseShortCluster = (level, state, tokens, index, shorts) =>
  switch shorts->Array.get(0) {
  | None => Ok((state, index + 1))
  | Some(short) =>
    let remaining = shorts->Array.slice(~start=1)
    switch ClapCommandDefinition.findShort(level.command, short) {
    | None => unknownShort(level, short)
    | Some(arg) =>
      let rest = remaining->Array.join("")
      switch (arg.action, rest) {
      | (Help | Version, _) => Error(displayHelpOrVersion(level, arg, ~mode=Short))
      | (Set | Append, "") => takeSeparateValue(level, state, arg, tokens, index + 1)
      | (Set | Append, rest) =>
        let value = rest->String.startsWith("=") ? rest->String.slice(~start=1) : rest
        recordValue(level, state, arg, value)->Result.map(state => (state, index + 1))
      | (SetTrue | SetFalse | Count, _) =>
        switch recordOccurrence(level, state, arg, "") {
        | Ok(state) => parseShortCluster(level, state, tokens, index, remaining)
        | Error(error) => Error(error)
        }
      }
    }
  }

let quoteAll = names => names->Array.map(name => `'${name}'`)->Array.join(", ")

let unknownArgument = (level, argument, ~tips) => Error(
  ClapError.UnknownArgument({context: helpContext(level), argument, suggestion: None, tips}),
)

/** Reports a word that is neither a free positional slot nor a subcommand, as clap's
`match_arg_error` does: a subcommand name after `--` gets a tip; otherwise a word similar to a
subcommand name, or any word when the command takes no positionals, is an unrecognized
subcommand, and the rest are unknown arguments. */
let unmatchedWord = (level, state, word) => {
  let invalidSubcommand = (~suggestion, ~tips) => Error(
    ClapError.InvalidSubcommand({context: helpContext(level), name: word, suggestion, tips}),
  )
  let candidates =
    level.command.subcommands->Array.flatMap(subcommand =>
      Array.concatMany([subcommand.name], [subcommand.aliases, subcommand.visibleAliases])
    )
  switch (
    state.isTrailing && ClapCommandDefinition.findSubcommand(level.command, word)->Option.isSome,
    candidates,
    ClapSuggest.didYouMean(word, candidates),
  ) {
  | (true, _, _) =>
    unknownArgument(
      level,
      word,
      ~tips=[`subcommand '${word}' exists; to use it, remove the '--' before it`],
    )
  | (false, [], _) => unknownArgument(level, word, ~tips=[])
  | (false, _, [candidate]) => invalidSubcommand(~suggestion=Some(candidate), ~tips=[])
  | (false, _, []) if !hasPositionals(level) => invalidSubcommand(~suggestion=None, ~tips=[])
  | (false, _, []) => unknownArgument(level, word, ~tips=[])
  | (false, _, similar) =>
    invalidSubcommand(
      ~suggestion=None,
      ~tips=[`some similar subcommands exist: ${quoteAll(similar)}`],
    )
  }
}

/** Records a positional value in the next free positional slot. A trailing `Append`
positional keeps its slot and collects the rest. */
let parsePositional = (level, state, token) =>
  switch ClapCommandDefinition.positionals(level.command)->Array.get(state.positionalIndex) {
  | Some(arg) =>
    recordValue(level, state, arg, token)->Result.map(state =>
      switch arg.action {
      | Append => {...state, isCollectingPositional: true}
      | Set | SetTrue | SetFalse | Count | Help | Version => {
          ...state,
          positionalIndex: state.positionalIndex + 1,
        }
      }
    )
  | None => unmatchedWord(level, state, token)
  }

/** Returns the usage name of a subcommand: the parent's usage name, the parent's required
arguments and the subcommand's name, as clap's `Command::build` computes it. */
let subcommandBinName = (level, subcommand: ClapCommand.t) => {
  let requiredNamed =
    ClapCommandDefinition.named(level.command)
    ->Array.filter(arg => arg.required)
    ->Array.map(ClapHelp.renderUsageSpec)
  let requiredPositionals =
    ClapCommandDefinition.positionals(level.command)
    ->Array.filter(arg => arg.required)
    ->Array.map(arg => ClapArg.displayPositional(arg, ~required=true))
  ClapHelp.joinWords(
    Array.concatMany([level.binName], [requiredNamed, requiredPositionals, [subcommand.name]]),
  )
}

let enterSubcommand = (level, subcommand: ClapCommand.t) =>
  makeLevel(
    subcommand,
    ~path=Array.concat(level.path, [subcommand.name]),
    ~binName=subcommandBinName(level, subcommand),
    ~env=level.env,
  )

/** Handles `help [COMMAND]...`: the long help of the named subcommand, or of `level`.

**Errors**: `DisplayHelp` on success, `InvalidSubcommand` for an unknown name. */
let rec displayHelpFor = (level, names) =>
  switch names->Array.get(0) {
  | None => Error(ClapError.DisplayHelp({output: renderHelp(level, Long)}))
  | Some(name) =>
    switch ClapCommandDefinition.findSubcommand(level.command, name) {
    | None =>
      Error(
        ClapError.InvalidSubcommand({
          context: helpContext(level),
          name,
          suggestion: None,
          tips: [],
        }),
      )
    | Some(subcommand) =>
      displayHelpFor(enterSubcommand(level, subcommand), names->Array.slice(~start=1))
    }
  }

let boolPossibleValues = [ClapPossibleValue.make("true"), ClapPossibleValue.make("false")]

/** Validates a `Count` value from the environment as clap's `u8` value parser does. */
let validateCount = input =>
  switch ClapValueParser.parse(ClapValueParser.int, input) {
  | Ok(count) if count >= 0 && count <= 255 => Ok()
  | Ok(count) => Error(`${Int.toString(count)} is not in 0..=255`)
  | Error(reason) => Error(reason)
  }

/** Validates an environment value with the value parser clap uses for the argument's action:
the argument's own for `Set` and `Append`, `true`/`false` for flags and `u8` for counters. */
let validateEnvValue = (level, arg: ClapArg.t, value) =>
  switch (arg.action, value) {
  | (SetTrue | SetFalse, "") => missingValue(level, {...arg, possibleValues: boolPossibleValues})
  | (SetTrue | SetFalse, value) =>
    validateValue(level, {...arg, possibleValues: boolPossibleValues}, value)
  | (Count, value) => validateValue(level, {...arg, validate: validateCount}, value)
  | (Set | Append | Help | Version, value) => validateValue(level, arg, value)
  }

/** Fills an absent argument from its environment variable, then from its default values.
Absent flags and counters default to `false` (`true` for `SetFalse`) and `0`, as in clap. */
let fallbackEntry = (level, arg: ClapArg.t): result<option<ClapMatches.entry>, ClapError.t> => {
  let envValue = arg.env->Option.flatMap(name => level.env->Dict.get(name))
  let defaulted = values => Ok(Some({ClapMatches.values, occurrences: 0, source: DefaultValue}))
  switch (arg.action, envValue) {
  | (Help | Version, _) => Ok(None)
  | (Set | Append | SetTrue | SetFalse | Count, Some(value)) =>
    validateEnvValue(level, arg, value)->Result.map(() => Some({
      ClapMatches.values: [value],
      occurrences: 0,
      source: EnvVariable,
    }))
  | (Set | Append, None) =>
    switch arg.defaultValues {
    | [] => Ok(None)
    | defaults => defaulted(defaults)
    }
  | (SetTrue, None) => defaulted(["false"])
  | (SetFalse, None) => defaulted(["true"])
  | (Count, None) => defaulted(["0"])
  }
}

let applyFallbacks = (level, state) =>
  level.command.args->Array.reduce(Ok(state.entries), (entries, arg) =>
    switch entries {
    | Error(error) => Error(error)
    | Ok(entries) if entries->Dict.get(arg.id)->Option.isSome => Ok(entries)
    | Ok(entries) =>
      fallbackEntry(level, arg)->Result.map(entry =>
        switch entry {
        | None => entries
        | Some(entry) => entries->withEntry(arg.id, entry)
        }
      )
    }
  )

/** Returns the ids of the arguments given on the command line, then of those read from the
environment, in clap's matcher order. Defaulted arguments are not explicit. */
let explicitIds = (level, state, entries) =>
  Array.concat(
    state.used,
    level.command.args
    ->Array.filter(arg =>
      switch entries->Dict.get(arg.id) {
      | Some({ClapMatches.source: EnvVariable, _}) => true
      | Some({source: CommandLine | DefaultValue, _}) | None => false
      }
    )
    ->Array.map(arg => arg.id),
  )

let checkRequired = (level, state, entries) => {
  let missing =
    level.command.args->Array.filter(arg =>
      arg.required && entries->Dict.get(arg.id)->Option.isNone
    )
  let ordered = Array.concat(
    missing->Array.filter(arg => !ClapArg.isPositional(arg)),
    missing->Array.filter(ClapArg.isPositional),
  )
  switch ordered {
  | [] => Ok()
  | ordered =>
    Error(
      ClapError.MissingRequiredArguments({
        context: usageContext(
          level,
          ~used=Array.concat(
            visibleIds(level, explicitIds(level, state, entries)),
            ordered->Array.map(arg => arg.id),
          )->Array.reduce([], addUnique),
        ),
        arguments: ordered->Array.map(arg => ClapArg.display({...arg, required: true})),
      }),
    )
  }
}

/** Validates one finished level and builds its matches, as clap's `add_env`, `add_defaults`
and `Validator` do, in that order. */
let finish = (level, state, subcommand) =>
  switch applyFallbacks(level, state) {
  | Error(error) => Error(error)
  | Ok(entries) =>
    switch subcommand {
    | None
      if level.command.argRequiredElseHelp &&
      explicitIds(level, state, entries)->Array.length == 0 =>
      Error(ClapError.DisplayHelpOnMissingArgumentOrSubcommand({output: renderHelp(level, Short)}))
    | None if level.command.subcommandRequired =>
      Error(
        ClapError.MissingSubcommand({
          context: helpContext(level),
          name: level.path->Array.join(" "),
          subcommands: ClapCommandDefinition.allSubcommandNames(level.command),
        }),
      )
    | None | Some(_) =>
      checkRequired(level, state, entries)->Result.map((): ClapMatches.t => {
        command: level.command,
        context: helpContext(level),
        entries,
        subcommand,
      })
    }
  }

/** Parses the tokens of one command level from `index` on. */
let rec parseLevel = (level, state, tokens, index) =>
  switch tokens->Array.get(index) {
  | None => finish(level, state, None)
  | Some(token) if state.isTrailing =>
    continueWith(level, parsePositional(level, state, token), tokens, index + 1)
  | Some("--") => parseLevel(level, {...state, isTrailing: true}, tokens, index + 1)
  | Some(token) if token->String.startsWith("--") =>
    continueAfterOption(level, parseLong(level, state, tokens, index, token), tokens)
  | Some(token) if isOptionLike(token) =>
    continueAfterOption(
      level,
      parseShortCluster(
        level,
        state,
        tokens,
        index,
        ClapText.codePoints(token)->Array.slice(~start=1),
      ),
      tokens,
    )
  | Some(token) if state.isCollectingPositional =>
    continueWith(level, parsePositional(level, state, token), tokens, index + 1)
  | Some(token) =>
    switch ClapCommandDefinition.findSubcommand(level.command, token) {
    | Some(subcommand) if ClapCommandDefinition.isHelpSubcommand(subcommand) =>
      displayHelpFor(level, tokens->Array.slice(~start=index + 1))
    | Some(subcommand) =>
      parseLevel(
        enterSubcommand(level, subcommand),
        initialState,
        tokens,
        index + 1,
      )->Result.flatMap(matches => finish(level, state, Some((subcommand.name, matches))))
    | None => continueWith(level, parsePositional(level, state, token), tokens, index + 1)
    }
  }
and continueWith = (level, parsed, tokens, nextIndex) =>
  switch parsed {
  | Ok(state) => parseLevel(level, state, tokens, nextIndex)
  | Error(error) => Error(error)
  }
and continueAfterOption = (level, parsed, tokens) =>
  switch parsed {
  | Ok((state, nextIndex)) =>
    parseLevel(level, {...state, isCollectingPositional: false}, tokens, nextIndex)
  | Error(error) => Error(error)
  }

/** Parses `argv` against `command`. The first element of `argv` is the program name and is
ignored. **Errors**: every `ClapError.t` case. */
let getMatchesFrom = (command: ClapCommand.t, argv, ~env) =>
  parseLevel(
    makeLevel(command, ~path=[command.name], ~binName=command.name, ~env),
    initialState,
    argv->Array.slice(~start=1),
    0,
  )
