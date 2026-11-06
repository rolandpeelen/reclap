# clap 4 output format

This is the spec for reclap's help, usage, version and error output. It
describes clap **4.6.7** with colour off and wrapping off (`term_width = 0`).
Every rule below was checked against the golden fixtures in
`packages/reclap/test/fixtures/clap/` (cited as `greet:<case>` and
`git:<case>`), or, where the fixtures do not cover it, taken from clap's
source: `clap_builder/src/output/help_template.rs`, `output/usage.rs`,
`error/format.rs`, `error/mod.rs`, `parser/parser.rs`, `parser/validator.rs`
and `builder/command.rs`. Source-only rules are marked *(source)*.

Notation: `␠` is one space where the exact count matters; `\n` is a newline.

## 1. Streams and exit codes

| Outcome                                          | Stream | Exit | Fixture |
| ------------------------------------------------ | ------ | ---- | ------- |
| Successful parse                                 | none   | 0    | `greet:long-equals` |
| `-h`, `--help`, `help [SUB]...`                  | stdout | 0    | `git:help-clone` |
| `-V`, `--version`                                | stdout | 0    | `greet:short-version` |
| Required subcommand missing and **no** argument given (`DisplayHelpOnMissingArgumentOrSubcommand`) | stderr: short help, no `error:` prefix | 2 | `git:empty-argv`, `git:stash-empty` |
| Every other error                                | stderr | 2    | |

Help and version are handled the moment the parser reaches the flag: an error
in an earlier argument wins, and a missing required argument does not stop
help (`greet:help-after-args`).

## 2. Version

`<name> <version>\n`, where `<name>` is the command name (not the path in
argv[0]). Both `-V` and `--version` print the same thing unless `long_version`
is set. `-V/--version` exist only on commands with a version; subcommands do
not inherit it (`git:subcommand-version` is an unknown-argument error).

## 3. Help

### 3.1 Which help

- `-h` gives **short help**. `--help` gives **long help** if the command
  *has long help*, else short help (`git:long-help` equals `git:short-help`).
- `help` (auto subcommand, only on commands with subcommands) gives long help
  of the root; `help a b` gives long help of subcommand `a b`. `-h` after a
  subcommand gives that subcommand's short help.
- A command *has long help* when it has `long_about`, or any non-hidden arg
  has `long_help` or has a possible value with help (a `ValueEnum` with doc
  comments). Subcommands are not considered (`git:short-help` still says
  `Print help` although `clone` has a long about).

### 3.2 Overall template

```
{about}\n
\n
Usage:␠{usage}\n
\n
{sections}
```

- `{about}`: short help uses `about`; long help uses `long_about`, falling
  back to `about`. If there is no about, the first two lines are absent (the
  output starts with `Usage:`).
- If the command has no visible args, positionals or subcommands, the output
  ends after the usage line (no sections). Usually `-h` exists, so there is an
  `Options:` section; the auto `help` subcommand has no `-h` and therefore
  only an `Arguments:` section (`git:help-help`).
- `{sections}`, in this order, each only if non-empty:
  1. `Commands:` (visible subcommands, including the auto `help`)
  2. `Arguments:` (visible positionals)
  3. `Options:` (visible non-positionals)

  Each section is `Heading:\n` + items; sections are separated by one blank
  line.
- Finally the whole text is trimmed at the end and exactly one `\n` is added.
  Trailing spaces *inside* the text are kept (see 3.4).

### 3.3 Item order and built-ins

- Args and subcommands appear in declaration order. A `flatten`ed struct's
  args appear where the `flatten` field is (`git:short-help`: `-C`, `-q`
  first).
- `-h, --help` comes after all user options, then `-V, --version` (only with a
  version). Their help text:
  - command has long help: short `Print help (see more with '--help')`, long
    `Print help (see a summary with '-h')`;
  - otherwise: `Print help` in both.
  - `-V, --version`: `Print version`.
