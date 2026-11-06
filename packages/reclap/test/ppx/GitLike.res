// Nested subcommands, inline records, newtype variants, an optional
// subcommand, a mutually recursive type group and a nested module.

module Remote = {
  @clap.args
  type addArgs = {
    /** Name of the remote */
    name: string,
    /** URL of the remote */
    url: string,
  }

  /** Manage remotes */
  @clap.subcommand
  type t =
    /** Adds a remote */
    | Add(addArgs)
    /** Removes a remote */
    | @command({alias: "rm", visibleAlias: "delete"}) Remove({name: string})
    /** Lists remotes */
    | @command({aliases: ["l"], visibleAliases: ["ls"]}) List({@arg({short, long}) verbose: bool})
}

@clap.parser @command({about: "A fictional version control system", author: "reclap"})
type rec t = {
  @arg({short: "C", long: "directory", valueName: "PATH"}) dir: option<string>,
  @command(subcommand) command: command,
}
@clap.subcommand
and command =
  /** Clones repos

  Clones a repository into a new directory. The directory is named after
  the repository unless you pass one.

  Shallow clones are supported. */
  | Clone({
      /** The remote to clone */
      remote: string,
      @arg({long, default: 1}) depth: int,
      dir: option<string>,
    })
  /** Shows the working tree status */
  | Status
  /** Adds things */
  | Add(addArgs)
  /** Manages remotes */
  | @command(subcommand) Remote(Remote.t)
  /** Stashes changes */
  | @command(subcommand) Stash(option<stash>)
  | @command({name: "secret", hide}) Hidden
@clap.args
and addArgs = {
  /** Files to add */
  paths: array<string>,
  @arg({short, long}) force: bool,
}
@clap.subcommand
and stash =
  Push({@arg({short, long}) message: option<string>}) | Pop | Apply({stash: option<string>})

let run = argv => Clap.tryParseFrom(parser, argv)
