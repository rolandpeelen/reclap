// expect: `action: Count` needs a field of type `int`, not `string`.
// line: 5
@clap.args
type t = {
  @arg({short, action: Count}) verbose: string,
}
