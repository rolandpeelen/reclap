// Defaults that only look like skipped values: the PPX must resolve the
// value type the way the compiler does, so these all compile.

@clap.valueEnum
type mode =
  | Fast
  | @value(skip) Slow

module Inner = {
  // A plain type shadows the outer value enum: `Slow` is a normal value here.
  type mode = Fast | Slow

  let modeValueParser = Clap.ValueParser.make(
    (input): result<mode, string> =>
      switch input {
      | "fast" => Ok(Fast)
      | "slow" => Ok(Slow)
      | _ => Error("invalid value")
      },
    (mode: mode) =>
      switch mode {
      | Fast => "fast"
      | Slow => "slow"
      },
  )

  @clap.args
  type t = {@arg({long, default: Slow}) mode: mode}
}

@clap.valueEnum
type speed = Quick | Steady

module Later = {
  // Uses the outer `speed`: the `speed` below, which skips `Steady`, is
  // declared after this record.
  @clap.args
  type t = {@arg({long, default: Steady}) speed: speed}

  @clap.valueEnum
  type speed = Quick | @value(skip) Steady
}
