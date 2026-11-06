// The example from docs/design.md.

/** A type without @clap attributes passes through untouched. */
type plain = {@as("x") value: int}

@clap.subcommand
type command =
  /** Says hello */
  | Hello({@arg(long) loud: bool})
  /** Says goodbye */
  | Bye

/** Simple program to greet a person */
@clap.parser @command({version: "1.0.0"})
type t = {
  /** Name of the person to greet */
  @arg({short, long}) name: string,
  /** Number of times to greet */
  @arg({short, long, default: 1}) count: int,
  @arg({short, action: Count}) verbose: int,
  @command(subcommand) command: option<command>,
}

let run = argv => Clap.tryParseFrom(parser, argv)
let plainValue = {value: 1}
