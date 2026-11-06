// expect: The long name --help is used by both the automatic --help flag and field `manual`.
// line: 5
@clap.args
type t = {
  @arg({long, alias: "help"}) manual: bool,
}
