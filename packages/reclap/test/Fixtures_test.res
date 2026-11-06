/*** Replays the clap 4.6.7 golden fixtures through the builder-API definitions of the same
CLIs and compares the exit code, stdout and stderr. */

open Vitest

type fixtureCase = {
  name: string,
  argv: array<string>,
  env: Dict.t<string>,
  exitCode: int,
  stdout: string,
  stderr: string,
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
    ) {
    | (Some(name), Some(argv), Some(env), Some(exitCode), Some(stdout), Some(stderr)) =>
      Some({name, argv, env, exitCode, stdout, stderr})
    | _ => None
    }
  | Boolean(_) | Null | Number(_) | Array(_) | String(_) => None
  }

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

let run = (command: Clap.Command.t, fixtureCase) =>
  switch Clap.getMatchesFrom(
    command,
    Array.concat([command.name], fixtureCase.argv),
    ~env=fixtureCase.env,
  ) {
  | Ok(_) => {exitCode: 0, stdout: "", stderr: ""}
  | Error(error) =>
    let output = Clap.Error.render(error)
    Clap.Error.usesStderr(error)
      ? {exitCode: Clap.Error.exitCode(error), stdout: "", stderr: output}
      : {exitCode: Clap.Error.exitCode(error), stdout: output, stderr: ""}
  }

let replay = (fileName, command) =>
  describe(fileName, () =>
    loadCases(fileName)->Array.forEach(fixtureCase =>
      test(
        fixtureCase.name,
        () =>
          expect(run(command, fixtureCase))->toEqual({
            exitCode: fixtureCase.exitCode,
            stdout: fixtureCase.stdout,
            stderr: fixtureCase.stderr,
          }),
      )
    )
  )

replay("greet.json", GreetCli.command)
replay("git.json", GitCli.command)
