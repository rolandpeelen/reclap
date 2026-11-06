# reclap

[![npm](https://img.shields.io/npm/v/@rolandpeelen/reclap)](https://www.npmjs.com/package/@rolandpeelen/reclap)
[![CI](https://github.com/rolandpeelen/reclap/actions/workflows/ci.yml/badge.svg)](https://github.com/rolandpeelen/reclap/actions/workflows/ci.yml)
[![license](https://img.shields.io/npm/l/@rolandpeelen/reclap)](https://github.com/rolandpeelen/reclap/blob/master/LICENSE)

Derive command-line parsers from ReScript types, in the style of Rust's [clap](https://docs.rs/clap/latest/clap/_derive/index.html).

Write the CLI as records and variants. A PPX turns the attributes and doc comments on those types into a parser, so the value you match on is the type you wrote, and `-h` / `--help` / errors stay in clap's format. Help text, usage lines and error messages match clap 4 byte for byte; the test suite replays 178 recorded clap 4.6.7 runs. Reach for it on a ReScript 12 program when you want that derive style. The builder API assembles the same kind of parser from function calls.

## Installation

```sh
npm install @rolandpeelen/reclap
```

Add the runtime and the PPX to `rescript.json`:

```json
{
  "dependencies": ["@rolandpeelen/reclap"],
  "ppx-flags": ["@rolandpeelen/reclap/bin/ppx"]
}
```

ReScript 12 and Node.js 20 or newer. The package ships a prebuilt PPX for Linux (x64 and arm64), macOS (x64 and arm64) and Windows (x64), so installing it is the whole setup. Its install script puts the binary for your platform at `bin/ppx`. On Linux and macOS, `bin/ppx` is also a launcher that finds that binary when the package manager skips install scripts. On another platform, build the PPX from source with OCaml ≥ 5.1 and dune:

```sh
cd node_modules/@rolandpeelen/reclap && dune build
```

## Quick start

```rescript
/** Simple program to greet a person */
@clap.parser @command({name: "greet", version: "1.0.0"})
type t = {
  /** Name of the person to greet */
  @arg({short, long}) name: string,
  /** Number of times to greet */
  @arg({short, long, default: 1}) count: int,
}

let args = Clap.parse(parser)

for _ in 1 to args.count {
  Console.log(`Hello ${args.name}!`)
}
```

`Clap.parse(parser)` reads `process.argv`. The first element is the program name and is ignored, as in clap; the name in the usage line is `greet` from `@command`. `--help` and `--version` print to stdout and exit 0. Any other error prints to stderr and exits 2.

The same program is `packages/reclap/examples/GreetExample.res`. From `packages/reclap`, after `npx rescript build`:

```
$ node examples/GreetExample.res.mjs --help
Simple program to greet a person

Usage: greet [OPTIONS] --name <NAME>

Options:
  -n, --name <NAME>    Name of the person to greet
  -c, --count <COUNT>  Number of times to greet [default: 1]
  -h, --help           Print help
  -V, --version        Print version

$ node examples/GreetExample.res.mjs --name Ann -c 2
Hello Ann!
Hello Ann!

$ node examples/GreetExample.res.mjs --nme Ann
error: unexpected argument '--nme' found

  tip: a similar argument exists: '--name'

Usage: greet --name <NAME>

For more information, try '--help'.
```

Doc comments become help. The first paragraph, with one trailing period removed, is the short text. A further paragraph is included in `--help`. A punned key means "on, with the derived default": `@arg({short, long})` on `name` is `-n, --name`.

## Examples

`packages/reclap/examples/` has a program for each section below. Clone the repository and, from `packages/reclap`, run `npx rescript build`, then `node examples/<Name>.res.mjs`.

### Flags, positionals, environment variables

`CopyExample.res` copies nothing. It prints the plan clap parsed: a flag, a counter, a required option that can come from the environment, a visible alias, and positionals.

```rescript
/** Copy files into a directory */
@clap.parser @command({name: "copy", version: "0.2.0"})
type t = {
  /** Overwrite files that already exist */
  @arg({short, long}) force: bool,
  /** Print the plan and do not write */
  @arg({short: "n", long}) dryRun: bool,
  /** Directory to copy into */
  @arg({short, long, visibleAlias: "dest", env: "COPY_DEST"}) destination: string,
  /** Print each path. Repeat for more detail */
  @arg({short, action: Count}) verbose: int,
  /** File to copy */
  source: string,
  /** Further files to copy */
  more: array<string>,
}

let args = Clap.parse(parser)
let files = Array.concat([args.source], args.more)

let action = if args.dryRun {
  "would copy"
} else if args.force {
  "copy (overwrite)"
} else {
  "copy"
}

if args.verbose == 0 {
  Console.log(`${action} ${Int.toString(files->Array.length)} file(s) -> ${args.destination}`)
} else {
  files->Array.forEach(file => Console.log(`${action} ${file} -> ${args.destination}`))
  if args.verbose > 1 {
    Console.log(`${Int.toString(files->Array.length)} file(s)`)
  }
}
```

A field with no `short` or `long` is positional. `source: string` is required; `more: array<string>` is zero or more. `bool` is a flag. `action: Count` on an `int` counts occurrences (`-vv`). `env: "COPY_DEST"` supplies the value when the flag is absent. `visibleAlias: "dest"` is listed in help; a plain `alias` would parse and stay hidden.

```
$ node examples/CopyExample.res.mjs --help
Copy files into a directory

Usage: copy [OPTIONS] --destination <DESTINATION> <SOURCE> [MORE]...

Arguments:
  <SOURCE>   File to copy
  [MORE]...  Further files to copy

Options:
  -f, --force                      Overwrite files that already exist
  -n, --dry-run                    Print the plan and do not write
  -d, --destination <DESTINATION>  Directory to copy into [env: COPY_DEST=] [alias: --dest]
  -v...                            Print each path. Repeat for more detail
  -h, --help                       Print help
  -V, --version                    Print version

$ node examples/CopyExample.res.mjs -n -vv src/a.txt src/b.txt --dest out
would copy src/a.txt -> out
would copy src/b.txt -> out
2 file(s)

$ COPY_DEST=out node examples/CopyExample.res.mjs src/a.txt
copy 1 file(s) -> out
```

`dryRun` would have taken `-d` from its long name `dry-run`, which is already `destination`'s short flag, so the short name is set explicitly to `-n`.

### Value enums and custom values

`ServeExample.res` checks a port and a log level, then prints the settings. `--no-color` is a `SetFalse` flag: the field is `true` until the flag appears.

```rescript
module Level = {
  @clap.valueEnum
  type t =
    /** Only errors */
    | Error
    /** Normal output */
    | @value({alias: "normal"}) Info
    /** Everything */
    | Debug
}

type port = Port(int)

let portValueParser = Clap.ValueParser.make(
  text =>
    switch Int.fromString(text) {
    | Some(number) if number > 0 && number < 65536 => Ok(Port(number))
    | Some(_) | None => Error("not a port number")
    },
  (Port(number)) => Int.toString(number),
)

/** Serve files from a directory */
@clap.parser @command({name: "serve", version: "0.4.0"})
type t = {
  /** Directory to serve */
  @arg({long, default: "."}) root: string,
  /** Port to listen on */
  @arg({short, long, env, default: Port(8080)}) port: port,
  /** How much to print */
  @arg({long, default: Level.Info}) level: Level.t,
  /** Response header, as `Name: value`. Repeat the flag to set more than one */
  @arg({short: "H", long}) header: option<array<string>>,
  /** Colour log output */
  @arg({long: "no-color", action: SetFalse}) color: bool,
}
```

A `@clap.valueEnum` named `t` inside `Level` generates `Level.valueParser`. Any other type uses the value you write under the generated name: `port` reads `portValueParser`. `format` has to round-trip with `parse`, because a `default` is stored as text and parsed again. A punned `env` is the field name in `SCREAMING_SNAKE_CASE`, so `port` reads `PORT`. `option<array<string>>` is `None` when the flag is absent and the accumulated values when it is present. `@value({alias: "normal"})` accepts the alias and leaves it out of the possible-value list. `--help` prints each value's doc comment; `-h` keeps the list on one line.

```
$ node examples/ServeExample.res.mjs -h
Serve files from a directory

Usage: serve [OPTIONS]

Options:
      --root <ROOT>      Directory to serve [default: .]
  -p, --port <PORT>      Port to listen on [env: PORT=] [default: 8080]
      --level <LEVEL>    How much to print [default: info] [possible values: error, info, debug]
  -H, --header <HEADER>  Response header, as `Name: value`. Repeat the flag to set more than one
      --no-color         Colour log output
  -h, --help             Print help (see more with '--help')
  -V, --version          Print version

$ node examples/ServeExample.res.mjs --root ./public -p 3000 --level debug
serve ./public on :3000 (debug, color)

$ PORT=3000 node examples/ServeExample.res.mjs --no-color -H "Cache-Control: no-store"
serve . on :3000 (info, plain) [Cache-Control: no-store]

$ node examples/ServeExample.res.mjs --level debgu
error: invalid value 'debgu' for '--level <LEVEL>'
  [possible values: error, info, debug]

  tip: a similar value exists: 'debug'

For more information, try '--help'.
```

With `PORT` set, the help line reads `[env: PORT=3000]`.

### Shared options

`@command(flatten)` inlines an `@clap.args` record. `JobExample.res` uses that for a counter and a config path, and a second doc-comment paragraph for the text that only `--help` shows.

```rescript
// Inlined into the parser below with @command(flatten).
@clap.args
type common = {
  /** Print more about what happens */
  @arg({short, action: Count}) verbose: int,
  /** Config file to read */
  @arg({long, env: "JOB_CONFIG"}) config: option<string>,
}

/** Run one job to completion

The job stops when it finishes or when `--timeout` elapses. */
@clap.parser @command({name: "job", version: "0.3.0"})
type t = {
  @command(flatten) common: common,
  /** Seconds to wait before stopping.

  Zero waits forever. */
  @arg({long, default: 30}) timeout: int,
  /** Name of the job to run */
  name: string,
}
```

```
$ node examples/JobExample.res.mjs --help
Run one job to completion

The job stops when it finishes or when `--timeout` elapses.

Usage: job [OPTIONS] <NAME>

Arguments:
  <NAME>
          Name of the job to run

Options:
  -v...
          Print more about what happens

      --config <CONFIG>
          Config file to read
          
          [env: JOB_CONFIG=]

      --timeout <TIMEOUT>
          Seconds to wait before stopping.
          
          Zero waits forever.
          
          [default: 30]

  -h, --help
          Print help (see a summary with '-h')

  -V, --version
          Print version

$ node examples/JobExample.res.mjs nightly --timeout 0 -vv
job nightly timeout=0 verbose=2

$ JOB_CONFIG=job.toml node examples/JobExample.res.mjs migrate
job migrate timeout=30 verbose=0 config=job.toml
```

The parsed `common` field is the flattened record: `args.common.verbose`, `args.common.config`.

### Subcommands

A `@clap.subcommand` variant is the command list. A constructor can take no payload, an inline record, one `@clap.args` type, or, with `@command(subcommand)`, a nested `@clap.subcommand` (`T` for required, `option<T>` for optional). `GitExample.res` is a small fictional git. `commit`'s `ci` is a visible alias; `status`'s `st` and `remote remove`'s `rm` are hidden aliases, so they parse and stay out of help.

```rescript
@clap.args
type addArgs = {
  /** Don't actually add the files */
  @arg({short: "n", long}) dryRun: bool,
  /** Files to add content from */
  paths: array<string>,
}

@clap.subcommand
type remote =
  /** Add a remote named NAME for the repository at URL */
  | Add({
      /** Name of the remote */
      name: string,
      /** URL of the remote */
      url: string,
    })
  /** Remove the remote named NAME */
  | @command({alias: "rm"})
  Remove({
      /** Name of the remote */
      name: string,
    })

@clap.valueEnum
type color =
  /** Always colour the output */
  | Always
  /** Never colour the output */
  | @value({alias: "off"}) Never
  /** Colour the output when stdout is a terminal */
  | Auto

@clap.subcommand
type command =
  /** Clone a repository into a new directory */
  | Clone({
      /** The repository to clone from */
      remote: string,
      /** Create a shallow clone with this many commits */
      @arg(long) depth: option<int>,
    })
  /** Add file contents to the index */
  | Add(addArgs)
  /** Show the working tree status */
  | @command({alias: "st"}) Status
  /** Record changes to the repository */
  | @command({visibleAlias: "ci"})
  Commit({
      /** Use the given message as the commit message */
      @arg({short, long}) message: string,
      /** Stage all modified files first */
      @arg({short, long}) all: bool,
    })
  /** Manage the set of tracked repositories */
  | @command(subcommand) Remote(option<remote>)

/** A fictional version control system */
@clap.parser @command({name: "git", version: "2.0.0"})
type t = {
  /** Suppress output */
  @arg({short, long}) quiet: bool,
  /** When to colour the output */
  @arg({long, default: Auto}) color: color,
  @command(subcommand) command: command,
}
```

`Add(addArgs)` wraps one args record, the same shape as a newtype variant in clap. The file then switches on `args.command` and prints one line. Short flags combine.

```
$ node examples/GitExample.res.mjs -h
A fictional version control system

Usage: git [OPTIONS] <COMMAND>

Commands:
  clone   Clone a repository into a new directory
  add     Add file contents to the index
  status  Show the working tree status
  commit  Record changes to the repository [alias: ci]
  remote  Manage the set of tracked repositories
  help    Print this message or the help of the given subcommand(s)

Options:
  -q, --quiet          Suppress output
      --color <COLOR>  When to colour the output [default: auto] [possible values: always, never, auto]
  -h, --help           Print help (see more with '--help')
  -V, --version        Print version

$ node examples/GitExample.res.mjs add -n a.txt b.txt
add a.txt b.txt (dry run)

$ node examples/GitExample.res.mjs ci -am "ship it"
commit -a: ship it

$ node examples/GitExample.res.mjs remote add origin https://example.com/repo
add remote origin -> https://example.com/repo

$ node examples/GitExample.res.mjs remote rm origin
remove remote origin

$ node examples/GitExample.res.mjs comit
error: unrecognized subcommand 'comit'

  tip: a similar subcommand exists: 'commit'

Usage: git [OPTIONS] <COMMAND>

For more information, try '--help'.
```

An empty command line prints help to stderr and exits 2, because `command` is required. `remote` with no nested command is `Remote(None)`.

### Returning a result

`Clap.parse` prints and exits. Tests and embedded parsers want the `result` instead. `TryParseExample.res` runs three argv arrays. Pass `~env=Dict.make()` so the process environment cannot fill in arguments.

```rescript
/** Simple program to greet a person */
@clap.parser @command({name: "greet", version: "1.0.0"})
type t = {
  /** Name of the person to greet */
  @arg({short, long}) name: string,
  /** Number of times to greet */
  @arg({short, long, default: 1}) count: int,
}

let show = argv =>
  switch Clap.tryParseFrom(parser, argv, ~env=Dict.make()) {
  | Ok(args) => Console.log(`Ok: ${args.name} x${Int.toString(args.count)}`)
  | Error(error) =>
    Console.log(`exit ${Int.toString(Clap.Error.exitCode(error))}`)
    Console.log(Clap.Error.render(error)->String.trimEnd)
  }

show(["greet", "--name", "Ann", "-c", "2"])
show(["greet", "--nme", "Ann"])
show(["greet", "--help"])
```

```
$ node examples/TryParseExample.res.mjs
Ok: Ann x2
exit 2
error: unexpected argument '--nme' found

  tip: a similar argument exists: '--name'

Usage: greet --name <NAME>

For more information, try '--help'.
exit 0
Simple program to greet a person

Usage: greet [OPTIONS] --name <NAME>

Options:
  -n, --name <NAME>    Name of the person to greet
  -c, --count <COUNT>  Number of times to greet [default: 1]
  -h, --help           Print help
  -V, --version        Print version
```

`Clap.tryParse(parser)` is the same call against `process.argv`. `Clap.Error.exitCode` is 0 for help and version and 2 otherwise. `Clap.Error.usesStderr` is false for those two. `Clap.Error.exit` prints and exits.

### Without the PPX

`BuilderExample.res` builds the greet parser through `Clap.Command` and `Clap.Args`. The PPX generates this shape of code; writing it out is the whole builder API.

```rescript
type t = {
  name: string,
  count: int,
}

let args: Clap.Args.t<t> = Clap.Args.make(
  command =>
    command
    ->Clap.Command.arg(
      Clap.Arg.make("name")
      ->Clap.Arg.valueName("NAME")
      ->Clap.Arg.required(true)
      ->Clap.Arg.short("n")
      ->Clap.Arg.long("name")
      ->Clap.Arg.help("Name of the person to greet"),
    )
    ->Clap.Command.arg(
      Clap.Arg.make("count")
      ->Clap.Arg.valueName("COUNT")
      ->Clap.Arg.valueParser(Clap.ValueParser.int)
      ->Clap.Arg.defaultValue(Clap.ValueParser.int, 1)
      ->Clap.Arg.short("c")
      ->Clap.Arg.long("count")
      ->Clap.Arg.help("Number of times to greet"),
    ),
  matches =>
    switch Clap.Matches.getRequired(matches, "name", Clap.ValueParser.string) {
    | Error(error) => Error(error)
    | Ok(name) =>
      switch Clap.Matches.getRequired(matches, "count", Clap.ValueParser.int) {
      | Error(error) => Error(error)
      | Ok(count) => Ok({name, count})
      }
    },
)

let parser = Clap.Parser.fromArgs(
  Clap.Command.make("hello")
  ->Clap.Command.version("1.0.0")
  ->Clap.Command.about("Simple program to greet a person"),
  args,
)

let parsed = Clap.parse(parser)
```

```
$ node examples/BuilderExample.res.mjs --name Ann -c 2
Hello Ann!
Hello Ann!
```

`Clap.getMatchesFrom(command, argv)` parses without decoding. `Clap.Parser.fromSubcommand` is the builder form of a `@clap.parser` variant: a subcommand is required. `Clap.Parser.command` returns the command definition, for help or for adding another argument by hand.

## API

`@clap.parser` on a record or variant generates the values below. In a `.resi`, the same attributes generate the matching `let` declarations. A parser in an interface needs the full type.

| Attribute on the type | Record                          | Variant                              |
| --------------------- | ------------------------------- | ------------------------------------ |
| `@clap.parser`        | `args` and `parser`             | `subcommand` and `parser`            |
| `@clap.args`          | `args: Clap.Args.t<t>`          | error                                |
| `@clap.subcommand`    | error                           | `subcommand: Clap.Subcommand.t<t>`   |
| `@clap.valueEnum`     | error                           | `valueParser: Clap.ValueParser.t<t>` |

A type named `t` gets `args`, `subcommand`, `valueParser` and `parser`. A type named `foo` gets `fooArgs`, `fooSubcommand`, `fooValueParser` and `fooParser`. A qualified type keeps its module path: `Level.t` → `Level.valueParser`, `Git.remote` → `Git.remoteSubcommand`. The PPX refers to other types by this rule, so a type used as a field is declared first (or in the same `type ... and ...` group), and a type from another module is qualified.

| Call | What it does |
| ---- | ------------ |
| `Clap.parse(parser)` | Parse `process.argv`, or print and exit |
| `Clap.tryParse(parser)` | Parse `process.argv` and return `result` |
| `Clap.tryParseFrom(parser, argv, ~env=?)` | Parse `argv`. `~env` defaults to `process.env` |
| `Clap.getMatchesFrom(command, argv, ~env=?)` | Parse without decoding into the typed value |

On an error, `Clap.Error.render` is the clap message, `exitCode` is 0 or 2, and `usesStderr` chooses the stream.

### Fields

| Field type          | Becomes                                      |
| ------------------- | -------------------------------------------- |
| `bool`              | a flag (`--force`); needs `short` or `long`  |
| `int` with `action: Count` | a counter (`-vvv`)                    |
| `T`                 | required, unless it has a `default`          |
| `option<T>`         | optional                                     |
| `array<T>`          | zero or more occurrences                     |
| `option<array<T>>`  | like `array<T>`, but `None` when absent      |

`T` is `string`, `int`, `float` or `bool` (also `String.t`, `Int.t`, `Float.t`, `Bool.t`), a `@clap.valueEnum` type, or any type with a value parser under the name above. `Option.t` and `Array.t` are not recognised: write `option<T>` and `array<T>`. Optional record fields (`name?: string`), `option<option<T>>` and other nesting are rejected.

`Bool.t` is a flag, and `Int.t` can count. The PPX goes by the type name, so a module of your own named `Int`, `String`, `Float` or `Bool` with a type `t` is taken for the standard one.

### `@arg`

`@arg(long)` and `@arg({long})` are the same. `default`, `valueName`, `valueParser` and `required` are errors on flags and counters.

| Key | Meaning |
| --- | --- |
| `short` / `short: "n"` | short name; punned: first character of the long name |
| `long` / `long: "name"` | long name; punned: the cased field name |
| `env` / `env: "NAME"` | environment variable; punned: `SCREAMING_SNAKE_CASE` field name |
| `default: expr` | typed default (clap's `default_value_t`); an array for `array<T>` |
| `help`, `longHelp` | override the doc comment |
| `valueName: "FILE"` | placeholder; default is `id` when set, otherwise the `SCREAMING_SNAKE_CASE` field name |
| `id: "x"` | argument id; default is the field name. An explicit id is also the default value name, verbatim |
| `alias`, `aliases` | hidden long aliases |
| `visibleAlias`, `visibleAliases` | long aliases shown in help |
| `action` | `Set`, `Append`, `SetTrue`, `SetFalse`, `Count` (`Count` needs `int`) |
| `required: bool` | overrides the inferred requiredness |
| `valueParser: expr` | a `Clap.ValueParser.t<T>` for the element type |
| `hide` | hide from help |
| `skip: expr` | no argument; the field is always `expr` |

`SetFalse` is a flag that reads `false` when present and `true` when absent. `action: Set` on a `bool` reads the values `true` and `false`.

Names are unique inside one record. Two arguments cannot share an id, a long name (aliases included) or a short name, and the automatic `-h` / `--help` (and `-V` / `--version` when the parser sets a version) count. A flattened record is checked on its own.

### `@command`

On a `@clap.parser` type: `name` (default: kebab-case of the type, or of the module when the type is `t`), `version`, `about`, `longAbout`, `author`, `renameAll`, `renameAllEnv`. `author` is stored on the command. Help does not print it.

On `@clap.args` and `@clap.subcommand`: `renameAll`, `renameAllEnv`.

On a record field: `subcommand` (one `T` or `option<T>` whose type is `@clap.subcommand`) or `flatten` (a `@clap.args` type).

On a subcommand constructor: `name`, `about`, `longAbout`, `alias`, `aliases`, `visibleAlias`, `visibleAliases`, `hide`, and `subcommand` for a nested command list.

### `@value`

On a `@clap.valueEnum` constructor: `name`, `help`, `alias`, `aliases`, `hide`, `skip`. On the type: `renameAll`. Constructors have no payload. A skipped value has no name, so it cannot be a `default`. The PPX can only reject that default when the value enum is declared in the same file.

### Names

`renameAll` and `renameAllEnv` accept `"kebab-case"` (the default for names), `"snake_case"`, `"camelCase"`, `"PascalCase"`, `"SCREAMING_SNAKE_CASE"`, `"lower"`, `"UPPER"` and `"verbatim"`. A punned `env` uses `SCREAMING_SNAKE_CASE` unless `renameAllEnv` says otherwise. A bare `long`, `short` or `env` is derived from the field name, including when `id` is set.

## Configuration

reclap has no config file.

- `rescript.json` holds the dependency and `ppx-flags`, as in [Installation](#installation).
- `@command` on the parser type sets the usage name, version, about text and [naming](#names).
- Arguments with `env` read `process.env`. `Clap.tryParseFrom` and `Clap.getMatchesFrom` take `~env` to pass another dictionary. Help shows the current value as `[env: NAME=value]`.

`Clap.parse` and `Clap.tryParse` always read `process.argv` and `process.env`.

## How it works

For each annotated type the PPX generates two ordinary functions against the builder API:

1. **augment** adds one `Clap.Arg.t` per field to a `Clap.Command.t`, with the behaviour inferred from the field type and the attributes.
2. **fromMatches** reads each field out of the untyped `Clap.Matches.t` and builds the typed value.

`Clap.parse` builds the command, parses, and decodes. The generated code is plain ReScript; `docs/design.md` shows it. `docs/clap-output-format.md` is the clap 4 help, usage and error format the renderer follows.

## Not supported yet

Argument groups, conflicts and requirements between arguments, `global` arguments, `Option<Option<T>>`, `num_args`, external subcommands, colours, and wrapping help to the terminal width.

## Agent skill

reclap ships an [agent skill](https://agentskills.io) that teaches coding agents the attributes, field types and error messages:

```sh
npx skills add rolandpeelen/reclap
```

The npm package contains it too, at `node_modules/@rolandpeelen/reclap/skills/reclap`, so `npx skills experimental_sync` picks it up from the dependency.

## Development

```sh
npm install
cd packages/reclap
eval $(opam env)        # OCaml 5.x with dune
npm test                # dune build, rescript build, vitest, PPX tests
```

| Path                                   | What                                                    |
| -------------------------------------- | ------------------------------------------------------- |
| `packages/reclap/src`                  | runtime: builder, parser, help and error rendering      |
| `packages/reclap/ppx`                  | the PPX (OCaml, no ppxlib; see below)                   |
| `packages/reclap/examples`             | the runnable programs in this README                   |
| `packages/reclap/test`                 | Vitest suites; `fixtures/clap` holds real clap output   |
| `packages/reclap/test/ppx`             | PPX fixtures and `-dsource` snapshots                   |
| `packages/reclap/ppx/test/errors`      | inputs the PPX must reject, with the expected message   |
| `packages/reclap/test/readme`          | README and skill snippets, compiled so they cannot drift |
| `reference/clap-fixtures`              | the Rust CLIs that produce the golden fixtures          |
| `docs/design.md`                       | attribute surface and generated code                    |
| `docs/clap-output-format.md`           | clap 4's help, usage and error format, as implemented   |
| `packages/reclap/skills/reclap`        | the agent skill for users of reclap                     |
| `agents/skills`                        | skills for developing this repository; not published    |

ReScript 12 hands PPXes a frozen OCaml 4.06-shaped AST (`Parsetree0`) that ppxlib no longer reads, so the PPX carries a verbatim copy of that AST (`ppx/lib/parsetree0.ml`) and reads and writes the compiler's marshalled files directly. After changing the PPX, delete `packages/reclap/lib` before rebuilding: `rescript build` does not notice a new `ppx.exe`.

## Releasing

`.github/workflows/release.yml` builds the PPX on every supported platform and publishes the npm package.

- **Release:** push a tag `vX.Y.Z`. The workflow publishes version `X.Y.Z` (the tag sets the version; `package.json` does not need a bump) under the `latest` dist-tag and creates a GitHub Release with the binaries.
- **Dry run:** run the workflow by hand with `dry_run` checked (the default), from the Actions tab or with `gh workflow run release.yml --ref master -f dry_run=true`. It builds and checks every binary, packs the package and uploads the tarball as the `npm-package` artifact, without publishing. `ref` selects another branch, tag or commit, and `npm_tag` another dist-tag for a real run.

npm authenticates the workflow with trusted publishing: on npmjs.com, under the package's settings, add a trusted publisher for the GitHub repository `rolandpeelen/reclap` and the workflow `release.yml`. A first version has to exist before the package has settings, so publish it with the `NPM_TOKEN` fallback: a repository secret holding a granular npm access token with publish rights. npm only attaches provenance to packages from public repositories, so the workflow passes `--provenance` once the repository is public.
