# clap golden fixtures

Real output of Rust's clap, recorded so the reclap runtime can be checked
against the original. Do not edit the JSON by hand; regenerate it.

- **clap version:** 4.6.7 (`clap_builder` 4.6.7, `clap_derive` 4.6.7), pinned
  in `reference/clap-fixtures/Cargo.toml` and `Cargo.lock`.
- **Features:** `std`, `help`, `usage`, `error-context`, `suggestions`,
  `derive`, `env`. No `color` (output has no ANSI codes) and no `wrap_help`.
- **Width:** every command sets `term_width = 0`, so clap never wraps help and
  never switches to "help on the next line" because of width. Lines longer than
  100 columns in the fixtures prove it.

## Regenerate

```sh
reference/clap-fixtures/regen.sh
```

This builds the CLIs (`cargo build --locked --bins`) and runs the `runner`
binary, which overwrites `greet.json`, `git.json` and `edge.json` here. The first build
needs crates.io access. The output is deterministic.

## Files

| File         | CLI source                                          |
| ------------ | --------------------------------------------------- |
| `greet.json` | `reference/clap-fixtures/src/bin/greet.rs` (no subcommands) |
| `git.json`   | `reference/clap-fixtures/src/bin/git.rs` (subcommands)      |
| `edge.json`  | `reference/clap-fixtures/src/bin/edge.rs` (builder API; parser, usage and environment edge cases) |

The argv cases are listed in `reference/clap-fixtures/src/bin/runner.rs`.

Each file has this shape:

```json
{
  "cli": "greet",
  "clapVersion": "4.6.7",
  "cases": [
    {
      "name": "short-help",
      "argv": ["-h"],
      "env": {},
      "exitCode": 0,
      "stdout": "...",
      "stderr": "",
      "parsed": null
    }
  ]
}
```

- `argv` excludes the program name. The binary is invoked as `greet`, `git` or
  `edge`, so usage lines start with that name.
- `env` lists the environment variables of the case. The runner clears the
  rest of the environment; it only adds `CLAP_FIXTURE_OUT`, the file where the
  CLI writes `parsed`. clap does not read that variable.
- `stdout` and `stderr` are exactly what clap printed. Help and version go to
  stdout with exit code 0. Errors go to stderr with exit code 2. A missing
  required subcommand with no other arguments prints the short help to stderr,
  also with exit code 2.
- `parsed` is `null` when clap exited, and otherwise
  `{"value": ..., "debug": "..."}`: `value` is the serde JSON of the parsed
  struct, `debug` its Rust `{:?}`. In `value`, enums use serde's external
  tagging: a unit variant is a string (`"Status"`), a struct or newtype variant
  is `{"Clone": {...}}`, and a `ValueEnum` is the variant name (`"Auto"`).
  `Option` is `null` when absent and a `Vec` is `[]` when absent.
- `edge` is written with the builder API, so its `value` is a dump of the
  `ArgMatches` instead: `{"args": {id: {"values": [...], "source": ...}},
  "subcommand": {"name": ..., "matches": ...} | null}`, with the raw values
  (`get_raw`) and the `ValueSource` of every id in `ids()`, sorted by id. It
  has no `debug`.

See `docs/clap-output-format.md` for the formatting rules derived from these
outputs and from clap's source.
