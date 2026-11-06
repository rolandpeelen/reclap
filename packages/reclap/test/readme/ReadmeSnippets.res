// The snippets in README.md, compiled so the README cannot drift.
// Programs that call Clap.parse live in packages/reclap/examples and are not
// repeated here: loading one would exit the process.

module Greet = {
  /** Simple program to greet a person */
  @clap.parser @command({name: "greet", version: "1.0.0"})
  type t = {
    /** Name of the person to greet */
    @arg({short, long}) name: string,
    /** Number of times to greet */
    @arg({short, long, default: 1}) count: int,
  }
}

module Copy = {
  /** Copy files into a directory */
  @clap.parser @command({name: "copy", version: "0.2.0"})
  type t = {
    /** Overwrite files that already exist */
    @arg({short, long}) force: bool,
    /** Print the plan and do not write */
    @arg({short: "n", long}) dryRun: bool,
    /** Directory to copy into */
    @arg({short, long, visibleAlias: "dest", env: "COPY_DEST"}) destination: string,
    /** Print each path. Repeat for more detail */
    @arg({short, action: Count}) verbose: int,
    /** File to copy */
    source: string,
    /** Further files to copy */
    more: array<string>,
  }
}

module Serve = {
  module Level = {
    @clap.valueEnum
    type t =
      /** Only errors */
      | Error
      /** Normal output */
      | @value({alias: "normal"}) Info
      /** Everything */
      | Debug
  }

  type port = Port(int)

  let portValueParser = Clap.ValueParser.make(
    text =>
      switch Int.fromString(text) {
      | Some(number) if number > 0 && number < 65536 => Ok(Port(number))
      | Some(_) | None => Error("not a port number")
      },
    (Port(number)) => Int.toString(number),
  )

  /** Serve files from a directory */
  @clap.parser @command({name: "serve", version: "0.4.0"})
  type t = {
    /** Directory to serve */
    @arg({long, default: "."}) root: string,
    /** Port to listen on */
    @arg({short, long, env, default: Port(8080)}) port: port,
    /** How much to print */
    @arg({long, default: Level.Info}) level: Level.t,
    /** Response header, as `Name: value`. Repeat the flag to set more than one */
    @arg({short: "H", long}) header: option<array<string>>,
    /** Colour log output */
    @arg({long: "no-color", action: SetFalse}) color: bool,
  }

  let describeLevel = level =>
    switch level {
    | Level.Error => "error"
    | Level.Info => "info"
    | Level.Debug => "debug"
    }
}

module Job = {
  // Inlined into the parser below with @command(flatten).
  @clap.args
  type common = {
    /** Print more about what happens */
    @arg({short, action: Count}) verbose: int,
    /** Config file to read */
    @arg({long, env: "JOB_CONFIG"}) config: option<string>,
  }

  /** Run one job to completion

  The job stops when it finishes or when `--timeout` elapses. */
  @clap.parser @command({name: "job", version: "0.3.0"})
  type t = {
    @command(flatten) common: common,
    /** Seconds to wait before stopping.

    Zero waits forever. */
    @arg({long, default: 30}) timeout: int,
    /** Name of the job to run */
    name: string,
  }
}

module Git = {
  @clap.args
  type addArgs = {
    /** Don't actually add the files */
    @arg({short: "n", long}) dryRun: bool,
    /** Files to add content from */
    paths: array<string>,
  }

  @clap.subcommand
  type remote =
    /** Add a remote named NAME for the repository at URL */
    | Add({
        /** Name of the remote */
        name: string,
        /** URL of the remote */
        url: string,
      })
    /** Remove the remote named NAME */
    | @command({alias: "rm"})
    Remove({
        /** Name of the remote */
        name: string,
      })

  @clap.valueEnum
  type color =
    /** Always colour the output */
    | Always
    /** Never colour the output */
    | @value({alias: "off"}) Never
    /** Colour the output when stdout is a terminal */
    | Auto

  @clap.subcommand
  type command =
    /** Clone a repository into a new directory */
    | Clone({
        /** The repository to clone from */
        remote: string,
        /** Create a shallow clone with this many commits */
        @arg(long) depth: option<int>,
      })
    /** Add file contents to the index */
    | Add(addArgs)
    /** Show the working tree status */
    | @command({alias: "st"}) Status
    /** Record changes to the repository */
    | @command({visibleAlias: "ci"})
    Commit({
        /** Use the given message as the commit message */
        @arg({short, long}) message: string,
        /** Stage all modified files first */
        @arg({short, long}) all: bool,
      })
    /** Manage the set of tracked repositories */
    | @command(subcommand) Remote(option<remote>)

  /** A fictional version control system */
  @clap.parser @command({name: "git", version: "2.0.0"})
  type t = {
    /** Suppress output */
    @arg({short, long}) quiet: bool,
    /** When to colour the output */
    @arg({long, default: Auto}) color: color,
    @command(subcommand) command: command,
  }
}

module TryParse = {
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
}

module Builder = {
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

  let parsed = Clap.tryParseFrom(parser, ["hello", "--name", "Ann", "-c", "2"], ~env=Dict.make())
}