- The auto `help` subcommand is last in `Commands:` with about
  `Print this message or the help of the given subcommand(s)`. Its own help is
  in `git:help-help` (usage `git help [COMMAND]...`, positional
  `[COMMAND]...  Print help for the subcommand(s)`).
- Hidden args (`hide`) and hidden values are omitted from help. Usage still
  lists hidden args that are **required** (`edge:hid-help`:
  `edge hid [OPTIONS] --secret <secret> --out <out> <token>`, where `--secret`
  and `<token>` are hidden). Hidden aliases are never shown.

### 3.4 Item spec strings

The **spec** of an item is the text in its left column:

| Item                                   | Spec                       |
| -------------------------------------- | -------------------------- |
| option with short and long             | `-n, --name <NAME>`        |
| option with long only                  | `␠␠␠␠--lang <LANG>` (4 spaces stand in for `-x, `) |
| option with short only                 | `-C <PATH>`                |
| flag (`SetTrue`)                       | `-s, --shout` / `␠␠␠␠--index` |
| counter (`Count`)                      | `-v...` (`...` attached, no value) |
| `Append` option                        | `-t, --tag <TAG>` (no `...` for options) |
| required positional                    | `<REMOTE>`                 |
| optional positional                    | `[GREETING]`               |
| multi-value (`Append`) positional      | `[PATHS]...` / `<PATHS>...` |
| subcommand                             | its name, e.g. `commit`    |

The value placeholder is `value_name` (derive default: SCREAMING_SNAKE_CASE of
the field). The **width** of a spec is its display width including the 4
leading spaces of a long-only option. reclap counts code points, so `-🚀`
is two wide (`edge:emoji-help`); clap uses Unicode display width, which
differs for wide characters such as CJK.

### 3.5 Short-help layout (one line per item)

For each section separately:

```
longest = max(2, max width(spec) over the section's visible items)
line    = "␠␠" + spec + " " * (longest - width(spec) + 2) + text
```

So the text column starts at `2 + longest + 2`. `Arguments:`, `Options:` and
`Commands:` each have their own `longest` (`greet:short-help`: column 14 for
`[GREETING]`, 25 for options).

`text` is the short help (the `help`, else `long_help`), then the **spec
values** appended with one space before each, in this order:

1. `[env: NAME=VALUE]` — `VALUE` is the variable's current value, empty if
   unset: `[env: GREET_LANG=]`.
2. `[default: VALUE]` — only for args that take a value; multiple defaults
   joined by a space.
3. `[alias: --x]` / `[aliases: --x, --y]` — visible arg aliases only
   *(source)*.
4. `[possible values: a, b, c]` — visible possible value names joined by
   `, ` (aliases excluded). Only in short help, or in long help when no
   possible value has help.

If the item has no help text, the spec values follow without a leading space;
if it has neither, the padding is still written, leaving **trailing spaces**
(`git:stash-pop-help`: `"      --index  \n"`, `git:short-help`: `"  gc      \n"`).
A help text containing `\n` continues on the next lines indented by
`longest + 4` spaces.

`Commands:` items use the same layout with the subcommand's `about` (falling
back to `long_about`, never long help) and one spec value: `[alias: ci]` /
`[aliases: a, b]` for **visible** aliases. Subcommands always use this
one-line layout, even in long help.

clap would move help to the next line when the terminal is narrow; with
`term_width = 0` this never happens, and the fixtures show lines over 100
columns (`greet:short-help`, `--color`).

### 3.6 Long-help layout (`Arguments:` and `Options:` only)

Used when long help is requested and the command has long help. Each item:

```
␠␠{spec}\n
␠␠␠␠␠␠␠␠␠␠{text}
```

- Items are separated by a blank line (`\n\n`).
- `text` is `long_help`, falling back to `help`. Every `\n` in it is followed
  by 10 spaces, so an empty line inside the help becomes a line of **10
  spaces** (`greet:long-help`, `--shout`).
