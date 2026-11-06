// expect: Unknown @arg option `shrot`. Expected one of: short, long,
// line: 5
@clap.args
type t = {
  @arg({shrot, long}) name: string,
}
