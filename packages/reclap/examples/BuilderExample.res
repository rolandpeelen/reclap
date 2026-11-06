// The same shape as GreetExample, written against the builder API with no
// `@clap` attributes.
//
// Run with: node examples/BuilderExample.res.mjs --help
//           node examples/BuilderExample.res.mjs --name Ann -c 2

type t = {
  name: string,
  count: int,
}

let args: Clap.Args.t<t> = Clap.Args.make(
  command =>
    command
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
      ->Clap.Arg.valueParser(Clap.ValueParser.int)
      ->Clap.Arg.defaultValue(Clap.ValueParser.int, 1)
      ->Clap.Arg.short("c")
      ->Clap.Arg.long("count")
      ->Clap.Arg.help("Number of times to greet"),
    ),
  matches =>
    switch Clap.Matches.getRequired(matches, "name", Clap.ValueParser.string) {
    | Error(error) => Error(error)
    | Ok(name) =>
      switch Clap.Matches.getRequired(matches, "count", Clap.ValueParser.int) {
      | Error(error) => Error(error)
      | Ok(count) => Ok({name, count})
      }
    },
)

let parser = Clap.Parser.fromArgs(
  Clap.Command.make("hello")
  ->Clap.Command.version("1.0.0")
  ->Clap.Command.about("Simple program to greet a person"),
  args,
)

let parsed = Clap.parse(parser)

for _ in 1 to parsed.count {
  Console.log(`Hello ${parsed.name}!`)
}
