// expect: Unknown @command option `version`. Expected one of: renameAll, renameAllEnv.
// line: 3
@clap.args @command({version: "1.0.0"})
type t = {name: string}
