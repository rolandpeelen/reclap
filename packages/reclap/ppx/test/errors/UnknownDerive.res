// expect: Unknown attribute @clap.parsr. Expected one of: @clap.parser, @clap.args, @clap.subcommand, @clap.valueEnum.
// line: 3
@clap.parsr
type t = {name: string}
