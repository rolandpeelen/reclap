// The builtin value types spelled as their standard library modules' `t`:
// they get the same value parsers as `string`, `int`, `float` and `bool`.

@clap.parser
type t = {
  @arg(long) name: String.t,
  @arg({long, default: 1}) count: Int.t,
  @arg(long) ratio: option<Float.t>,
  @arg({short, long}) force: Bool.t,
  @arg({long, action: Set}) enabled: Stdlib.Bool.t,
  @arg({short, action: Count}) verbose: Int.t,
  @arg(long) tag: array<String.t>,
  @arg(long) weight: option<array<Float.t>>,
  files: array<Stdlib.String.t>,
}
