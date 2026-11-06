# reclap

Derive command line parsers from ReScript types, the way Rust's
[clap](https://docs.rs/clap/latest/clap/_derive/index.html) derives them from
Rust types. Help text, usage lines and error messages match clap 4 byte for
byte; the test suite replays 178 recorded clap 4.6.7 runs.

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

```
$ node Greet.res.mjs --help
Simple program to greet a person

Usage: greet [OPTIONS] --name <NAME>

Options:
  -n, --name <NAME>    Name of the person to greet
  -c, --count <COUNT>  Number of times to greet [default: 1]
  -h, --help           Print help
  -V, --version        Print version

$ node Greet.res.mjs --nme Ann
error: unexpected argument '--nme' found

  tip: a similar argument exists: '--name'

Usage: greet --name <NAME>

For more information, try '--help'.
```

## Setup

```sh
npm install reclap
```

Add the runtime and the PPX to `rescript.json`:

```json
{
  "dependencies": ["reclap"],
  "ppx-flags": ["reclap/bin/ppx"]
}
```

There is no build step: reclap needs ReScript 12, and the package ships a
prebuilt PPX for Linux (x64 and arm64), macOS (x64 and arm64) and Windows
(x64). Its install script puts the one for your platform at `bin/ppx`; on Linux
and macOS, `bin/ppx` is also a launcher that finds the binary when the package
manager skips install scripts. On another platform, build the PPX from source
with OCaml ≥ 5.1 and dune: `cd node_modules/reclap && dune build`.

## How it works

Like `clap_derive`, the PPX does not parse anything itself. For each annotated
type it generates two ordinary functions against the runtime's builder API:

1. **augment** adds one `Clap.Arg.t` per field to a `Clap.Command.t`, with the
   behaviour inferred from the field type and the attributes;
2. **fromMatches** reads each field back out of the untyped `Clap.Matches.t`
   and builds the typed value.

`Clap.parse(parser)` builds the command, parses `process.argv`, decodes, and on
error prints the message and exits: code 0 for `--help` and `--version`, 2 for
everything else. `Clap.tryParseFrom(parser, argv)` returns a `result` instead.
The generated code is plain ReScript; `docs/design.md` shows it.

## Attributes

| Rust                                 | ReScript                                     | Generates                           |
| ------------------------------------ | -------------------------------------------- | ----------------------------------- |
| `#[derive(Parser)]` struct / enum    | `@clap.parser` on a record / variant          | `parser` (and `args` / `subcommand`) |
| `#[derive(Args)]`                    | `@clap.args` on a record                      | `args: Clap.Args.t<t>`              |
| `#[derive(Subcommand)]`              | `@clap.subcommand` on a variant               | `subcommand: Clap.Subcommand.t<t>`  |
| `#[derive(ValueEnum)]`               | `@clap.valueEnum` on a variant                | `valueParser: Clap.ValueParser.t<t>` |
| `#[command(...)]`, `#[arg(...)]`, `#[value(...)]` | `@command({...})`, `@arg({...})`, `@value({...})` |                    |
| `/// doc comment`                    | `/** doc comment */`                          | `about` / `help`, long help         |

A type named `t` gets `args`, `subcommand`, `valueParser` and `parser`; a type
named `foo` gets `fooArgs`, `fooSubcommand`, `fooValueParser` and `fooParser`.

A punned key means "on, with the derived default", as a bare `short` does in
Rust: `@arg({short, long})` gives `-n, --name` for a field `name`.

### Field types

| Field type          | Becomes                                   |
| ------------------- | ----------------------------------------- |
| `bool`              | a flag (`--force`)                        |
| `int` with `action: Count` | a counter (`-vvv`)                 |
| `T`                 | a required argument, unless it has a `default` |
| `option<T>`         | an optional argument                      |
| `array<T>`          | zero or more occurrences                  |
| `option<array<T>>`  | like `array<T>`, but `None` when absent   |

`T` is `string`, `int`, `float`, `bool` (or `String.t`, `Int.t`, `Float.t`,
`Bool.t`), a `@clap.valueEnum` type, or anything with a
`valueParser: Clap.ValueParser.make(parse, format)`. A field without
`short` or `long` is positional.

### `@arg({...})`

`short`, `long`, `env` (punned or a string), `default`, `help`, `longHelp`,
`valueName`, `id`, `alias`, `aliases`, `visibleAlias`, `visibleAliases`,
`action` (`Set`, `Append`, `SetTrue`, `SetFalse`, `Count`), `required`,
`valueParser`, `hide`, `skip: value`.

### `@command({...})`

On a `@clap.parser` type: `name`, `version`, `about`, `longAbout`, `author`,
`renameAll`, `renameAllEnv`. On a field: `subcommand` (type `T` or `option<T>`)
or `flatten`. On a subcommand constructor: `name`, `about`, `longAbout`,
`alias`, `aliases`, `visibleAlias`, `visibleAliases`, `hide`, and `subcommand`
for nested subcommands.

### Subcommands

```rescript
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
  | @command(subcommand) Remote(option<remote>) // nested; optional
  | Status
```

### Value enums

```rescript
@clap.valueEnum
type color =
  /** Always colour the output */
  | Always
  | @value({alias: "off"}) Never
  | Auto
```

`packages/reclap/examples/` has a complete git-like CLI.

## Without the PPX

The runtime mirrors clap's builder API and works on its own:

```rescript
let command =
  Clap.Command.make("prog")->Clap.Command.arg(
    Clap.Arg.make("name")->Clap.Arg.short("n")->Clap.Arg.long("name"),
  )

switch Clap.getMatchesFrom(command, ["prog", "-n", "Ann"]) {
| Ok(matches) => Clap.Matches.getOne(matches, "name", Clap.ValueParser.string)
| Error(error) => Clap.Error.exit(error)
}
```

## Not supported yet

Argument groups, conflicts and requirements between arguments, `global`
arguments, `Option<Option<T>>`, `num_args`, external subcommands, colours, and
wrapping help to the terminal width.

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
| `packages/reclap/test`                 | Vitest suites; `fixtures/clap` holds real clap output   |
| `packages/reclap/test/ppx`             | PPX fixtures and `-dsource` snapshots                   |
| `packages/reclap/ppx/test/errors`      | inputs the PPX must reject, with the expected message   |
| `reference/clap-fixtures`              | the Rust CLIs that produce the golden fixtures          |
| `docs/design.md`                       | attribute surface and generated code                    |
| `docs/clap-output-format.md`           | clap 4's help, usage and error format, as implemented   |

ReScript 12 hands PPXes a frozen OCaml 4.06-shaped AST (`Parsetree0`) that
ppxlib no longer reads, so the PPX carries a verbatim copy of that AST
(`ppx/lib/parsetree0.ml`) and reads and writes the compiler's marshalled files
directly. After changing the PPX, delete `packages/reclap/lib` before
rebuilding: `rescript build` does not notice a new `ppx.exe`.

## Releasing

`.github/workflows/release.yml` builds the PPX on every supported platform
and publishes the npm package.

- **Release:** push a tag `vX.Y.Z`. The workflow publishes version `X.Y.Z`
  (the tag sets the version; `package.json` does not need a bump) under the
  `latest` dist-tag and creates a GitHub Release with the binaries.
- **Dry run:** run the workflow by hand with `dry_run` checked (the default),
  from the Actions tab or with
  `gh workflow run release.yml --ref master -f dry_run=true`. It builds and
  checks every binary, packs the package and uploads the tarball as the
  `npm-package` artifact, without publishing. `ref` selects another branch,
  tag or commit, and `npm_tag` another dist-tag for a real run.

npm authenticates the workflow with trusted publishing: on npmjs.com, under the
package's settings, add a trusted publisher for the GitHub repository
`rolandpeelen/reclap` and the workflow `release.yml`. A first version has to
exist before the package has settings, so publish it with the `NPM_TOKEN`
fallback: a repository secret holding a granular npm access token with
publish rights. npm only attaches provenance to packages from public
repositories, so the workflow passes `--provenance` once the repository is
public.
