// expect: The subcommand name "rm" is used by both constructor `Remove` and constructor `Prune`.
// line: 6
@clap.parser
type t =
  | @command({visibleAlias: "rm"}) Remove
  | @command({aliases: ["rm"]}) Prune
