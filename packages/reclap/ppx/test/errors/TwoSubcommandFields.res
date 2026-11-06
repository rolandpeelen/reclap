// expect: A record can have only one @command({subcommand}) field.
// line: 9
@clap.subcommand
type command = Start | Stop

@clap.parser
type t = {
  @command({subcommand}) first: command,
  @command({subcommand}) second: option<command>,
}
