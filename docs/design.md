# reclap design

reclap derives command line parsers from ReScript types, the way Rust's
[clap](https://docs.rs/clap/latest/clap/_derive/index.html) derives them from
Rust types. It has two parts:

- **The runtime** (`packages/reclap/src`): a builder API (`Clap.Arg`,
  `Clap.Command`), the parser, help and error rendering. It works without the
  PPX, like clap's builder API.
- **The PPX** (`packages/reclap/ppx`): reads `@clap.*` attributes on type
  declarations and generates values that call the builder API and decode the
  parse result into the type.

## How clap's derive works

`#[derive(Parser)]` does not parse anything itself. `clap_derive` expands every
derive into two pieces of ordinary code (see `clap_derive/src/derives/args.rs`):

1. **Augment** (`Args::augment_args`, `Subcommand::augment_subcommands`): a
   function that takes a `Command` and adds one `Arg::new(id)` per field, with
   builder calls inferred from the field type and attributes:
   `.value_name(..).required(..).value_parser(value_parser!(T)).action(..)`,
   then the explicit attribute methods (`.short('n').long("name")`).
2. **Construct** (`FromArgMatches::from_arg_matches`): reads each field out of
   the untyped `ArgMatches` by id with `remove_one::<T>(id)`,
   `remove_many::<T>(id)`, and so on, and builds the struct. Subcommand enums
   match on `matches.subcommand_name()`.

`Parser::parse()` is a provided trait method: build the command, run the
runtime parser on `std::env::args`, call `from_arg_matches`, and on error
print and exit (code 0 for help and version, 2 otherwise).

Behaviour is inferred from the field type:

| Rust field type      | Effect                     | Implies                                        |
| -------------------- | -------------------------- | ---------------------------------------------- |
| `bool`               | flag                       | `ArgAction::SetTrue`                           |
| `Option<T>`          | optional argument          | `ArgAction::Set`, not required                 |
| `T`                  | required argument          | `ArgAction::Set`, required unless defaulted    |
| `Vec<T>`             | zero or more occurrences   | `ArgAction::Append`, not required              |
| `Option<Vec<T>>`     | like `Vec<T>`, but `None` when absent |                                     |
| subcommand `T`       | required subcommand        | `subcommand_required` + `arg_required_else_help` |
| subcommand `Option<T>` | optional subcommand      |                                                |

A field without `short` or `long` is positional. Names are derived from the
field name: `long` is the kebab-case name, `short` its first character,
`value_name` the SCREAMING_SNAKE_CASE name, `env` the SCREAMING_SNAKE_CASE
name. Doc comments become `about`/`help`; when a doc comment has more than one
paragraph, the whole comment also becomes `long_about`/`long_help`. As in
`clap_derive`, paragraphs are separated by blank lines and the lines of a
paragraph are trimmed and joined with spaces. The summary is the first
paragraph without one trailing `.` (`...` is kept); the long text is every
paragraph, joined by an empty line, with periods kept.

## The ReScript surface

Rust attributes map to ReScript attributes. `#[derive(X)]` becomes
`@clap.x` on the type; `#[arg(...)]`, `#[command(...)]` and `#[value(...)]`
become `@arg({...})`, `@command({...})` and `@value({...})` with a record
payload. A punned field means "on, with the derived default", exactly like a
bare `short` in Rust. A single punned field parses as an identifier, so
`@arg(long)` and `@arg({long})` are both accepted.

```rescript
/** Simple program to greet a person */
@clap.parser @command({version: "1.0.0"})
type t = {
  /** Name of the person to greet */
  @arg({short, long}) name: string,
  /** Number of times to greet */
  @arg({short, long, default: 1}) count: int,
}

let args = Clap.parse(parser)
```

| Rust                                  | ReScript                                    |
| ------------------------------------- | ------------------------------------------- |
| `#[derive(Parser)]` on a struct/enum  | `@clap.parser` on a record/variant          |
| `#[derive(Args)]`                     | `@clap.args` on a record                    |
| `#[derive(Subcommand)]`               | `@clap.subcommand` on a variant             |
| `#[derive(ValueEnum)]`                | `@clap.valueEnum` on a variant of constant constructors |
| `/// doc comment`                     | `/** doc comment */`                        |
| `Option<T>`, `Vec<T>`                 | `option<T>`, `array<T>`                     |
| `String`, `i32`/`u8`, `f64`, `bool`   | `string`, `int`, `float`, `bool`            |

### Attributes

`@command({...})` on a `@clap.parser` type:
`name: string` (default: the kebab-case type name, or the kebab-case module
name for a type named `t`), `version: string`, `about: string`,
`longAbout: string`, `author: string`, `renameAll: string`,
`renameAllEnv: string`.

`@command({...})` on a record field: `subcommand` (field type `T` or
`option<T>`, where `T` has `@clap.subcommand`) or `flatten` (field type `T`,
where `T` has `@clap.args`).

`@command({...})` on a subcommand constructor: `name`, `about`, `longAbout`,
`alias: string`, `aliases: array<string>` (hidden), `visibleAlias: string`,
`visibleAliases: array<string>` (shown in help), `hide`, and `subcommand` (the
constructor payload is a `@clap.subcommand` type whose subcommands nest under
this one).

`@arg({...})` on a record field:

| Key                    | Meaning                                                                 |
| ---------------------- | ----------------------------------------------------------------------- |
| `short` / `short: "n"` | short name; punned = first character of the cased long name             |
| `long` / `long: "x"`   | long name; punned = the cased field name                                |
| `env` / `env: "X"`     | environment variable; punned = SCREAMING_SNAKE_CASE field name          |
| `default: expr`        | typed default value (clap's `default_value_t`); arrays for `array<T>`   |
| `help: "..."`          | overrides the doc comment summary                                       |
| `longHelp: "..."`      | overrides the long doc comment                                          |
| `valueName: "FILE"`    | placeholder in usage and help                                           |
| `id: "x"`              | argument id; default: the field name                                    |
| `alias: "x"`, `aliases: [..]` | hidden long aliases                                              |
| `visibleAlias: "x"`, `visibleAliases: [..]` | long aliases shown in help                                 |
| `action: Count`        | `Set`, `Append`, `SetTrue`, `SetFalse` or `Count` (`Count` needs `int`) |
| `required: bool`       | overrides the inferred requiredness                                     |
| `valueParser: expr`    | a `Clap.ValueParser.t<T>` for the field's element type                  |
| `hide`                 | hide from help                                                          |
| `skip: expr`           | do not register an argument; the field is always `expr`                 |

`@value({...})` on a `@clap.valueEnum` constructor: `name`, `help`, `alias`,
`aliases`, `hide`, `skip`. On the type: `renameAll`.

`renameAll` accepts clap's values: `"kebab-case"` (default), `"snake_case"`,
`"camelCase"`, `"PascalCase"`, `"SCREAMING_SNAKE_CASE"`, `"lower"`,
`"UPPER"`, `"verbatim"`.

### Field types

| ReScript field type | Generated arg                               | Decoder                                  |
| ------------------- | ------------------------------------------- | ---------------------------------------- |
| `bool`              | action `SetTrue`                            | `Clap.Matches.getFlag`                   |
| `int` + `action: Count` | action `Count`                          | `Clap.Matches.getCount`                  |
| `option<T>`         | `Set`, value parser                         | `Clap.Matches.getOne`                    |
| `T`                 | `Set`, required unless `default`            | `Clap.Matches.getRequired`               |
| `array<T>`          | `Append`, value parser                      | `Clap.Matches.getMany`                   |
| `option<array<T>>`  | `Append`, value parser                      | `Clap.Matches.getManyOptional`           |

A `bool` field must be named (`short` or `long`); a positional flag is a
compile error, as it is a debug assertion in clap.

Names must be unique, as clap's debug assertions require. Within one record,
two arguments cannot share an id, a long name (aliases included) or a short
name, and the automatic `-h`/`--help` (and `-V`/`--version` on a
`@clap.parser` record with a `version`) count as arguments. Within one variant,
two subcommands cannot share a name or alias, and the automatic `help`
subcommand counts. The PPX reports each repetition as a compile error. A
flattened type is checked on its own, not against the record it is flattened
into.

### Value parsers and naming

The value parser for an element type `T` is:

- `string`, `int`, `float`, `bool`: `Clap.ValueParser.string` and so on.
- Any other type: the value that `@clap.valueEnum` generates for it, by the
  naming rule below. Users can write that value by hand for custom types, which
  is how clap's `value_parser = ...` is spelled.

**Naming rule.** For a type named `t`, the generated values are `args`,
`subcommand`, `valueParser` and `parser`. For a type named `foo`, they are
`fooArgs`, `fooSubcommand`, `fooValueParser` and `fooParser`. A qualified type
keeps its module path: `Level.t` → `Level.valueParser`, `Git.remote` →
`Git.remoteSubcommand`.

| Attribute on type     | Record generates               | Variant generates                  |
| --------------------- | ------------------------------ | ---------------------------------- |
| `@clap.args`          | `xArgs: Clap.Args.t<x>`        | error                              |
| `@clap.subcommand`    | error                          | `xSubcommand: Clap.Subcommand.t<x>` |
| `@clap.valueEnum`     | error                          | `xValueParser: Clap.ValueParser.t<x>` |
| `@clap.parser`        | `xArgs` and `xParser`          | `xSubcommand` and `xParser`        |

In a `.resi`, the same attributes generate the matching `let` declarations.

## Generated code

For

```rescript
/** Simple program to greet a person */
@clap.parser @command({version: "1.0.0"})
type t = {
  /** Name of the person to greet */
  @arg({short, long}) name: string,
  @arg({short, long, default: 1}) count: int,
  @arg({short, action: Count}) verbose: int,
  @command({subcommand}) command: option<command>,
}
```

in `Greet.res`, the PPX appends (shown as ReScript; it builds the AST directly):

```rescript
let args: Clap.Args.t<t> = Clap.Args.make(
  __clap_command => {
    let __clap_command = Clap.Command.arg(
      __clap_command,
      Clap.Arg.help(
        Clap.Arg.long(
          Clap.Arg.short(
            Clap.Arg.valueParser(
              Clap.Arg.action(
                Clap.Arg.required(Clap.Arg.valueName(Clap.Arg.make("name"), "NAME"), true),
                Clap.Arg.Set,
              ),
              Clap.ValueParser.string,
            ),
            "n",
          ),
          "name",
        ),
        "Name of the person to greet",
      ),
    )
    let __clap_command = Clap.Command.arg(__clap_command, /* count, with
      Clap.Arg.defaultValue(_, Clap.ValueParser.int, 1) */)
    let __clap_command = Clap.Command.arg(__clap_command, /* verbose, action Count */)
    Clap.Subcommand.augment(commandSubcommand, __clap_command)
  },
  __clap_matches =>
    switch Clap.Matches.getRequired(__clap_matches, "name", Clap.ValueParser.string) {
    | Error(__clap_error) => Error(__clap_error)
    | Ok(__clap_field_name) =>
      switch Clap.Matches.getRequired(__clap_matches, "count", Clap.ValueParser.int) {
      | Error(__clap_error) => Error(__clap_error)
      | Ok(__clap_field_count) =>
        let __clap_field_verbose = Clap.Matches.getCount(__clap_matches, "verbose")
        switch Clap.Subcommand.fromMatchesOptional(commandSubcommand, __clap_matches) {
        | Error(__clap_error) => Error(__clap_error)
        | Ok(__clap_field_command) =>
          Ok(({
            name: __clap_field_name,
            count: __clap_field_count,
            verbose: __clap_field_verbose,
            command: __clap_field_command,
          }: t))
        }
      }
    },
)

let parser: Clap.Parser.t<t> = Clap.Parser.fromArgs(
  Clap.Command.about(Clap.Command.version(Clap.Command.make("greet"), "1.0.0"), "Simple program to greet a person"),
  args,
)
```

Field values are bound to `__clap_field_<name>`, so a field named `command`,
`matches` or `error` cannot shadow the generated `__clap_command`,
`__clap_matches` and `__clap_error`. Reads that cannot fail (`getFlag`,
`getCount`, `skip`) are plain `let` bindings. Built values carry a type
annotation (`(... : t)`) so record and constructor disambiguation never picks
another type with the same field or constructor names. A lambda whose
parameter would be unused, such as the decoder of a record with only `skip`
fields, takes `_`.

A `@clap.subcommand` variant generates:

```rescript
let commandSubcommand: Clap.Subcommand.t<command> = Clap.Subcommand.make(
  __clap_command => {
    let __clap_command = Clap.Command.subcommand(__clap_command, /* Clap.Command.make("add") + args */)
    let __clap_command = Clap.Command.subcommand(__clap_command, Clap.Command.make("status"))
    __clap_command
  },
  __clap_matches =>
    switch Clap.Matches.subcommand(__clap_matches) {
    | Some(("add", __clap_matches)) => /* decode the fields, then */ Ok(Add({...}))
    | Some(("status", _)) => Ok((Status: command))
    | Some(_) | None => Clap.Matches.missingSubcommand(__clap_matches)
    },
)
```

Constructor payloads:

- none (`Status`): a subcommand without arguments;
- an inline record (`Add({name: string})`): the fields are the subcommand's
  arguments, with the same rules as a `@clap.args` record;
- one type (`Add(addArgs)`): `Clap.Args.augment(addArgsArgs, cmd)` and
  `Clap.Args.fromMatches(addArgsArgs, sub)`, like a clap newtype variant;
- one type with `@command({subcommand})`: nested subcommands through
  `Clap.Subcommand.augmentRequired` and `Clap.Subcommand.fromMatches`.

A `@clap.valueEnum` variant generates:

```rescript
let levelValueParser: Clap.ValueParser.t<level> = Clap.ValueParser.enum([
  ((Debug: level), Clap.PossibleValue.help(Clap.PossibleValue.make("debug"), "Everything")),
  ((Info: level), Clap.PossibleValue.make("info")),
])
```

### Constraints on the generated AST

The PPX talks to the compiler through ReScript 12's frozen `Parsetree0`
(`compiler/ml/parsetree0.ml`), not through ppxlib: ppxlib 0.35 no longer reads
the 4.06 binary AST that ReScript uses. `packages/reclap/ppx/lib/parsetree0.ml`
is a verbatim copy, and the PPX marshals it with `input_value`/`output_value`.
Rules for generated code:

- Do not emit `Pexp_function`; the compiler asserts on it. Use `Pexp_fun` +
  `Pexp_match`.
- A bare `Pexp_fun` is a one-parameter function. Generated lambdas take one
  parameter. A multi-parameter function needs `Function$` with `res.arity`.
- Emit string constants as `Pconst_string (s, Some "js")`, as the ReScript
  parser does.
- Report user errors as `[%%ocaml.error "message"]` items (or
  `[%ocaml.error]` expressions) at the attribute's location; the compiler
  prints them as located errors.
- Doc comments arrive as `res.doc` attributes with a string payload.
- Optional record fields (`x?: t`) carry `res.optional`; they are rejected.
- `{long}` with one punned field arrives as `Pexp_ident "long"` with a
  `res.braces` attribute.

## Out of scope for the first version

Argument groups, conflicts and requirements between arguments, `global`
arguments, `Option<Option<T>>`, `num_args`, external subcommands, value hints,
help wrapping to the terminal width, colours, and flattening subcommand enums
into each other.
