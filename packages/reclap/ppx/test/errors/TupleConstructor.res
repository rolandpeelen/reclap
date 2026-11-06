// expect: A subcommand constructor takes no payload, one @clap.args type, or an inline record.
// line: 4
@clap.subcommand
type t = Pair(int, string)
