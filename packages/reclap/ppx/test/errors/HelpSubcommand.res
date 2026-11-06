// expect: The subcommand name "help" is used by both the automatic help subcommand and constructor `Help`.
// line: 5
@clap.subcommand
type t =
  | Help
  | Status
