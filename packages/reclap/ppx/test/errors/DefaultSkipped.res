// expect: The default `Trace` is a skipped value of `level` (@value(skip)): it has no name to show in help or to parse. Choose a value that is not skipped.
// line: 10
@clap.valueEnum
type level =
  | Info
  | @value(skip) Trace

@clap.parser
type t = {
  @arg({long, default: Trace})
  level: level,
}
