@clap.valueEnum
type mode = Fast | Safe

@clap.args
type options = {@arg(long) dry: bool}

@clap.parser
type t = {
  mode: mode,
  @command({flatten}) options: options,
}

@clap.subcommand
type action = Start | Stop