- **Possible values block**, when at least one visible possible value has
  help: after the text, `\n\n` (a truly empty line), then 10 spaces +
  `Possible values:`, then per visible value `\n` + 10 spaces + `- ` + name,
  and if the value has help, `: ` + padding to the longest visible value name +
  help (`- never:  Never colour the output`). In this case the
  `[possible values: ...]` spec value is omitted.
- **Spec values** (env, default, aliases, and possible values when there is no
  block) each go on their own line, joined by `\n`. If there is help text or a
  possible-values block, they are preceded by `\n\n`. Every `\n` is followed by
  10 spaces, so the separator line contains 10 spaces:

  ```
  "          Number of times to greet\n          \n          [default: 1]"
  ```
- The about of a subcommand item in `Commands:` stays one line (3.5).

## 4. Usage line

`Usage:␠` is followed by one of two forms. Elements are separated by single
spaces; there is no trailing space.

### 4.1 Help usage (help output and most errors)

```
{bin} [OPTIONS] {required options} {positionals} {subcommand}
```

- `{bin}`: the program name. For a subcommand it is the parent's usage name +
  required args of the parent + ` ` + subcommand name: `git clone`,
  `git remote add` (a parent's required options would appear in between,
  *(source)*).
- `[OPTIONS]`: present if there is at least one non-positional arg that is
  not `--help`/`--version`, not hidden and not required. `git status` has
  none; `git commit` has `-a` so `git commit [OPTIONS] --message <MESSAGE>`.
- Required options, hidden ones included, in declaration order, as
  `--long <VALUE>` (or `-s <VALUE>` without a long; flags without a value).
- Positionals in index order: required ones as `<X>` (hidden ones too), the
  other visible ones as `[X]`; `...` appended for multi-value positionals:
  `git add [OPTIONS] [PATHS]...`.
- Subcommand placeholder, if there are visible subcommands: `<COMMAND>` when
  required, `[COMMAND]` when optional (`git remote [OPTIONS] [COMMAND]`).

### 4.2 Smart usage (some errors, see 6)

Built from the args the user actually gave ("used") plus the required ones:

```
{bin} {required options + used options} {positionals} [<COMMAND>]
```

- No `[OPTIONS]`.
- Options: required ones first (declaration order, hidden ones included), then
  used ones in the order they were seen, without duplicates. Each is rendered
  as in 3.4 without the short: `--name <NAME>`, `--shout`, `-v...`.
- Positionals: a used or required one is `<X>`, the other visible ones `[X]`
  (`greet:missing-required-with-other-args`:
  `greet --name <NAME> -v... <GREETING>`).
- `<COMMAND>` only if a subcommand is required; never `[COMMAND]`.
- Which args count as used depends on the error (table in 6). Hidden args are
  left out of the used list except where noted. When the list ends up empty,
  the help usage (4.1) is shown instead (`edge:hid-unknown-after-hidden`).

## 5. Error format

```
error:␠{message}{context}{tips}{usage}\n
\n
For more information, try '--help'.\n
```

- `{context}`: lines starting with `\n␠␠`, e.g. `\n  [possible values: a, b]`
  or one `\n  <arg>` per missing argument.
- `{tips}`: the first tip is preceded by a blank line (`\n\n`), later tips by
  `\n`; each is `␠␠tip:␠...`.
- `{usage}`: `\n\nUsage:␠...` when the error kind has a usage (table below).
- An arg inside a message is rendered as in usage: `--name <NAME>`,
  `--shout`, `-C <PATH>` (long name preferred: `-n` at the end gives
  `'--name <NAME>'`), positionals `<REMOTE>` / `[DIRECTORY]`.

## 6. Errors by kind

