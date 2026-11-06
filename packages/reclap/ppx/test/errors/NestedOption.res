// expect: Unsupported field type: `option<int>` cannot be nested here.
// line: 5
@clap.args
type t = {
  @arg(long) numbers: option<option<int>>,
}
