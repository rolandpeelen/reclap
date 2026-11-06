// @clap.parser on a variant: the subcommands are the program's subcommands.

@clap.parser @command({version: "2.0.0"})
type tool =
  /** Builds the project */
  | Build({@arg(long) release: bool, @arg({short, long}) jobs: option<int>})
  /** Runs the tests */
  | Test({filter: option<string>})

let run = argv => Clap.tryParseFrom(toolParser, argv)
