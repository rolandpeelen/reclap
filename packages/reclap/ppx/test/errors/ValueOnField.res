// expect: @value is not valid on record fields.
// line: 5
@clap.args
type t = {
  @value({name: "x"}) name: string,
}
