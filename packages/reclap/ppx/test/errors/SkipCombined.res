// expect: `skip` cannot be combined with other @arg options.
// line: 5
@clap.args
type t = {
  @arg({long, skip: 1}) attempts: int,
}
