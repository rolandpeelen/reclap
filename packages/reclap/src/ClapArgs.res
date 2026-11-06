type t<'value> = {
  augment: ClapCommand.t => ClapCommand.t,
  fromMatches: ClapMatches.t => result<'value, ClapError.t>,
}

let make = (augment, fromMatches) => {augment, fromMatches}

let augment = (args, command) => args.augment(command)

let fromMatches = (args, matches) => args.fromMatches(matches)
