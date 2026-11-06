/*** Replays the clap 4.6.7 golden fixtures through the builder-API definitions of the same
CLIs and compares the exit code, stdout and stderr. */

let replayCommand = (fileName, command: Clap.Command.t) =>
  FixtureReplay.replay(fileName, ~programName=command.name, (argv, env) =>
    Clap.getMatchesFrom(command, argv, ~env)
  )

replayCommand("greet.json", GreetCli.command)
replayCommand("git.json", GitCli.command)

FixtureReplay.replay("edge.json", ~programName=EdgeCli.command.name, (argv, env) =>
  Clap.getMatchesFrom(EdgeCli.command, argv, ~env)
)
FixtureReplay.replayParsedValues(
  "edge.json",
  ~programName=EdgeCli.command.name,
  (argv, env) => Clap.getMatchesFrom(EdgeCli.command, argv, ~env),
  EdgeCli.dump,
)
