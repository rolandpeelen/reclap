// expect: The long name --colour is used by both field `colour` and field `color`.
// line: 6
@clap.args
type t = {
  @arg({long}) colour: string,
  @arg({long, visibleAlias: "colour"}) color: option<string>,
}
