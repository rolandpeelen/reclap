/*** Value parsers, suggestions, error metadata and the command rendering functions. */

open Vitest

describe("value parsers", () => {
  test("int", () => {
    expect(Clap.ValueParser.parse(Clap.ValueParser.int, "-42"))->toEqual(Ok(-42))
    expect(Clap.ValueParser.parse(Clap.ValueParser.int, "+7"))->toEqual(Ok(7))
    expect(Clap.ValueParser.parse(Clap.ValueParser.int, "1.5"))->toEqual(
      Error("invalid digit found in string"),
    )
    expect(Clap.ValueParser.parse(Clap.ValueParser.int, ""))->toEqual(
      Error("cannot parse integer from empty string"),
    )
    expect(Clap.ValueParser.parse(Clap.ValueParser.int, "3000000000"))->toEqual(
      Error("3000000000 is not in -2147483648..=2147483647"),
    )
  })
  test("float", () => {
    expect(Clap.ValueParser.parse(Clap.ValueParser.float, "2e3"))->toEqual(Ok(2000.))
    expect(Clap.ValueParser.parse(Clap.ValueParser.float, "-0.5"))->toEqual(Ok(-0.5))
    expect(Clap.ValueParser.parse(Clap.ValueParser.float, "1x"))->toEqual(
      Error("invalid float literal"),
    )
    expect(Clap.ValueParser.format(Clap.ValueParser.float, 1.))->toBe("1")
  })
  test("bool lists its possible values", () => {
    expect(Clap.ValueParser.parse(Clap.ValueParser.bool, "true"))->toEqual(Ok(true))
    expect(Clap.ValueParser.bool.possibleValues->Array.map(value => value.name))->toEqual([
      "true",
      "false",
    ])
  })
  test("possible values", () => {
    let value = Clap.PossibleValue.make("never")->Clap.PossibleValue.alias("off")
    expect(Clap.PossibleValue.matches(value, "off"))->toBe(true)
    expect(Clap.PossibleValue.matches(value, "Never"))->toBe(false)
  })
})

describe("suggestions", () => {
  test("keeps candidates above the threshold, best last", () => {
    expect(ClapSuggest.didYouMean("sta", ["status", "stash", "st", "commit"]))->toEqual([
      "status",
      "stash",
      "st",
    ])
    expect(ClapSuggest.best("--forc", ["--force", "--name"]))->toEqual(Some("--force"))
    expect(ClapSuggest.best("zzz", ["force"]))->toEqual(None)
  })
})

let command =
  Clap.Command.make("prog")
  ->Clap.Command.about("Does things")
  ->Clap.Command.arg(Clap.Arg.make("name")->Clap.Arg.long("name")->Clap.Arg.required(true))
  ->Clap.Command.arg(Clap.Arg.make("force")->Clap.Arg.long("force")->Clap.Arg.action(SetTrue))
  ->Clap.Command.arg(
    Clap.Arg.make("mode")
    ->Clap.Arg.long("mode")
    ->Clap.Arg.valueParser(Clap.ValueParser.bool),
  )
  ->Clap.Command.arg(Clap.Arg.make("file")->Clap.Arg.valueName("FILE"))

let rendered = argv =>
  Clap.getMatchesFrom(command, Array.concat(["prog"], argv), ~env=Dict.make())
  ->Result.map(_ => ())
  ->Result.mapError(Clap.Error.render)

describe("errors", () => {
  test("argument used twice", () => {
    expect(rendered(["--name", "a", "--name", "b"]))->toEqual(
      Error(
        "error: the argument '--name <name>' cannot be used multiple times\n\nUsage: prog [OPTIONS] --name <name> [FILE]\n\nFor more information, try '--help'.\n",
      ),
    )
  })
  test("missing value lists possible values", () => {
    expect(rendered(["--name", "a", "--mode"]))->toEqual(
      Error(
        "error: a value is required for '--mode <mode>' but none was supplied\n  [possible values: true, false]\n\nFor more information, try '--help'.\n",
      ),
    )
  })
  test("value for a flag", () => {
    expect(rendered(["--force=yes"]))->toEqual(
      Error(
        "error: unexpected value 'yes' for '--force' found; no more were expected\n\nUsage: prog --name <name> --force [FILE]\n\nFor more information, try '--help'.\n",
      ),
    )
  })
  test("unknown argument with suggestion", () => {
    expect(rendered(["--forc"]))->toEqual(
      Error(
        "error: unexpected argument '--forc' found\n\n  tip: a similar argument exists: '--force'\n\nUsage: prog --name <name> --force [FILE]\n\nFor more information, try '--help'.\n",
      ),
    )
  })
  test("missing required argument", () => {
    expect(rendered([]))->toEqual(
      Error(
        "error: the following required arguments were not provided:\n  --name <name>\n\nUsage: prog --name <name> [FILE]\n\nFor more information, try '--help'.\n",
      ),
    )
  })
  test("exit codes and streams", () => {
    let help = Clap.Error.DisplayHelp({output: "help\n"})
    let unknown = Clap.Error.UnknownArgument({
      context: {path: ["prog"], usage: "prog"},
      argument: "--x",
      suggestion: None,
      tips: [],
    })
    let missingHelp = Clap.Error.DisplayHelpOnMissingArgumentOrSubcommand({output: "help\n"})
    expect([help, unknown, missingHelp]->Array.map(Clap.Error.exitCode))->toEqual([0, 2, 2])
    expect([help, unknown, missingHelp]->Array.map(Clap.Error.usesStderr))->toEqual([
      false,
      true,
      true,
    ])
  })
})

describe("command rendering", () => {
  test("usage, help and version", () => {
    expect(Clap.Command.renderUsage(command))->toBe("prog [OPTIONS] --name <name> [FILE]")
    expect(Clap.Command.renderHelp(command))->toBe(
      "Does things\n\nUsage: prog [OPTIONS] --name <name> [FILE]\n\nArguments:\n  [FILE]  \n\nOptions:\n      --name <name>  \n      --force        \n      --mode <mode>  [possible values: true, false]\n  -h, --help         Print help\n",
    )
    expect(Clap.Command.renderLongHelp(command))->toBe(Clap.Command.renderHelp(command))
    expect(Clap.Command.renderVersion(command->Clap.Command.version("2.1")))->toBe("prog 2.1\n")
  })
  test("build is idempotent and respects user-defined names", () => {
    let custom =
      Clap.Command.make("prog")->Clap.Command.arg(
        Clap.Arg.make("host")->Clap.Arg.short("h")->Clap.Arg.long("host"),
      )
    let built = Clap.Command.build(Clap.Command.build(custom))
    expect(built.args->Array.map(arg => (arg.id, arg.short)))->toEqual([
      ("host", Some("h")),
      ("help", None),
    ])
  })
})
