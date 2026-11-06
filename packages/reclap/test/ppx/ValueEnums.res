// @clap.valueEnum variants and the value parsers that fields pick for them.

module Level = {
  @clap.valueEnum
  type t =
    /** Everything */
    | Debug
    /** Normal output.

    Long text is not used for values. */
    | Info
    | @value({name: "warn", alias: "warning"}) Warning
    | @value({aliases: ["err", "e"], help: "Only errors"}) Error
    | @value({hide}) Trace
    | @value({skip}) Internal
}

@clap.valueEnum @value({renameAll: "SCREAMING_SNAKE_CASE"})
type colorChoice = Always | AutoDetect | Never

@clap.valueEnum @value({renameAll: "verbatim"})
type format = JsonLines | PlainText

let percent: Clap.ValueParser.t<int> = Clap.ValueParser.make(
  raw =>
    switch Int.fromString(raw) {
    | Some(n) if n >= 0 && n <= 100 => Ok(n)
    | Some(_) | None => Error("not a percentage")
    },
  n => Int.toString(n),
)

@clap.parser
type options = {
  @arg({long, default: Level.Info}) level: Level.t,
  @arg({long}) color: option<colorChoice>,
  @arg({long, default: [JsonLines]}) formats: array<format>,
  @arg({long, valueParser: percent}) quality: int,
  @arg({long, action: Set}) dryRun: bool,
  @arg({long}) ratio: option<float>,
}

let run = argv => Clap.tryParseFrom(optionsParser, argv)
