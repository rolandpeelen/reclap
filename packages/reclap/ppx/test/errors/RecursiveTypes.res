// expect: These @clap types depend on each other: command. Recursive @clap types are not supported.
// line: 4
@clap.subcommand
type rec command = Leaf | @command({subcommand}) Nested(command)