| Situation (kind) | Message and context | Tips | Usage | Fixture |
| --- | --- | --- | --- | --- |
| Unknown `--long`, similar long exists (`UnknownArgument`) | `unexpected argument '--cout' found` | `a similar argument exists: '--count'` | smart: used args, then the suggested one, hidden ones left out | `greet:unknown-long-with-suggestion`, `edge:hid-unknown-suggests-hidden` |
| Unknown `--long`, no similar long, command has positionals | same | `to pass '--zzz' as a value, use '-- --zzz'` | smart | `greet:unknown-long-without-suggestion` |
| Unknown `--long` without positionals | same | none | smart | `git:unknown-long-for-other-subcommand` |
| Unknown `--long` that a later subcommand has | same | `'clone --depth' exists` | smart | `git:unknown-long-suggested-from-subcommand` |
| Unknown short (first unknown char of a cluster: `-vx` → `-x`) | `unexpected argument '-x' found` | `to pass '-x' as a value, use '-- -x'` if the command has positionals | help | `greet:unknown-short-in-cluster` |
| Extra positional (no free positional slot, no similar subcommand name) | `unexpected argument 'extra' found` | none | help | `greet:unexpected-extra-positional`, `edge:pos-unexpected-after-full` |
| Word without a free positional slot, similar subcommand names exist (`InvalidSubcommand`) | `unrecognized subcommand 'comit'` | `a similar subcommand exists: 'commit'`; several: `some similar subcommands exist: 'status', 'stash', 'st'` | help | `git:unknown-subcommand-with-suggestion`, `git:unknown-subcommand-several-suggestions`, `edge:pos-similar-subcommand-after-full` |
| Same, no similar name, command has subcommands and no positionals | `unrecognized subcommand 'frobnicate'` | none | help | `git:unknown-subcommand-without-suggestion` |
| `help nope` | `unrecognized subcommand 'nope'` | none | help usage of the command where lookup failed | `git:help-unknown` |
| Subcommand name after `--` | `unexpected argument 'status' found` | `subcommand 'status' exists; to use it, remove the '--' before it` | help | `git:double-dash-before-subcommand` |
| Value not in possible values (`InvalidValue`) | `invalid value 'alwys' for '--color <COLOR>'` + `\n  [possible values: always, never, auto]` | `a similar value exists: 'always'` | none | `greet:invalid-value-enum-with-suggestion` |
| Option without a value (at end, or next arg is an option) (`InvalidValue`, empty) | `a value is required for '--name <NAME>' but none was supplied` (+ possible values line for enums) | none | none | `greet:missing-value-long-at-end`, `greet:missing-value-enum` |
| Value parser fails (`ValueValidation`) | `invalid value 'abc' for '--count <COUNT>': {parser message}` | none | none | `greet:invalid-int` |
| Required args missing (`MissingRequiredArgument`) | `the following required arguments were not provided:` + `\n  --name <NAME>` per arg (options first in declaration order, then positionals by index) | none | smart: visible args given on the command line, then visible args read from the environment, then the missing ones (hidden too) | `greet:missing-required`, `git:missing-nested-positionals`, `edge:hid-missing-with-env` |
| Value given to a flag, `--help` or `--version` (`TooManyValues`) | `unexpected value 'x' for '--shout' found; no more were expected` | none | smart: used args that are neither hidden nor required, then this one | `greet:flag-with-value`, `edge:help-with-value` |
| Non-repeatable arg given twice (`ArgumentConflict`) | `the argument '--name <NAME>' cannot be used multiple times` | none | help | `greet:repeated-single-value-arg`, `greet:repeated-flag` |
| Subcommand required, some args given (`MissingSubcommand`) | `'git' requires a subcommand but one was not provided` + `\n  [subcommands: clone, add, status, st, commit, ci, remote, stash, gc, rm, help]` (names and **all** aliases, hidden too, in declaration order) | none | help | `git:missing-subcommand-with-args` |
| Subcommand required, no args at all | short help on stderr (no `error:`, no footer) | | | `git:empty-argv` |

Parser messages for integers (`ValueValidation`), from Rust's parser and
clap's ranged parser for `u8`:

- `invalid digit found in string`
- `cannot parse integer from empty string`
- `300 is not in 0..=255`, `-1 is not in 0..=255` (`u8`: range `0..=255`)

