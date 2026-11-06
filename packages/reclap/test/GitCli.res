/*** The `git` CLI of `reference/clap-fixtures/src/bin/git.rs`, written with the builder API
as the derive would generate it. */

let positional = (id, ~valueName, ~help) =>
  Clap.Arg.make(id)->Clap.Arg.valueName(valueName)->Clap.Arg.help(help)

let clone =
  Clap.Command.make("clone")
  ->Clap.Command.about("Clone a repository into a new directory")
  ->Clap.Command.longAbout(
    "Clone a repository into a new directory.\n\nClones a repository into a newly created directory and creates remote-tracking branches for each branch in the cloned repository.",
  )
  ->Clap.Command.arg(
    positional(
      "remote",
      ~valueName="REMOTE",
      ~help="The repository to clone from",
    )->Clap.Arg.required(true),
  )
  ->Clap.Command.arg(
    positional("directory", ~valueName="DIRECTORY", ~help="The directory to clone into"),
  )
  ->Clap.Command.arg(
    Clap.Arg.make("depth")
    ->Clap.Arg.valueName("DEPTH")
    ->Clap.Arg.valueParser(Clap.ValueParser.int)
    ->Clap.Arg.long("depth")
    ->Clap.Arg.help("Create a shallow clone with this many commits"),
  )

let add =
  Clap.Command.make("add")
  ->Clap.Command.about("Add file contents to the index")
  ->Clap.Command.arg(
    Clap.Arg.make("dry_run")
    ->Clap.Arg.action(SetTrue)
    ->Clap.Arg.short("n")
    ->Clap.Arg.long("dry-run")
    ->Clap.Arg.help("Don't actually add the files"),
  )
  ->Clap.Command.arg(
    positional("paths", ~valueName="PATHS", ~help="Files to add content from")->Clap.Arg.action(
      Append,
    ),
  )

let commit =
  Clap.Command.make("commit")
  ->Clap.Command.about("Record changes to the repository")
  ->Clap.Command.visibleAlias("ci")
  ->Clap.Command.arg(
    Clap.Arg.make("message")
    ->Clap.Arg.valueName("MESSAGE")
    ->Clap.Arg.required(true)
    ->Clap.Arg.short("m")
    ->Clap.Arg.long("message")
    ->Clap.Arg.help("Use the given message as the commit message"),
  )
  ->Clap.Command.arg(
    Clap.Arg.make("all")
    ->Clap.Arg.action(SetTrue)
    ->Clap.Arg.short("a")
    ->Clap.Arg.long("all")
    ->Clap.Arg.help("Stage all modified files first"),
  )

let remote =
  Clap.Command.make("remote")
  ->Clap.Command.about("Manage the set of tracked repositories")
  ->Clap.Command.arg(
    Clap.Arg.make("verbose")
    ->Clap.Arg.action(SetTrue)
    ->Clap.Arg.short("v")
    ->Clap.Arg.long("verbose")
    ->Clap.Arg.help("Show remote URLs"),
  )
  ->Clap.Command.subcommand(
    Clap.Command.make("add")
    ->Clap.Command.about("Add a remote named NAME for the repository at URL")
    ->Clap.Command.arg(
      positional("name", ~valueName="NAME", ~help="Name of the remote")->Clap.Arg.required(true),
    )
    ->Clap.Command.arg(
      positional("url", ~valueName="URL", ~help="URL of the remote")->Clap.Arg.required(true),
    ),
  )
  ->Clap.Command.subcommand(
    Clap.Command.make("remove")
    ->Clap.Command.about("Remove the remote named NAME")
    ->Clap.Command.alias("rm")
    ->Clap.Command.arg(
      positional("name", ~valueName="NAME", ~help="Name of the remote")->Clap.Arg.required(true),
    ),
  )

let stash =
  Clap.Command.make("stash")
  ->Clap.Command.about("Stash the changes in a dirty working directory")
  ->Clap.Command.subcommand(
    Clap.Command.make("push")
    ->Clap.Command.about("Save local modifications to a new stash entry")
    ->Clap.Command.arg(
      Clap.Arg.make("message")
      ->Clap.Arg.valueName("MESSAGE")
      ->Clap.Arg.short("m")
      ->Clap.Arg.long("message")
      ->Clap.Arg.help("Stash message"),
    ),
  )
  ->Clap.Command.subcommand(
    Clap.Command.make("pop")
    ->Clap.Command.about("Remove a stash entry and apply it")
    ->Clap.Command.arg(Clap.Arg.make("index")->Clap.Arg.action(SetTrue)->Clap.Arg.long("index")),
  )
  ->Clap.Command.subcommandRequired(true)
  ->Clap.Command.argRequiredElseHelp(true)

let rm =
  Clap.Command.make("rm")
  ->Clap.Command.about("Remove files from the working tree and the index")
  ->Clap.Command.arg(
    positional("files", ~valueName="FILES", ~help="Files to remove")->Clap.Arg.action(Append),
  )

let command =
  Clap.Command.make("git")
  ->Clap.Command.version("2.0.0")
  ->Clap.Command.about("A fictional version control system")
  ->Clap.Command.arg(
    Clap.Arg.make("directory")
    ->Clap.Arg.valueName("PATH")
    ->Clap.Arg.short("C")
    ->Clap.Arg.help("Run as if started in PATH"),
  )
  ->Clap.Command.arg(
    Clap.Arg.make("quiet")
    ->Clap.Arg.action(SetTrue)
    ->Clap.Arg.short("q")
    ->Clap.Arg.long("quiet")
    ->Clap.Arg.help("Suppress output"),
  )
  ->Clap.Command.subcommand(clone)
  ->Clap.Command.subcommand(add)
  ->Clap.Command.subcommand(
    Clap.Command.make("status")
    ->Clap.Command.about("Show the working tree status")
    ->Clap.Command.alias("st"),
  )
  ->Clap.Command.subcommand(commit)
  ->Clap.Command.subcommand(remote)
  ->Clap.Command.subcommand(stash)
  ->Clap.Command.subcommand(Clap.Command.make("gc"))
  ->Clap.Command.subcommand(rm)
  ->Clap.Command.subcommandRequired(true)
  ->Clap.Command.argRequiredElseHelp(true)
