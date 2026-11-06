// expect: @clap.args needs a record type. Use @clap.subcommand for a variant.
// line: 4
@clap.args
type t = A | B
