type t<'value> = {
  augment: ClapCommand.t => ClapCommand.t,
  fromMatches: ClapMatches.t => result<'value, ClapError.t>,
}

let make = (augment, fromMatches) => {augment, fromMatches}

let augment = (subcommands, command) => subcommands.augment(command)

let augmentRequired = (subcommands, command) =>
  subcommands.augment(command)
  ->ClapCommand.subcommandRequired(true)
  ->ClapCommand.argRequiredElseHelp(true)

let fromMatches = (subcommands, matches) => subcommands.fromMatches(matches)

let fromMatchesOptional = (subcommands, matches) =>
  switch ClapMatches.subcommand(matches) {
  | None => Ok(None)
  | Some(_) => subcommands.fromMatches(matches)->Result.map(value => Some(value))
  }
