---
name: reclap
description: Build command line interfaces in ReScript 12 with reclap, a port of Rust's clap derive. Use when writing, changing or debugging a CLI that uses the `@clap.parser`, `@clap.args`, `@clap.subcommand` or `@clap.valueEnum` attributes, `@arg({...})`, `@command({...})` or `@value({...})`, `Clap.parse` or `Clap.tryParseFrom`, or when setting up the reclap PPX in `rescript.json`.
---

# reclap

reclap derives command line parsers from ReScript types, the way Rust's clap
derives them from Rust types. A PPX reads attributes on type declarations and
generates ordinary values; the runtime parses `argv` and prints help, usage and
errors exactly as clap 4 does. If you know clap's derive API, the mapping is
mechanical: see [Rust to ReScript](#rust-to-rescript).

## Setup

```sh
npm install @rolandpeelen/reclap
```

`rescript.json`:

```json
{
  "dependencies": ["@rolandpeelen/reclap"],
  "ppx-flags": ["@rolandpeelen/reclap/bin/ppx"]
}
```

The package ships a prebuilt PPX for Linux (x64, arm64), macOS (x64, arm64)
and Windows (x64); there is no build step. After changing `ppx-flags`, run a
clean build (`rescript clean && rescript build`).

## A complete program

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

`Clap.parse(parser)` reads `process.argv`, and on `--help`, `--version` or an
error prints and exits (0 for help and version, 2 otherwise). To handle errors
yourself or to test, use `Clap.tryParseFrom(parser, ["greet", "-n", "Ann"])`,
which returns `result<t, Clap.Error.t>`; the first element is the program name.
`Clap.Error.render`, `Clap.Error.exitCode` and `Clap.Error.exit` work on the
error. Pass `~env=Dict.make()` in tests so environment variables don't leak in.

## What the attributes generate

| Attribute on the type | On a record                 | On a variant                         |
| --------------------- | --------------------------- | ------------------------------------ |
| `@clap.parser`        | `args` and `parser`         | `subcommand` and `parser`            |
| `@clap.args`          | `args: Clap.Args.t<t>`      | error                                |
| `@clap.subcommand`    | error                       | `subcommand: Clap.Subcommand.t<t>`   |
| `@clap.valueEnum`     | error                       | `valueParser: Clap.ValueParser.t<t>` |

For a type named `t` the values are `args`, `subcommand`, `valueParser` and
`parser`. For a type named `foo` they are `fooArgs`, `fooSubcommand`,
`fooValueParser` and `fooParser`. The PPX refers to the values of other types
by this rule: a field of type `Level.t` uses `Level.valueParser`, a field of
type `color` uses `colorValueParser`. So a type used as a field must be
declared before the type that uses it (or in the same `type ... and ...`
group), and a type from another module must be qualified.

In a `.resi`, put the same attributes on the type and the PPX declares the
generated values. `@clap.parser` in a `.resi` needs the full type definition.

## Fields

| Field type          | Becomes                                         |
| ------------------- | ----------------------------------------------- |
| `bool`              | a flag (`--force`); must have `short` or `long` |
| `int` + `action: Count` | a counter (`-vvv`)                          |
| `T`                 | a required argument, unless it has a `default`  |
| `option<T>`         | an optional argument                            |
| `array<T>`          | zero or more occurrences                        |
| `option<array<T>>`  | like `array<T>`, but `None` when absent         |

`T` is `string`, `int`, `float`, `bool` (also `String.t`, `Int.t`, `Float.t`,
`Bool.t`), a `@clap.valueEnum` type, or any type with a value parser named by
the rule above. A field without `short` or `long` is **positional**. Optional
record fields (`name?: string`), `option<option<T>>` and other nesting are
rejected; use `option<T>`.

Doc comments (`/** ... */`) become help text. The first paragraph, without one
trailing period, is the short help; a comment with more paragraphs also becomes
the long help shown by `--help`.

### `@arg({...})`

A punned key means "on, with the derived default", as a bare `short` does in
Rust. `@arg(long)` and `@arg({long})` are the same.

| Key | Meaning |
| --- | --- |
| `short` / `short: "n"` | short name; punned: first character of the long name |
| `long` / `long: "name"` | long name; punned: the kebab-case field name |
| `env` / `env: "NAME"` | read from an environment variable; punned: SCREAMING_SNAKE_CASE field name |
| `default: expr` | typed default (clap's `default_value_t`); an array for `array<T>` |
| `help: "..."`, `longHelp: "..."` | override the doc comment |
| `valueName: "FILE"` | placeholder in usage and help; default: `id` if given, else SCREAMING_SNAKE_CASE field name |
| `id: "x"` | argument id; default: the field name |
| `alias`, `aliases: [...]` | hidden long aliases |
| `visibleAlias`, `visibleAliases: [...]` | long aliases shown in help |
| `action: X` | `Set`, `Append`, `SetTrue`, `SetFalse` (a `bool` that is `true` unless the flag is given, as in `--no-color`) or `Count` (needs `int`) |
| `required: bool` | override the inferred requiredness |
| `valueParser: expr` | a `Clap.ValueParser.t<T>` for the element type |
| `hide` | hide from help |
| `skip: expr` | no argument; the field is always `expr` |

`default`, `valueName`, `valueParser` and `required` are errors on flags and
counters, which take no value.

### `@command({...})`

- On a `@clap.parser` type: `name` (default: kebab-case type name, or the
  module name for a type `t`), `version`, `about`, `longAbout`, `author`,
  `renameAll`, `renameAllEnv`.
- On `@clap.args` and `@clap.subcommand` types: `renameAll`, `renameAllEnv`.
- On a record field: `subcommand` (field type `T` or `option<T>` with
  `@clap.subcommand`; at most one per record) or `flatten` (field type `T` with
  `@clap.args`).
- On a subcommand constructor: `name`, `about`, `longAbout`, `alias`,
  `aliases`, `visibleAlias`, `visibleAliases`, `hide`, `subcommand`.

`renameAll` values: `"kebab-case"` (default), `"snake_case"`, `"camelCase"`,
`"PascalCase"`, `"SCREAMING_SNAKE_CASE"`, `"lower"`, `"UPPER"`, `"verbatim"`.

## Subcommands

```rescript
@clap.args
type addArgs = {@arg({short: "n", long}) dryRun: bool, paths: array<string>}

@clap.subcommand
type remote =
  /** Add a remote */
  | Add({name: string, url: string})
  /** Remove a remote */
  | @command({alias: "rm"}) Remove({name: string})

@clap.subcommand
type command =
  | Add(addArgs) // one @clap.args type, like `Add(AddArgs)` in Rust
  | @command({visibleAlias: "ci"}) Commit({@arg({short, long}) message: string})
  | @command(subcommand) Remote(option<remote>) // nested subcommands, optional
  | Status // no arguments

/** A fictional version control system */
@clap.parser @command({name: "git", version: "2.0.0"})
type t = {
  @arg({short, long}) quiet: bool,
  @command(subcommand) command: command, // required; option<command> is optional
}
```

A constructor takes no payload, an inline record (its fields are the
subcommand's arguments), one `@clap.args` type, or, with
`@command(subcommand)`, one `@clap.subcommand` type (`T` or `option<T>`). A
`@clap.parser` variant is a CLI that is only subcommands.

## Value enums and custom values

```rescript
@clap.valueEnum
type color =
  /** Always colour the output */
  | Always
  | @value({alias: "off"}) Never
  | Auto
  | @value(skip) Internal // not accepted on the command line

@clap.args
type t = {@arg({long, default: Auto}) color: color}
```

`@value({...})` keys: `name`, `help`, `alias`, `aliases`, `hide`, `skip`; on
the type, `@value({renameAll: "..."})`. Constructors cannot have payloads. A
skipped value cannot be a `default`.

For any other type, write the value parser yourself under the generated name,
or pass it with `valueParser:`. `format` must invert `parse`: defaults are
shown and stored through it.

```rescript
type port = Port(int)

let portValueParser = Clap.ValueParser.make(
  text =>
    switch Int.fromString(text) {
    | Some(number) if number > 0 && number < 65536 => Ok(Port(number))
    | Some(_) | None => Error("not a port number")
    },
  (Port(number)) => Int.toString(number),
)

@clap.args
type t = {@arg({long, default: Port(8080)}) port: port}
```

## Compile errors the PPX reports

The PPX reports mistakes at the attribute's location instead of generating
code that fails at run time. The usual ones:

- **Duplicate names.** Two arguments in one record with the same id, long name
  (aliases count) or short name, or one that takes `-h`/`--help`, or
  `-V`/`--version` on a `@clap.parser` with a `version`. Two subcommands with
  the same name or alias, or a subcommand named `help`. Rename one, or set a
  different `short`, `long` or `id`. (A flattened record is checked on its
  own, so keep its names apart from the parent's yourself.)
- **A `bool` or `Count` field without `short` or `long`.** Flags must be named.
- **`action` that does not fit the type**, such as `Count` on a `string`.
- **A default that names a `@value(skip)` constructor.**
- **Unknown keys** in `@arg`, `@command` or `@value`, and attributes in the
  wrong place.
- **Unsupported field types**: tuples, functions, type parameters, nested
  `option`/`array`, recursive `@clap` types.

If a type error mentions a missing value such as `colorValueParser`, the field
type has no value parser: add `@clap.valueEnum` to it, write the value, or
pass `valueParser:`.

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

## Rust to ReScript

| Rust | ReScript |
| --- | --- |
| `#[derive(Parser)]`, `Args`, `Subcommand`, `ValueEnum` | `@clap.parser`, `@clap.args`, `@clap.subcommand`, `@clap.valueEnum` |
| `#[command(...)]`, `#[arg(...)]`, `#[value(...)]` | `@command({...})`, `@arg({...})`, `@value({...})` |
| `/// doc comment` | `/** doc comment */` |
| `String`, `i32`/`u8`, `f64`, `bool`, `PathBuf` | `string`, `int`, `float`, `bool`, `string` |
| `Option<T>`, `Vec<T>` | `option<T>`, `array<T>` |
| `default_value_t = 1` | `default: 1` |
| `value_name`, `long_help`, `visible_alias`, `rename_all` | `valueName`, `longHelp`, `visibleAlias`, `renameAll` |
| `action = ArgAction::Count` | `action: Count` |
| `Cli::parse()`, `Cli::try_parse_from(argv)` | `Clap.parse(parser)`, `Clap.tryParseFrom(parser, argv)` |

## Not supported

Argument groups, conflicts and requirements between arguments, `global`
arguments, `Option<Option<T>>`, `num_args`, external subcommands, colours, and
wrapping help to the terminal width. Do not try to emulate these with
attributes that don't exist; the PPX rejects unknown keys.
