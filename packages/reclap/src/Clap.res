module PossibleValue = ClapPossibleValue
module ValueParser = ClapValueParser
module Arg = ClapArg
module Command = ClapCommand
module Error = ClapError
module Matches = ClapMatches
module Args = ClapArgs
module Subcommand = ClapSubcommand
module Parser = ClapParser

let getMatchesFrom = (command, argv, ~env=NodeProcess.env) =>
  ClapParse.getMatchesFrom(command, argv, ~env)

let tryParseFrom = (parser: ClapParser.t<'value>, argv, ~env=NodeProcess.env) =>
  getMatchesFrom(parser.command, argv, ~env)->Result.flatMap(parser.fromMatches)

// `process.argv` starts with the Node executable and the script path; the script path plays
// the role of clap's program name.
let processArguments = () => NodeProcess.argv->Array.slice(~start=1)

let tryParse = parser => tryParseFrom(parser, processArguments())

let parse = parser =>
  switch tryParse(parser) {
  | Ok(value) => value
  | Error(error) => ClapError.exit(error)
  }
