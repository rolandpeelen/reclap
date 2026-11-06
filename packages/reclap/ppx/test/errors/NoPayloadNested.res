// expect: @command({subcommand}) on a constructor needs a payload type, as in Remote(remote).
// line: 4
@clap.subcommand
type t = | @command({subcommand}) Remote
