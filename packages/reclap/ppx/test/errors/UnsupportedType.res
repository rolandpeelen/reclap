// expect: An argument value type must be a named type without parameters, such as `command` or `Remote.t`, not `list<int>`.
// line: 5
@clap.args
type t = {
  @arg(long) numbers: list<int>,
}
