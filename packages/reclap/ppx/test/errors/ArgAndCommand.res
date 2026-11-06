// expect: @arg and @command cannot be combined on one field.
// line: 8
@clap.args
type common = {@arg(long) debug: bool}

@clap.args
type t = {
  @arg(long) @command({flatten}) common: common,
}
