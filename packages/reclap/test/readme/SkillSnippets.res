// The snippets in skills/reclap/SKILL.md that README.md does not have,
// compiled so the skill cannot drift.

module Subcommands = {
  @clap.args
  type addArgs = {@arg({short: "n", long}) dryRun: bool, paths: array<string>}

  @clap.subcommand
  type remote =
    /** Add a remote */
    | Add({name: string, url: string})
    /** Remove a remote */
    | @command({alias: "rm"}) Remove({name: string})

  @clap.subcommand
  type command =
    | Add(addArgs) // one @clap.args type, like `Add(AddArgs)` in Rust
    | @command({visibleAlias: "ci"}) Commit({@arg({short, long}) message: string})
    | @command(subcommand) Remote(option<remote>) // nested subcommands, optional
    | Status // no arguments

  /** A fictional version control system */
  @clap.parser @command({name: "git", version: "2.0.0"})
  type t = {
    @arg({short, long}) quiet: bool,
    @command(subcommand) command: command, // required; option<command> is optional
  }
}

module ValueEnums = {
  @clap.valueEnum
  type color =
    /** Always colour the output */
    | Always
    | @value({alias: "off"}) Never
    | Auto
    | @value(skip) Internal // not accepted on the command line

  @clap.args
  type t = {@arg({long, default: Auto}) color: color}
}

module CustomValues = {
  type port = Port(int)

  let portValueParser = Clap.ValueParser.make(
    text =>
      switch Int.fromString(text) {
      | Some(number) if number > 0 && number < 65536 => Ok(Port(number))
      | Some(_) | None => Error("not a port number")
      },
    (Port(number)) => Int.toString(number),
  )

  @clap.args
  type t = {@arg({long, default: Port(8080)}) port: port}
}
