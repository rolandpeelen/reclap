// Run with: node examples/GreetExample.res.mjs --name Ann -c 2

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
