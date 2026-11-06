// Edge cases: values that never read the matches, escaped field names,
// a parser in a nested module, a JSDoc style doc comment, and a value enum whose values
// are all skipped.

@clap.args
type constant = {@arg({skip: "fixed"}) value: string}

@clap.subcommand
type command =
  | Run({@arg({skip: 0}) code: int})
  | @command(hide) Noop

module Sub = {
  /** A nested program */
  @clap.parser
  type t = {
    /**
     * Only print what would happen.
     *
     * JSDoc style: the leading stars are not part of the help.
     */
    @arg(long)
    \"dry-run": bool,
    @arg({long, short: "N"}) \"max-count": option<int>,
    @command(flatten) constant: constant,
    @command(subcommand) command: command,
  }
}

@clap.valueEnum
type internal = | @value(skip) Hidden

let subParser = Sub.parser
