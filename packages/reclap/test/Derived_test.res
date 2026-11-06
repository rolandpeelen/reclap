/*** Replays the clap 4.6.7 golden fixtures through the CLIs derived with the `@clap.*`
attributes in `DerivedGreet` and `DerivedGit`.

Every case compares the exit code, stdout and stderr with clap's. Every case where clap
parsed a value also decodes the derived value and compares its serde JSON with clap's:
external tagging for enums (a unit variant is a string, a struct or newtype variant is
`{"Name": {...}}`), a `ValueEnum` is its variant name, `Option` is `null` when absent and
`Vec` is `[]` when absent. */

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

module GitJson = {
  let globalOpts = (global: DerivedGit.globalOpts) =>
    object([("directory", option(global.directory, string)), ("quiet", bool(global.quiet))])

  let addArgs = (add: DerivedGit.addArgs) =>
    object([("dry_run", bool(add.dryRun)), ("paths", array(add.paths, string))])

  let remoteCommands = (command: DerivedGit.remoteCommands) =>
    switch command {
    | Add({name, url}) => variant("Add", object([("name", string(name)), ("url", string(url))]))
    | Remove({name}) => variant("Remove", object([("name", string(name))]))
    }

  let stashCommands = (command: DerivedGit.stashCommands) =>
    switch command {
    | Push({message}) => variant("Push", object([("message", option(message, string))]))
    | Pop({index}) => variant("Pop", object([("index", bool(index))]))
    }

  let commands = (command: DerivedGit.commands) =>
    switch command {
    | Clone({remote, directory, depth, branch}) =>
      variant(
        "Clone",
        object([
          ("remote", string(remote)),
          ("directory", option(directory, string)),
          ("depth", option(depth, int)),
          ("branch", option(branch, string)),
        ]),
      )
    | Add(add) => variant("Add", addArgs(add))
    | Status => string("Status")
    | Commit({message, all}) =>
      variant("Commit", object([("message", string(message)), ("all", bool(all))]))
    | Remote({verbose, command}) =>
      variant(
        "Remote",
        object([("verbose", bool(verbose)), ("command", option(command, remoteCommands))]),
      )
    | Stash(stash) => variant("Stash", stashCommands(stash))
    | Gc => string("Gc")
    | Rm({files}) => variant("Rm", object([("files", array(files, string))]))
    }

  let t = (git: DerivedGit.t) =>
    object([("global", globalOpts(git.global)), ("command", commands(git.command))])
}

let replayDerived = (fileName, parser: Clap.Parser.t<'value>, toJson: 'value => JSON.t) => {
  let programName = Clap.Parser.command(parser).name
  let parse = (argv, env) => Clap.tryParseFrom(parser, argv, ~env)
  FixtureReplay.replay(fileName, ~programName, parse)
  FixtureReplay.replayParsedValues(fileName, ~programName, parse, toJson)
}

replayDerived("greet.json", DerivedGreet.parser, GreetJson.t)
replayDerived("git.json", DerivedGit.parser, GitJson.t)
