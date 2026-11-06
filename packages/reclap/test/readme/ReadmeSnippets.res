// The snippets in README.md, compiled so the README cannot drift.

module Greet = {
  /** Simple program to greet a person */
  @clap.parser @command({name: "greet", version: "1.0.0"})
  type t = {
    /** Name of the person to greet */
    @arg({short, long}) name: string,
    /** Number of times to greet */
    @arg({short, long, default: 1}) count: int,
  }
}

module Subcommands = {
  @clap.subcommand
  type remote =
    /** Add a remote */
    | Add({name: string, url: string})
    /** Remove a remote */
    | @command({alias: "rm"}) Remove({name: string})

  @clap.args
  type addArgs = {@arg({short: "n", long}) dryRun: bool, paths: array<string>}

  @clap.subcommand
  type command =
    | Add(addArgs) // a newtype variant, like `Add(AddArgs)` in Rust
    | @command({visibleAlias: "ci"}) Commit({@arg({short, long}) message: string})
    | @command({subcommand}) Remote(option<remote>) // nested; optional
    | Status
}

module ValueEnums = {
  @clap.valueEnum
  type color =
    /** Always colour the output */
    | Always
    | @value({alias: "off"}) Never
    | Auto
}

module Builder = {
  let command =
    Clap.Command.make("prog")
    ->Clap.Command.arg(Clap.Arg.make("name")->Clap.Arg.short("n")->Clap.Arg.long("name"))

  let name = () =>
    switch Clap.getMatchesFrom(command, ["prog", "-n", "Ann"]) {
    | Ok(matches) => Clap.Matches.getOne(matches, "name", Clap.ValueParser.string)
    | Error(error) => Clap.Error.exit(error)
    }
}
