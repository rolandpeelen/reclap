type rec t = ClapCommandDefinition.t = {
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

let make = ClapCommandDefinition.make

let version = (command, version) => {...command, version: Some(version)}

let about = (command, about) => {...command, about: Some(about)}

let longAbout = (command, longAbout) => {...command, longAbout: Some(longAbout)}

let author = (command, author) => {...command, author: Some(author)}

let alias = (command, alias) => {...command, aliases: Array.concat(command.aliases, [alias])}

let visibleAlias = (command, alias) => {
  ...command,
  visibleAliases: Array.concat(command.visibleAliases, [alias]),
}

let arg = (command, arg) => {...command, args: Array.concat(command.args, [arg])}

let subcommand = (command, subcommand) => {
  ...command,
  subcommands: Array.concat(command.subcommands, [subcommand]),
}

let subcommandRequired = (command, subcommandRequired) => {...command, subcommandRequired}

let argRequiredElseHelp = (command, argRequiredElseHelp) => {...command, argRequiredElseHelp}

let hide = command => {...command, hidden: true}

let build = ClapCommandDefinition.build

let renderHelp = command =>
  ClapHelp.render(build(command), ~binName=command.name, ~mode=Short, ~env=NodeProcess.env)

let renderLongHelp = command =>
  ClapHelp.render(build(command), ~binName=command.name, ~mode=Long, ~env=NodeProcess.env)

let renderUsage = command => ClapHelp.renderUsage(build(command), ~binName=command.name)

let renderVersion = command => ClapHelp.renderVersion(command)
