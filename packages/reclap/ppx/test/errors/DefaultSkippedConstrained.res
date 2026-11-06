// expect: The default `Trace` is a skipped value of `Level.t` (@value(skip))
// line: 13
module Level: {
  @clap.valueEnum
  type t = Info | Trace
} = {
  @clap.valueEnum
  type t = Info | @value(skip) Trace
}

@clap.args
type t = {
  @arg({long, default: Level.Trace})
  level: Level.t,
}
