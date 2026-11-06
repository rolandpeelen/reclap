/*** The `edge` CLI of `reference/clap-fixtures/src/bin/edge.rs`, written with the builder API.

Each subcommand isolates one parser, usage or environment edge case. */

let flags =
  Clap.Command.make("flags")
  ->Clap.Command.about("Flags and counters read from the environment")
  ->Clap.Command.arg(
    Clap.Arg.make("flag")
    ->Clap.Arg.long("flag")
    ->Clap.Arg.env("FLAG")
    ->Clap.Arg.action(SetTrue)
    ->Clap.Arg.help("A SetTrue flag"),
  )
  ->Clap.Command.arg(
    Clap.Arg.make("plain")
    ->Clap.Arg.long("plain")
    ->Clap.Arg.env("PLAIN")
    ->Clap.Arg.action(SetFalse)
    ->Clap.Arg.help("A SetFalse flag"),
  )
  ->Clap.Command.arg(
    Clap.Arg.make("verbose")
    ->Clap.Arg.short("v")
    ->Clap.Arg.env("VCOUNT")
    ->Clap.Arg.action(Count)
    ->Clap.Arg.help("A counter"),
  )

let need =
  Clap.Command.make("need")
  ->Clap.Command.about("Requires an argument, else prints help")
  ->Clap.Command.argRequiredElseHelp(true)
  ->Clap.Command.arg(
    Clap.Arg.make("name")->Clap.Arg.long("name")->Clap.Arg.env("NAME")->Clap.Arg.help("Who"),
  )

let run = Clap.Command.make("run")->Clap.Command.about("Run it")

let pos =
  Clap.Command.make("pos")
  ->Clap.Command.about("A positional and a subcommand")
  ->Clap.Command.arg(Clap.Arg.make("file")->Clap.Arg.help("A file"))
  ->Clap.Command.subcommand(run)

let multi =
  Clap.Command.make("multi")
  ->Clap.Command.about("A multi-value positional and a subcommand")
  ->Clap.Command.arg(Clap.Arg.make("files")->Clap.Arg.action(Append)->Clap.Arg.help("Files"))
  ->Clap.Command.arg(
    Clap.Arg.make("loud")
    ->Clap.Arg.long("loud")
    ->Clap.Arg.action(SetTrue)
    ->Clap.Arg.help("Be loud"),
  )
  ->Clap.Command.subcommand(run)

let hid =
  Clap.Command.make("hid")
  ->Clap.Command.about("Hidden required arguments")
  ->Clap.Command.arg(
    Clap.Arg.make("secret")->Clap.Arg.long("secret")->Clap.Arg.required(true)->Clap.Arg.hide,
  )
  ->Clap.Command.arg(
    Clap.Arg.make("out")->Clap.Arg.long("out")->Clap.Arg.required(true)->Clap.Arg.help("Output"),
  )
  ->Clap.Command.arg(
    Clap.Arg.make("name")->Clap.Arg.long("name")->Clap.Arg.env("NAME")->Clap.Arg.help("Name"),
  )
  ->Clap.Command.arg(Clap.Arg.make("hid")->Clap.Arg.long("hid")->Clap.Arg.hide)
  ->Clap.Command.arg(Clap.Arg.make("opt")->Clap.Arg.long("opt")->Clap.Arg.help("Optional"))
  ->Clap.Command.arg(Clap.Arg.make("token")->Clap.Arg.required(true)->Clap.Arg.hide)

let emoji =
  Clap.Command.make("emoji")
  ->Clap.Command.about("Non-BMP characters")
  ->Clap.Command.arg(
    Clap.Arg.make("rocket")
    ->Clap.Arg.short("🚀")
    ->Clap.Arg.long("rocket")
    ->Clap.Arg.action(SetTrue)
    ->Clap.Arg.help("Launch"),
  )
  ->Clap.Command.arg(
    Clap.Arg.make("to")
    ->Clap.Arg.long("to")
    ->Clap.Arg.valueName("🌍")
    ->Clap.Arg.help("Destination"),
  )
  ->Clap.Command.arg(
    Clap.Arg.make("x")->Clap.Arg.short("x")->Clap.Arg.action(SetTrue)->Clap.Arg.help("Ex"),
  )

let strict =
  Clap.Command.make("strict")
  ->Clap.Command.about("A required subcommand and an environment value")
  ->Clap.Command.subcommandRequired(true)
  ->Clap.Command.argRequiredElseHelp(true)
  ->Clap.Command.arg(
    Clap.Arg.make("level")
    ->Clap.Arg.long("level")
    ->Clap.Arg.env("LEVEL")
    ->Clap.Arg.valueParser(GreetCli.u8ValueParser)
    ->Clap.Arg.help("Level"),
  )
  ->Clap.Command.subcommand(Clap.Command.make("go")->Clap.Command.about("Go"))

let command =
  Clap.Command.make("edge")
  ->Clap.Command.version("0.1.0")
  ->Clap.Command.about("Edge cases of the clap parser")
  ->Clap.Command.subcommand(flags)
  ->Clap.Command.subcommand(need)
  ->Clap.Command.subcommand(pos)
  ->Clap.Command.subcommand(multi)
  ->Clap.Command.subcommand(hid)
  ->Clap.Command.subcommand(emoji)
  ->Clap.Command.subcommand(strict)

let sourceName = (source: Clap.Matches.valueSource) =>
  switch source {
  | CommandLine => "CommandLine"
  | EnvVariable => "EnvVariable"
  | DefaultValue => "DefaultValue"
  }

/** Dumps every argument of every level as `edge.rs` does: raw values and value source. */
let rec dump = (matches: Clap.Matches.t): JSON.t => {
  let args = Clap.Matches.ids(matches)->Array.map(id => (
    id,
    JSON.Object(
      Dict.fromArray([
        (
          "values",
          JSON.Array(
            Clap.Matches.getRaw(matches, id)
            ->Option.getOr([])
            ->Array.map(value => JSON.String(value)),
          ),
        ),
        (
          "source",
          Clap.Matches.valueSource(matches, id)->Option.mapOr(JSON.Null, source => JSON.String(
            sourceName(source),
          )),
        ),
      ]),
    ),
  ))
  let subcommand = switch Clap.Matches.subcommand(matches) {
  | None => JSON.Null
  | Some((name, subcommandMatches)) =>
    JSON.Object(Dict.fromArray([("name", JSON.String(name)), ("matches", dump(subcommandMatches))]))
  }
  JSON.Object(
    Dict.fromArray([("args", JSON.Object(Dict.fromArray(args))), ("subcommand", subcommand)]),
  )
}
