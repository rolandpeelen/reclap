// expect: `skip` needs a value, such as skip: ...
// line: 5
@clap.args
type t = {
  @arg(skip) attempts: int,
}
