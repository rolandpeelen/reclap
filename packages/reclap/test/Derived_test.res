/*** Replays the clap 4.6.7 golden fixtures through the CLIs derived with the `@clap.*`
attributes in `DerivedGreet` and `DerivedGit`.

Every case compares the exit code, stdout and stderr with clap's. Every case where clap
parsed a value also decodes the derived value and compares its serde JSON with clap's:
external tagging for enums (a unit variant is a string, a struct or newtype variant is
`{"Name": {...}}`), a `ValueEnum` is its variant name, `Option` is `null` when absent and
`Vec` is `[]` when absent. */

open Vitest

let string = (text: string) => JSON.String(text)
let int = (value: int) => JSON.Number(Int.toFloat(value))
let bool = (value: bool) => JSON.Boolean(value)
let option = (value: option<'value>, toJson: 'value => JSON.t) =>
  switch value {
  | Some(present) => toJson(present)
  | None => JSON.Null
  }
let array = (values: array<'value>, toJson: 'value => JSON.t) => JSON.Array(
  values->Array.map(toJson),
)
let object = (fields: array<(string, JSON.t)>) => JSON.Object(Dict.fromArray(fields))
let variant = (name, payload) => object([(name, payload)])

module GreetJson = {
  let color = (color: DerivedGreet.color) =>
    switch color {
    | Always => string("Always")
    | Never => string("Never")
    | Auto => string("Auto")
    }

  let t = (greet: DerivedGreet.t) =>
    object([
      ("name", string(greet.name)),
      ("count", int(greet.count)),
      ("verbose", int(greet.verbose)),
      ("greeting", option(greet.greeting, string)),
      ("tag", array(greet.tag, string)),
      ("lang", option(greet.lang, string)),
      ("color", color(greet.color)),
      ("offset", int(greet.offset)),
      ("secret", option(greet.secret, string)),
      ("shout", bool(greet.shout)),
    ])
}

let replayDerived = (fileName, parser: Clap.Parser.t<'value>, toJson: 'value => JSON.t) => {
  let programName = Clap.Parser.command(parser).name
  let parse = (argv, env) => Clap.tryParseFrom(parser, argv, ~env)
  FixtureReplay.replay(fileName, ~programName, parse)
  describe(`${fileName} parsed values`, () =>
    FixtureReplay.loadCases(fileName)->Array.forEach(fixtureCase =>
      switch fixtureCase.parsedValue {
      | None => ()
      | Some(expected) =>
        test(
          fixtureCase.name,
          () =>
            expect(
              parse(FixtureReplay.argvOf(fixtureCase, ~programName), fixtureCase.env)->Result.map(
                toJson,
              ),
            )->toEqual(Ok(expected)),
        )
      }
    )
  )
}

replayDerived("greet.json", DerivedGreet.parser, GreetJson.t)
