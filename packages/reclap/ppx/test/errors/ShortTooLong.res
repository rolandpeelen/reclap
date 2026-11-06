// expect: `short` must be one character, not "ab".
// line: 5
@clap.args
type t = {
  @arg({short: "ab"}) name: string,
}
