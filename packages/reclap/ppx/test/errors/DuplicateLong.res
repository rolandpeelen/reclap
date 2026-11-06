// expect: The long name --name is used by both field `name` and field `title`.
// line: 6
@clap.args
type t = {
  @arg({long}) name: string,
  @arg({long: "name"}) title: string,
}
