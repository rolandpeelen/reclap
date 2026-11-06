// expect: A `bool` flag must be named: add `short` or `long`
// line: 5
@clap.args
type t = {
  verbose: bool,
}
