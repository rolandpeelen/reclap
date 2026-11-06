/*** Loads the clap 4.6.7 golden fixtures and replays them through a reclap CLI.

A CLI is replayed as a `parse` function from the full `argv`, program name included, to
the parse result. The test compares the exit code, stdout and stderr with what clap
printed. */

open Vitest

type fixtureCase = {
  name: string,
  argv: array<string>,
  env: Dict.t<string>,
  exitCode: int,
  stdout: string,
  stderr: string,
  /** The serde JSON of the value that clap parsed, or `None` when clap exited. */
  parsedValue: option<JSON.t>,
}

type outcome = {
  exitCode: int,
  stdout: string,
  stderr: string,
}

let decodeString = (json: JSON.t) =>
  switch json {
  | String(text) => Some(text)
  | Boolean(_) | Null | Number(_) | Object(_) | Array(_) => None
  }

let decodeStrings = (json: JSON.t) =>
  switch json {
  | Array(items) =>
    let strings = items->Array.filterMap(decodeString)
    strings->Array.length == items->Array.length ? Some(strings) : None
  | Boolean(_) | Null | Number(_) | Object(_) | String(_) => None
  }

let decodeStringDict = (json: JSON.t) =>
  switch json {
  | Object(fields) =>
    let entries =
      fields
      ->Dict.toArray
      ->Array.filterMap(((key, value)) => decodeString(value)->Option.map(text => (key, text)))
    entries->Array.length == fields->Dict.size ? Some(Dict.fromArray(entries)) : None
  | Boolean(_) | Null | Number(_) | Array(_) | String(_) => None
  }

let decodeInt = (json: JSON.t) =>
  switch json {
  | Number(number) => Some(Float.toInt(number))
  | Boolean(_) | Null | Object(_) | Array(_) | String(_) => None
  }

/* `parsed` is `null` when clap exited and `{"value": ..., "debug": ...}` otherwise. The
 outer option is the decoding result, the inner one the presence of a parsed value. */
let decodeParsedValue = (json: JSON.t) =>
  switch json {
  | Null => Some(None)
  | Object(fields) => fields->Dict.get("value")->Option.map(value => Some(value))
  | Boolean(_) | Number(_) | Array(_) | String(_) => None
  }

let decodeCase = (json: JSON.t) =>
  switch json {
  | Object(fields) =>
    let field = (key, decode) => fields->Dict.get(key)->Option.flatMap(decode)
    switch (
      field("name", decodeString),
      field("argv", decodeStrings),
      field("env", decodeStringDict),
      field("exitCode", decodeInt),
      field("stdout", decodeString),
      field("stderr", decodeString),
      field("parsed", decodeParsedValue),
    ) {
    | (
        Some(name),
        Some(argv),
        Some(env),
        Some(exitCode),
        Some(stdout),
        Some(stderr),
        Some(parsedValue),
      ) =>
      Some({name, argv, env, exitCode, stdout, stderr, parsedValue})
    | _ => None
    }
  | Boolean(_) | Null | Number(_) | Array(_) | String(_) => None
  }

/** Reads and decodes `test/fixtures/clap/<fileName>`. Throws on a malformed file. */
let loadCases = fileName => {
  let json = JSON.parseOrThrow(NodeFs.readFileUtf8(`test/fixtures/clap/${fileName}`))
  switch json {
  | Object(fields) =>
    switch fields->Dict.get("cases") {
    | Some(Array(cases)) =>
      cases->Array.map(caseJson =>
        switch decodeCase(caseJson) {
        | Some(fixtureCase) => fixtureCase
        | None => JsError.throwWithMessage(`malformed case in ${fileName}`)
        }
      )
    | Some(Boolean(_) | Null | Number(_) | Object(_) | String(_)) | None =>
      JsError.throwWithMessage(`no cases in ${fileName}`)
    }
  | Boolean(_) | Null | Number(_) | Array(_) | String(_) =>
    JsError.throwWithMessage(`${fileName} is not an object`)
  }
}

/** Returns the full `argv` of a case: the program name followed by the case's arguments. */
let argvOf = (fixtureCase: fixtureCase, ~programName) =>
  Array.concat([programName], fixtureCase.argv)

/** Returns what a CLI prints and its exit code for a parse result, as `Parser::parse` would. */
let outcomeOf = (result: result<'value, Clap.Error.t>) =>
  switch result {
  | Ok(_) => {exitCode: 0, stdout: "", stderr: ""}
  | Error(error) =>
    let output = Clap.Error.render(error)
    Clap.Error.usesStderr(error)
      ? {exitCode: Clap.Error.exitCode(error), stdout: "", stderr: output}
      : {exitCode: Clap.Error.exitCode(error), stdout: output, stderr: ""}
  }

/** Returns the exit code, stdout and stderr that clap produced for a case. */
let expectedOutcome = (fixtureCase: fixtureCase) => {
  exitCode: fixtureCase.exitCode,
  stdout: fixtureCase.stdout,
  stderr: fixtureCase.stderr,
}

/** Registers one test per case of `fileName` that compares the output of `parse` with clap's.

`parse` receives the full `argv` and the case's environment. */
let replay = (
  fileName,
  ~programName,
  parse: (array<string>, Dict.t<string>) => result<'value, Clap.Error.t>,
) =>
  describe(fileName, () =>
    loadCases(fileName)->Array.forEach(fixtureCase =>
      test(
        fixtureCase.name,
        () =>
          expect(outcomeOf(parse(argvOf(fixtureCase, ~programName), fixtureCase.env)))->toEqual(
            expectedOutcome(fixtureCase),
          ),
      )
    )
  )

/** Registers one test per case of `fileName` in which clap parsed successfully, comparing
`toJson` of the value that `parse` returns with the `value` that clap recorded. */
let replayParsedValues = (
  fileName,
  ~programName,
  parse: (array<string>, Dict.t<string>) => result<'value, Clap.Error.t>,
  toJson: 'value => JSON.t,
) =>
  describe(`${fileName} parsed values`, () =>
    loadCases(fileName)->Array.forEach(fixtureCase =>
      switch fixtureCase.parsedValue {
      | None => ()
      | Some(expected) =>
        test(
          fixtureCase.name,
          () =>
            expect(
              parse(argvOf(fixtureCase, ~programName), fixtureCase.env)->Result.map(toJson),
            )->toEqual(Ok(expected)),
        )
      }
    )
  )