A `Count` arg reads its environment variable with the `u8` parser, so errors
name it `-v...` (`edge:count-env-too-large`). `SetTrue`/`SetFalse` flags read
theirs with the bool parser, which accepts exactly `true` and `false`:
`invalid value 'yes' for '--flag'` + `\n  [possible values: true, false]`, a
similar-value tip for near misses (`ture`), and an empty variable is
`a value is required for '--flag' but none was supplied` with the same list
(`edge:flag-env-*`).

Floats use Rust's `f64` grammar: `inf`, `infinity` and `nan` in any case and
with an optional sign; `Display` writes `inf`, `-inf` and `NaN`.

**Suggestions** use Jaro similarity > 0.7 *(source)*. Arguments and values
get the single best match. Subcommands list every match (names and aliases,
hidden ones included), ordered from least to most similar.

## 7. Parsing behaviour visible in the fixtures

- `--name=x`, `--name x`, `-nx`, `-n x`, `-n=x` all give `x`. `--name=` gives
  the empty string (`greet:missing-value-equals-empty`).
- Short clusters: `-vvv` counts 3; `-vn Ann` and `-vsnAnn` work. In a
  cluster, the first char that takes a value consumes the rest (minus one
  leading `=`). `-q=yes` on a flag is `unexpected argument '-=' found` (help
  usage), because `=` is read as the next short flag (`git:flag-with-value`).
- A value is never taken from an argument that starts with `-` (unless it is
  just `-`): `--name --shout` is a missing value; `--offset -3` and
  `--count -1` are `unexpected argument '-3' found` with the `-- -3` tip. Use
  `--offset=-3`.
- `-` alone is a positional. `--` makes every later argument positional
  (`greet:double-dash-then-option-like`).
- Positionals and options can be mixed in any order.
- An arg with `Set` given twice is an error; `Append` collects in order
  across `-t a`, `--tag b`, `--tag=c`, `-td`.
- Precedence: command line, then the env var (an empty env var gives `""`
  for options), then the default. A flag's or counter's env var is ignored
  when the flag is given (`edge:flag-env-ignored-when-given`).
- Absent flags and counters are present in the matches with a default value:
  `false` (`true` for `SetFalse`) and `0` (`edge:flags-absent`).
- Order of checks after parsing a level: env values are validated (an
  invalid env value wins over a missing subcommand, `edge:strict-invalid-env`),
  then `arg_required_else_help`, which counts env values as given
  (`edge:need-env`, `edge:strict-valid-env`), then the missing subcommand,
  then missing required args.
- A word that matches a subcommand name starts that subcommand, except right
  after a value of a multi-value positional, where it is another value:
  `multi a run` gives `files = [a, run]`, `multi run` runs `run`, and an
  option in between (`multi a --loud run`, `edge:multi-subcommand-after-flag`)
  ends the positional's values.
- Short names are split by code point: `-🚀` and `-x🚀` work
  (`edge:emoji-*`).
- `ValueEnum` accepts value aliases (`--color off`); errors and help list only
  the visible names.
- Parent options are not accepted after the subcommand name
  (`git:global-after-subcommand`); they must come before it.
- Hidden subcommand aliases are accepted (`st`); visible ones too (`ci`).
- An optional subcommand may be absent (`git:remote-without-subcommand`). A
  required one that is absent gives help (no args) or `MissingSubcommand`.
- A CLI without subcommands treats `help` as an ordinary positional
  (`greet:help-subcommand-absent`).

## 8. Doc comments (clap_derive)

- A doc comment is split into paragraphs at blank lines. Lines inside a
  paragraph are trimmed and joined with one space.
- `about`/`help` = the first paragraph, with one trailing `.` removed (not
  `..`). This happens with one paragraph too: `Offset added to the count.`
  shows as `Offset added to the count`.
- If there is more than one paragraph, `long_about`/`long_help` = all
  paragraphs joined by `\n\n`, with no period removed (`Shout the greeting.`
  keeps its period in long help).
- A doc comment on a `#[command(subcommand)]` field is ignored.
