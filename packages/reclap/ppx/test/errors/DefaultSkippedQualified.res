// expect: The default `Trace` is a skipped value of `Level.t` (@value(skip))
// line: 12
module Level = {
  @clap.valueEnum
  type t =
    | Info
    | @value({skip}) Trace
}

@clap.args
type t = {
  @arg({long, default: [Level.Info, Level.Trace]}) levels: array<Level.t>,
}
