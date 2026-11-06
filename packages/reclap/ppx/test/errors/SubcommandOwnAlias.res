// expect: The subcommand name "list" is used twice by constructor `List`.
// line: 4
@clap.subcommand
type t = | @command({alias: "list"}) List | Show
