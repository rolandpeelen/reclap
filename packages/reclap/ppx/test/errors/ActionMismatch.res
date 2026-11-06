// expect: `action: Append` does not fit the field type `option<string>`.
// line: 5
@clap.args
type t = {
  @arg({long, action: Append}) name: option<string>,
}
