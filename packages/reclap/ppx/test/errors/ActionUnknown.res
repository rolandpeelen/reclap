// expect: Unknown action `Help`. Expected one of: Set, Append, SetTrue, SetFalse, Count.
// line: 5
@clap.args
type t = {
  @arg({long, action: Help}) help: bool,
}
