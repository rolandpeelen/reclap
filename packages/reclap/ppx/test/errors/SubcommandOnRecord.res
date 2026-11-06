// expect: @clap.subcommand needs a variant type. Use @clap.args for a record.
// line: 4
@clap.subcommand
type t = {name: string}
