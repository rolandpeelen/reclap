// expect: The short name -h is used by both the automatic --help flag and field `host`.
// line: 5
@clap.parser
type t = {
  @arg({short, long}) host: string,
}
