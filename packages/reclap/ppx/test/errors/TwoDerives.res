// expect: A type takes one of @clap.parser, @clap.args, @clap.subcommand and @clap.valueEnum.
// line: 3
@clap.parser @clap.args
type t = {name: string}
