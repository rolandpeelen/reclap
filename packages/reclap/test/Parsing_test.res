/*** Tokenizing, fallbacks and typed reads, through the builder API. */

open Vitest

let command =
  Clap.Command.make("prog")
  ->Clap.Command.arg(Clap.Arg.make("name")->Clap.Arg.short("n")->Clap.Arg.long("name"))
  ->Clap.Command.arg(
    Clap.Arg.make("count")
    ->Clap.Arg.short("c")
    ->Clap.Arg.long("count")
    ->Clap.Arg.valueParser(Clap.ValueParser.int)
    ->Clap.Arg.defaultValue(Clap.ValueParser.int, 1)
    ->Clap.Arg.env("PROG_COUNT"),
  )
  ->Clap.Command.arg(Clap.Arg.make("verbose")->Clap.Arg.short("v")->Clap.Arg.action(Count))
  ->Clap.Command.arg(
    Clap.Arg.make("force")->Clap.Arg.short("f")->Clap.Arg.long("force")->Clap.Arg.action(SetTrue),
  )
  ->Clap.Command.arg(Clap.Arg.make("color")->Clap.Arg.long("no-color")->Clap.Arg.action(SetFalse))
  ->Clap.Command.arg(
    Clap.Arg.make("tag")
    ->Clap.Arg.short("t")
    ->Clap.Arg.long("tag")
    ->Clap.Arg.action(Append)
    ->Clap.Arg.alias("label"),
  )
  ->Clap.Command.arg(Clap.Arg.make("input")->Clap.Arg.valueName("INPUT"))
  ->Clap.Command.arg(Clap.Arg.make("rest")->Clap.Arg.valueName("REST")->Clap.Arg.action(Append))

let parse = (~env=Dict.make(), argv) =>
  switch Clap.getMatchesFrom(command, Array.concat(["prog"], argv), ~env) {
  | Ok(matches) => matches
  | Error(error) => JsError.throwWithMessage(Clap.Error.render(error))
  }

let one = (matches, id) =>
  switch Clap.Matches.getOne(matches, id, Clap.ValueParser.string) {
  | Ok(value) => value
  | Error(error) => JsError.throwWithMessage(Clap.Error.render(error))
  }

let many = (matches, id) =>
  switch Clap.Matches.getMany(matches, id, Clap.ValueParser.string) {
  | Ok(values) => values
  | Error(error) => JsError.throwWithMessage(Clap.Error.render(error))
  }

let countValue = matches =>
  switch Clap.Matches.getRequired(matches, "count", Clap.ValueParser.int) {
  | Ok(value) => value
  | Error(error) => JsError.throwWithMessage(Clap.Error.render(error))
  }

describe("tokenizing", () => {
  test("long forms", () => {
    expect(parse(["--name=Ann"])->one("name"))->toEqual(Some("Ann"))
    expect(parse(["--name", "Ann"])->one("name"))->toEqual(Some("Ann"))
    expect(parse(["--name="])->one("name"))->toEqual(Some(""))
  })
  test("short forms", () => {
    expect(parse(["-nAnn"])->one("name"))->toEqual(Some("Ann"))
    expect(parse(["-n", "Ann"])->one("name"))->toEqual(Some("Ann"))
    expect(parse(["-n=Ann"])->one("name"))->toEqual(Some("Ann"))
  })
  test("combined short flags", () => {
    let matches = parse(["-vfvnAnn"])
    expect(Clap.Matches.getCount(matches, "verbose"))->toBe(2)
    expect(Clap.Matches.getFlag(matches, "force"))->toBe(true)
    expect(matches->one("name"))->toEqual(Some("Ann"))
  })
  test("negative numbers need an equals sign", () => {
    expect(parse(["--count=-3"])->countValue)->toBe(-3)
    expect(parse(["-c-3"])->countValue)->toBe(-3)
  })
  test("double dash makes the rest positional", () => {
    let matches = parse(["--", "--force", "-v"])
    expect(matches->one("input"))->toEqual(Some("--force"))
    expect(matches->many("rest"))->toEqual(["-v"])
    expect(Clap.Matches.getFlag(matches, "force"))->toBe(false)
  })
  test("a single dash is a positional", () => {
    expect(parse(["-"])->one("input"))->toEqual(Some("-"))
  })
  test("a trailing append positional collects the rest", () => {
    let matches = parse(["a", "b", "--force", "c"])
    expect(matches->one("input"))->toEqual(Some("a"))
    expect(matches->many("rest"))->toEqual(["b", "c"])
  })
  test("append collects every occurrence, including aliases", () => {
    expect(parse(["-ta", "--tag", "b", "--label=c"])->many("tag"))->toEqual(["a", "b", "c"])
    expect(parse([])->many("tag"))->toEqual([])
    expect(Clap.Matches.getManyOptional(parse([]), "tag", Clap.ValueParser.string))->toEqual(
      Ok(None),
    )
  })
  test("flags read their defaults when absent", () => {
    let matches = parse([])
    expect(Clap.Matches.getFlag(matches, "force"))->toBe(false)
    expect(Clap.Matches.getFlag(matches, "color"))->toBe(true)
    expect(Clap.Matches.getFlag(parse(["--no-color"]), "color"))->toBe(false)
    expect(Clap.Matches.getCount(matches, "verbose"))->toBe(0)
  })
})

describe("fallbacks", () => {
  test("default value", () => {
    let matches = parse([])
    expect(countValue(matches))->toBe(1)
    expect(Clap.Matches.valueSource(matches, "count"))->toEqual(Some(Clap.Matches.DefaultValue))
  })
  test("environment beats default, command line beats environment", () => {
    let env = Dict.fromArray([("PROG_COUNT", "7")])
    let fromEnv = parse(~env, [])
    expect(countValue(fromEnv))->toBe(7)
    expect(Clap.Matches.valueSource(fromEnv, "count"))->toEqual(Some(Clap.Matches.EnvVariable))
    let fromArgs = parse(~env, ["-c", "3"])
    expect(countValue(fromArgs))->toBe(3)
    expect(Clap.Matches.valueSource(fromArgs, "count"))->toEqual(Some(Clap.Matches.CommandLine))
  })
  test("an invalid environment value is an error", () => {
    let result = Clap.getMatchesFrom(command, ["prog"], ~env=Dict.fromArray([("PROG_COUNT", "x")]))
    expect(result->Result.mapError(Clap.Error.render))->toEqual(
      Error(
        "error: invalid value 'x' for '--count <count>': invalid digit found in string\n\nFor more information, try '--help'.\n",
      ),
    )
  })
  test("absent arguments have no entry", () => {
    let matches = parse([])
    expect(Clap.Matches.contains(matches, "name"))->toBe(false)
    expect(Clap.Matches.valueSource(matches, "name"))->toEqual(None)
    expect(matches->one("name"))->toEqual(None)
  })
})
