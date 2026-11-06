/*** Typed decoding through `ClapArgs`, `ClapSubcommand` and `ClapParser`, written the way the
PPX generates it. */

open Vitest

type level =
  | Debug
  | Info

let levelValueParser = Clap.ValueParser.enum([
  (Debug, Clap.PossibleValue.make("debug")->Clap.PossibleValue.help("Everything")),
  (Info, Clap.PossibleValue.make("info")->Clap.PossibleValue.alias("normal")),
])

type remote =
  | Add({name: string})
  | Show

type command =
  | Push({force: bool, level: level})
  | Remote(remote)
  | Status

type t = {
  verbose: int,
  command: option<command>,
}

let remoteSubcommand: Clap.Subcommand.t<remote> = Clap.Subcommand.make(
  command =>
    command
    ->Clap.Command.subcommand(
      Clap.Command.make("add")->Clap.Command.arg(
        Clap.Arg.make("name")->Clap.Arg.valueName("NAME")->Clap.Arg.required(true),
      ),
    )
    ->Clap.Command.subcommand(Clap.Command.make("show")),
  matches =>
    switch Clap.Matches.subcommand(matches) {
    | Some(("add", matches)) =>
      Clap.Matches.getRequired(matches, "name", Clap.ValueParser.string)->Result.map(name => Add({
        name: name,
      }))
    | Some(("show", _)) => Ok(Show)
    | Some(_) | None => Clap.Matches.missingSubcommand(matches)
    },
)

let commandSubcommand: Clap.Subcommand.t<command> = Clap.Subcommand.make(
  command =>
    command
    ->Clap.Command.subcommand(
      Clap.Command.make("push")
      ->Clap.Command.alias("p")
      ->Clap.Command.arg(Clap.Arg.make("force")->Clap.Arg.long("force")->Clap.Arg.action(SetTrue))
      ->Clap.Command.arg(
        Clap.Arg.make("level")
        ->Clap.Arg.long("level")
        ->Clap.Arg.valueName("LEVEL")
        ->Clap.Arg.valueParser(levelValueParser)
        ->Clap.Arg.defaultValue(levelValueParser, Info),
      ),
    )
    ->Clap.Command.subcommand(
      Clap.Subcommand.augmentRequired(remoteSubcommand, Clap.Command.make("remote")),
    )
    ->Clap.Command.subcommand(Clap.Command.make("status")),
  matches =>
    switch Clap.Matches.subcommand(matches) {
    | Some(("push", matches)) =>
      Clap.Matches.getRequired(matches, "level", levelValueParser)->Result.map(level => Push({
        force: Clap.Matches.getFlag(matches, "force"),
        level,
      }))
    | Some(("remote", matches)) =>
      Clap.Subcommand.fromMatches(remoteSubcommand, matches)->Result.map(remote => Remote(remote))
    | Some(("status", _)) => Ok(Status)
    | Some(_) | None => Clap.Matches.missingSubcommand(matches)
    },
)

let args: Clap.Args.t<t> = Clap.Args.make(
  command =>
    command
    ->Clap.Command.arg(Clap.Arg.make("verbose")->Clap.Arg.short("v")->Clap.Arg.action(Count))
    ->(command => Clap.Subcommand.augment(commandSubcommand, command)),
  matches =>
    Clap.Subcommand.fromMatchesOptional(commandSubcommand, matches)->Result.map(command => {
      verbose: Clap.Matches.getCount(matches, "verbose"),
      command,
    }),
)

let parser = Clap.Parser.fromArgs(Clap.Command.make("tool")->Clap.Command.version("0.1.0"), args)

let parse = argv => Clap.tryParseFrom(parser, Array.concat(["tool"], argv), ~env=Dict.make())

let rendered = argv => parse(argv)->Result.mapError(Clap.Error.render)

