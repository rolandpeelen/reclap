// expect: The subcommand name "start" is used by both constructor `Start` and constructor `Begin`.
// line: 6
@clap.subcommand
type t =
  | Start
  | @command({name: "start"}) Begin
