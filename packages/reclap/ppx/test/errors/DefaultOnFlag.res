// expect: `default` is not supported for flags, which take no value.
// line: 5
@clap.args
type t = {
  @arg({long, default: true}) force: bool,
}
