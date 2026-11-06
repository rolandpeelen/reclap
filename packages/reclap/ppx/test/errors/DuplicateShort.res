// expect: The short name -n is used by both field `name` and field `number`.
// line: 6
@clap.args
type t = {
  @arg({short, long}) name: string,
  @arg({short, long}) number: int,
}
