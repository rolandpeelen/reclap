// expect: The argument id "target" is used by both field `source` and field `destination`.
// line: 6
@clap.args
type t = {
  @arg({id: "target"}) source: string,
  @arg({id: "target"}) destination: string,
}
