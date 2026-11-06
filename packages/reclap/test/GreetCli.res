/*** The `greet` CLI of `reference/clap-fixtures/src/bin/greet.rs`, written with the builder
API as the derive would generate it. */

type color =
  | Always
  | Never
  | Auto

let colorValueParser = Clap.ValueParser.enum([
  (Always, Clap.PossibleValue.make("always")->Clap.PossibleValue.help("Always colour the output")),
  (
    Never,
    Clap.PossibleValue.make("never")
    ->Clap.PossibleValue.help("Never colour the output")
    ->Clap.PossibleValue.alias("off"),
  ),
  (
    Auto,
    Clap.PossibleValue.make("auto")->Clap.PossibleValue.help(
      "Colour the output when stdout is a terminal",
    ),
  ),
])

/** Rust's `u8` with clap's ranged parser messages. */
let u8ValueParser = Clap.ValueParser.make(
  input =>
    switch Clap.ValueParser.parse(Clap.ValueParser.int, input) {
    | Ok(value) if value >= 0 && value <= 255 => Ok(value)
    | Ok(value) => Error(`${Int.toString(value)} is not in 0..=255`)
    | Error(reason) => Error(reason)
    },
  value => Int.toString(value),
)

let command =
  Clap.Command.make("greet")
  ->Clap.Command.version("1.0.0")
  ->Clap.Command.about("Simple program to greet a person")
  ->Clap.Command.longAbout(
    "Simple program to greet a person\n\nGreets NAME a number of times. This second paragraph only appears in the long help (`--help`), as clap's `long_about`.",
  )
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
    ->Clap.Arg.valueParser(u8ValueParser)
    ->Clap.Arg.defaultValue(u8ValueParser, 1)
    ->Clap.Arg.short("c")
    ->Clap.Arg.long("count")
    ->Clap.Arg.help("Number of times to greet"),
  )
  ->Clap.Command.arg(
    Clap.Arg.make("verbose")
    ->Clap.Arg.action(Count)
    ->Clap.Arg.short("v")
    ->Clap.Arg.help("Increase verbosity"),
  )
  ->Clap.Command.arg(
    Clap.Arg.make("greeting")
    ->Clap.Arg.valueName("GREETING")
    ->Clap.Arg.help("Greeting to use instead of \"Hello\""),
  )
  ->Clap.Command.arg(
    Clap.Arg.make("tag")
    ->Clap.Arg.valueName("TAG")
    ->Clap.Arg.action(Append)
    ->Clap.Arg.short("t")
    ->Clap.Arg.long("tag")
    ->Clap.Arg.help("Tag to attach (repeatable)"),
  )
  ->Clap.Command.arg(
    Clap.Arg.make("lang")
    ->Clap.Arg.valueName("LANG")
    ->Clap.Arg.long("lang")
    ->Clap.Arg.env("GREET_LANG")
    ->Clap.Arg.help("Language of the greeting"),
  )
  ->Clap.Command.arg(
    Clap.Arg.make("color")
    ->Clap.Arg.valueName("COLOR")
    ->Clap.Arg.valueParser(colorValueParser)
    ->Clap.Arg.defaultValue(colorValueParser, Auto)
    ->Clap.Arg.long("color")
    ->Clap.Arg.help("Colour of the output"),
  )
  ->Clap.Command.arg(
    Clap.Arg.make("offset")
    ->Clap.Arg.valueName("OFFSET")
    ->Clap.Arg.valueParser(Clap.ValueParser.int)
    ->Clap.Arg.defaultValue(Clap.ValueParser.int, 0)
    ->Clap.Arg.long("offset")
    ->Clap.Arg.help("Offset added to the count"),
  )
  ->Clap.Command.arg(
    Clap.Arg.make("secret")
    ->Clap.Arg.valueName("SECRET")
    ->Clap.Arg.long("secret")
    ->Clap.Arg.hide
    ->Clap.Arg.help("Internal option, hidden from help"),
  )
  ->Clap.Command.arg(
    Clap.Arg.make("shout")
    ->Clap.Arg.action(SetTrue)
    ->Clap.Arg.short("s")
    ->Clap.Arg.long("shout")
    ->Clap.Arg.help("Shout the greeting")
    ->Clap.Arg.longHelp(
      "Shout the greeting.\n\nPrints the greeting in upper case and appends an exclamation mark. Only `--help` shows this paragraph.",
    ),
  )
