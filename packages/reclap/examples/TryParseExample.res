// `Clap.parse` prints and exits. `Clap.tryParseFrom` returns the value or the
// error, which is what tests and embedded parsers want. The first element of
// `argv` is the program name. `~env` replaces `process.env`.
//
// Run with: node examples/TryParseExample.res.mjs

/** Simple program to greet a person */
@clap.parser @command({name: "greet", version: "1.0.0"})
type t = {
  /** Name of the person to greet */
  @arg({short, long}) name: string,
  /** Number of times to greet */
  @arg({short, long, default: 1}) count: int,
}

let show = argv =>
  switch Clap.tryParseFrom(parser, argv, ~env=Dict.make()) {
  | Ok(args) => Console.log(`Ok: ${args.name} x${Int.toString(args.count)}`)
  | Error(error) =>
    Console.log(`exit ${Int.toString(Clap.Error.exitCode(error))}`)
    Console.log(Clap.Error.render(error)->String.trimEnd)
  }

show(["greet", "--name", "Ann", "-c", "2"])
show(["greet", "--nme", "Ann"])
show(["greet", "--help"])
