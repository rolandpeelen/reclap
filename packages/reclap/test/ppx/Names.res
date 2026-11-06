// Names that look like duplicates but that clap accepts: -V on a command
// without a version, and an alias that repeats the argument's own long name.

@clap.parser
type t = {
  @arg({short: "V", long}) verbose: bool,
  @arg({long, alias: "colour"}) colour: option<string>,
}
