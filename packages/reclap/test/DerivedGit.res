/*** The `git` CLI of `reference/clap-fixtures/src/bin/git.rs`, derived from types with the
`@clap.*` attributes. The types are one recursive group so that they keep the order of the
Rust source. */

/** A fictional version control system */
@clap.parser @command({name: "git", version: "2.0.0"})
type rec t = {
  @command(flatten) global: globalOpts,
  /** Required subcommand */
  @command(subcommand) command: commands,
}
@clap.args
and globalOpts = {
  /** Run as if started in PATH */
  @arg({short: "C", valueName: "PATH"}) directory: option<string>,
  /** Suppress output */
  @arg({short, long}) quiet: bool,
}
@clap.subcommand
and commands =
  /** Clone a repository into a new directory.

  Clones a repository into a newly created directory and creates
  remote-tracking branches for each branch in the cloned repository. */
  | Clone({
      /** The repository to clone from */
      remote: string,
      /** The directory to clone into */
      directory: option<string>,
      /** Create a shallow clone with this many commits */
      @arg(long) depth: option<int>,
      /** Check out this branch instead of the remote's HEAD */
      @arg({long, id: "branch_name"}) branch: option<string>,
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
  | Remote({
      /** Show remote URLs */
      @arg({short, long}) verbose: bool,
      @command(subcommand) command: option<remoteCommands>,
    })
  /** Stash the changes in a dirty working directory */
  | @command(subcommand) Stash(stashCommands)
  | Gc
  /** Remove files from the working tree and the index */
  | Rm({
      /** Files to remove */
      files: array<string>,
    })
@clap.args
and addArgs = {
  /** Don't actually add the files */
  @arg({short: "n", long}) dryRun: bool,
  /** Files to add content from */
  paths: array<string>,
}
@clap.subcommand
and remoteCommands =
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
@clap.subcommand
and stashCommands =
  /** Save local modifications to a new stash entry */
  | Push({
      /** Stash message */
      @arg({short, long}) message: option<string>,
    })
  /** Remove a stash entry and apply it */
  | Pop({@arg(long) index: bool})
