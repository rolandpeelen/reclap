// Run with: node examples/GitExample.res.mjs --help
//           node examples/GitExample.res.mjs add -n a.txt b.txt
//           node examples/GitExample.res.mjs remote add origin https://example.com/repo

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

let describe = command =>
  switch command {
  | Clone({remote, depth: None}) => `clone ${remote}`
  | Clone({remote, depth: Some(depth)}) => `clone ${remote} (depth ${Int.toString(depth)})`
  | Add({dryRun, paths}) => `add ${paths->Array.join(" ")}${dryRun ? " (dry run)" : ""}`
  | Status => "status"
  | Commit({message, all}) => `commit${all ? " -a" : ""}: ${message}`
  | Remote(None) => "list remotes"
  | Remote(Some(Add({name, url}))) => `add remote ${name} -> ${url}`
  | Remote(Some(Remove({name}))) => `remove remote ${name}`
  }

let args = Clap.parse(parser)
if !args.quiet {
  Console.log(describe(args.command))
}