describe("decoding", () => {
  test("optional subcommand absent", () => {
    expect(parse(["-vv"]))->toEqual(Ok({verbose: 2, command: None}))
  })
  test("subcommand with flags, enum default and alias", () => {
    expect(parse(["push"]))->toEqual(
      Ok({verbose: 0, command: Some(Push({force: false, level: Info}))}),
    )
    expect(parse(["p", "--force", "--level", "debug"]))->toEqual(
      Ok({verbose: 0, command: Some(Push({force: true, level: Debug}))}),
    )
    expect(parse(["push", "--level=normal"]))->toEqual(
      Ok({verbose: 0, command: Some(Push({force: false, level: Info}))}),
    )
  })
  test("nested required subcommand", () => {
    expect(parse(["remote", "add", "origin"]))->toEqual(
      Ok({verbose: 0, command: Some(Remote(Add({name: "origin"})))}),
    )
    expect(parse(["remote", "show"]))->toEqual(Ok({verbose: 0, command: Some(Remote(Show))}))
  })
  test("an empty nested command line prints help to stderr", () => {
    expect(
      parse(["remote"])->Result.mapError(
        error => (
          Clap.Error.render(error),
          Clap.Error.usesStderr(error),
          Clap.Error.exitCode(error),
        ),
      ),
    )->toEqual(
      Error((
        "Usage: tool remote <COMMAND>\n\nCommands:\n  add   \n  show  \n  help  Print this message or the help of the given subcommand(s)\n\nOptions:\n  -h, --help  Print help\n",
        true,
        2,
      )),
    )
  })
  test("invalid enum value with suggestion", () => {
    expect(rendered(["push", "--level", "debgu"]))->toEqual(
      Error(
        "error: invalid value 'debgu' for '--level <LEVEL>'\n  [possible values: debug, info]\n\n  tip: a similar value exists: 'debug'\n\nFor more information, try '--help'.\n",
      ),
    )
  })
  test("help subcommand", () => {
    expect(rendered(["help", "remote", "add"]))->toEqual(
      Error(
        "Usage: tool remote add <NAME>\n\nArguments:\n  <NAME>  \n\nOptions:\n  -h, --help  Print help\n",
      ),
    )
  })
  test("version", () => {
    expect(rendered(["-V"]))->toEqual(Error("tool 0.1.0\n"))
    expect(rendered(["--version"]))->toEqual(Error("tool 0.1.0\n"))
  })
  test("parser command exposes the augmented definition", () => {
    expect(Clap.Parser.command(parser).subcommands->Array.map(command => command.name))->toEqual([
      "push",
      "remote",
      "status",
    ])
  })
  test("fromSubcommand requires a subcommand", () => {
    let required = Clap.Parser.fromSubcommand(Clap.Command.make("tool"), commandSubcommand)
    expect(
      Clap.tryParseFrom(required, ["tool"], ~env=Dict.make())
      ->Result.map(_ => ())
      ->Result.mapError(Clap.Error.exitCode),
    )->toEqual(Error(2))
  })
})

describe("standard library module types", () => {
  let parse = argv =>
    Clap.tryParseFrom(ModuleTypes.parser, Array.concat(["module-types"], argv), ~env=Dict.make())

  test("decode like the builtin types", () => {
    expect(
      parse([
        "--name",
        "Ann",
        "--ratio",
        "0.5",
        "-f",
        "--enabled",
        "false",
        "-vv",
        "--tag",
        "a",
        "--weight",
        "1.5",
        "a.txt",
      ]),
    )->toEqual(
      Ok(
        (
          {
            name: "Ann",
            count: 1,
            ratio: Some(0.5),
            force: true,
            enabled: false,
            verbose: 2,
            tag: ["a"],
            weight: Some([1.5]),
            files: ["a.txt"],
          }: ModuleTypes.t
        ),
      ),
    )
  })
  test("reject values the builtin parsers reject", () => {
    expect(
      parse(["--name", "Ann", "--enabled", "false", "--count", "many"])->Result.mapError(
        Clap.Error.render,
      ),
    )->toEqual(
      Error(
        "error: invalid value 'many' for '--count <COUNT>': invalid digit found in string\n\nFor more information, try '--help'.\n",
      ),
    )
  })
})
