/*** The `greet` CLI of `reference/clap-fixtures/src/bin/greet.rs`, derived from types with
the `@clap.*` attributes. */

/** Rust's `u8`, with the message of clap's ranged integer parser. */
let u8ValueParser: Clap.ValueParser.t<int> = Clap.ValueParser.make(
  input =>
    switch Clap.ValueParser.int.parse(input) {
    | Ok(value) if value >= 0 && value <= 255 => Ok(value)
    | Ok(value) => Error(`${Int.toString(value)} is not in 0..=255`)
    | Error(reason) => Error(reason)
    },
  value => Int.toString(value),
)

@clap.valueEnum
type color =
  /** Always colour the output */
  | Always
  /** Never colour the output */
  | @value({alias: "off"}) Never
  /** Colour the output when stdout is a terminal */
  | Auto

/** Simple program to greet a person

Greets NAME a number of times. This second paragraph only appears in the
long help (`--help`), as clap's `long_about`. */
@clap.parser @command({name: "greet", version: "1.0.0"})
type t = {
  /** Name of the person to greet */
  @arg({short, long}) name: string,
  /** Number of times to greet */
  @arg({short, long, default: 1, valueParser: u8ValueParser}) count: int,
  /** Increase verbosity */
  @arg({short, action: Count}) verbose: int,
  /** Greeting to use instead of "Hello" */
  greeting: option<string>,
  /** Tag to attach (repeatable) */
  @arg({short, long}) tag: array<string>,
  /** Language of the greeting */
  @arg({long, env: "GREET_LANG"}) lang: option<string>,
  /** Colour of the output */
  @arg({long, default: Auto}) color: color,
  /** Offset added to the count. */
  @arg({long, default: 0}) offset: int,
  /** Internal option, hidden from help */
  @arg({long, hide}) secret: option<string>,
  /** Shout the greeting.

  Prints the greeting in upper case and appends an exclamation mark.
  Only `--help` shows this paragraph. */
  @arg({short, long}) shout: bool,
}
