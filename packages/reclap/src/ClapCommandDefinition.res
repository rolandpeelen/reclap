/*** The command definition record and the queries that the parser and the help renderer share.

`ClapCommand` re-exports the type; this module exists so that `ClapHelp` can render a
command before `ClapCommand` is defined. */

type rec t = {
  name: string,
  aliases: array<string>,
  visibleAliases: array<string>,
  version: option<string>,
  about: option<string>,
  longAbout: option<string>,
  author: option<string>,
  args: array<ClapArg.t>,
  subcommands: array<t>,
  subcommandRequired: bool,
  argRequiredElseHelp: bool,
  hidden: bool,
}

let helpSubcommandAbout = "Print this message or the help of the given subcommand(s)"

let make = name => {
  name,
  aliases: [],
  visibleAliases: [],
  version: None,
  about: None,
  longAbout: None,
  author: None,
  args: [],
  subcommands: [],
  subcommandRequired: false,
  argRequiredElseHelp: false,
  hidden: false,
}

let isSomeString = (option: option<string>, value: string) =>
  switch option {
  | Some(candidate) => candidate == value
  | None => false
  }

let hasArgWithLong = (command, long) => command.args->Array.some(arg => isSomeString(arg.long, long))

let hasArgWithShort = (command, short) => command.args->Array.some(arg => isSomeString(arg.short, short))

let hasArgWithId = (command, id) => command.args->Array.some(arg => arg.id == id)

let hasSubcommand = (command, name) =>
  command.subcommands->Array.some(subcommand => subcommand.name == name)

let makeAutomaticArg = (command, ~id, ~short, ~action) => {
  let arg = ClapArg.make(id)->ClapArg.long(id)->ClapArg.action(action)
  hasArgWithShort(command, short) ? arg : arg->ClapArg.short(short)
}

let addHelpArg = command =>
  switch hasArgWithId(command, "help") || hasArgWithLong(command, "help") {
  | true => command
  | false => {
      ...command,
      args: Array.concat(
        command.args,
        [makeAutomaticArg(command, ~id="help", ~short="h", ~action=ClapArg.Help)],
      ),
    }
  }

let addVersionArg = command =>
  switch command.version {
  | None => command
  | Some(_) if hasArgWithId(command, "version") || hasArgWithLong(command, "version") => command
  | Some(_) => {
      ...command,
      args: Array.concat(
        command.args,
        [makeAutomaticArg(command, ~id="version", ~short="V", ~action=ClapArg.Version)],
      ),
    }
  }

let helpSubcommand = {
  ...make("help"),
  about: Some(helpSubcommandAbout),
  args: [
    ClapArg.make("subcommand")
    ->ClapArg.valueName("COMMAND")
    ->ClapArg.action(ClapArg.Append)
    ->ClapArg.help("Print help for the subcommand(s)"),
  ],
}

let addHelpSubcommand = command =>
  switch command.subcommands {
  | [] => command
  | _ if hasSubcommand(command, "help") => command
  | subcommands => {...command, subcommands: Array.concat(subcommands, [helpSubcommand])}
  }

/** Adds `-h, --help`, `-V, --version` when a version is set, and the `help` subcommand when
there are subcommands, unless the command already defines them. Mirrors `Command::build`
for one level; the parser builds each subcommand when it enters it. Idempotent. */
let build = command => command->addHelpArg->addVersionArg->addHelpSubcommand

/** Returns whether this is the automatic `help` subcommand that `build` adds. */
let isHelpSubcommand = command =>
  command.name == "help" && isSomeString(command.about, helpSubcommandAbout)

let positionals = command => command.args->Array.filter(ClapArg.isPositional)

let named = command => command.args->Array.filter(arg => !ClapArg.isPositional(arg))

let findLong = (command, long) =>
  command.args->Array.find(arg =>
    isSomeString(arg.long, long) ||
    arg.aliases->Array.includes(long) ||
    arg.visibleAliases->Array.includes(long))

let findShort = (command, short) => command.args->Array.find(arg => isSomeString(arg.short, short))

let findSubcommand = (command, name) =>
  command.subcommands->Array.find(subcommand =>
    subcommand.name == name ||
    subcommand.aliases->Array.includes(name) ||
    subcommand.visibleAliases->Array.includes(name)
  )
