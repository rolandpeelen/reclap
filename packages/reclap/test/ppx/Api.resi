// The PPX generates matching `let` declarations in interfaces.

@clap.valueEnum
type mode = Fast | Safe

@clap.args
type options

@clap.parser
type t = {
  mode: mode,
  @command({flatten}) options: options,
}

@clap.subcommand
type action = Start | Stop
