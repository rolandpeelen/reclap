// expect: The short name -V is used by both the automatic --version flag and field `verbose`.
// line: 5
@clap.parser @command({version: "1.0.0"})
type t = {
  @arg({short: "V", long}) verbose: bool,
}
