type t<'value> = {
  command: ClapCommand.t,
  fromMatches: ClapMatches.t => result<'value, ClapError.t>,
}

let fromArgs = (command, args) => {
  command: ClapArgs.augment(args, command),
  fromMatches: matches => ClapArgs.fromMatches(args, matches),
}

let fromSubcommand = (command, subcommands) => {
  command: ClapSubcommand.augmentRequired(subcommands, command),
  fromMatches: matches => ClapSubcommand.fromMatches(subcommands, matches),
}

let command = parser => parser.command
