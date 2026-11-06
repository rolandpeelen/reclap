// expect: Unknown `renameAll` value "kebab". Expected one of: "kebab-case", "snake_case"
// line: 3
@clap.args @command({renameAll: "kebab"})
type t = {name: string}
