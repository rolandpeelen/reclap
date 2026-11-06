// @command({flatten}), skip, env, renaming, actions and help texts.

@clap.args @command({renameAll: "snake_case", renameAllEnv: "kebab-case"})
type common = {
  /** Print more output */
  @arg({short, long, action: Count}) verbose: int,
  /** Disable colors */
  @arg({long: "no-color", action: SetFalse}) colorEnabled: bool,
  @arg({long, env}) configFile: option<string>,
}

/** Runs a job

The job runs until it finishes or `--timeout` passes. */
@clap.parser @command({name: "job-runner", version: "0.1.0", longAbout: "Explicit long about"})
type t = {
  @command({flatten}) common: common,
  /** Seconds before the job is killed.

  Zero means no timeout. */
  @arg({long, env: "JOB_TIMEOUT", default: 30, help: "Timeout in seconds"}) timeout: int,
  @arg({long, id: "job-tags", valueName: "TAG", alias: "tag", aliases: ["t"], visibleAliases: ["label", "labels"]}) tags: option<array<string>>,
  @arg({long, required: false, hide}) token: string,
  @arg({long, longHelp: "Only for debugging."}) trace: bool,
  @arg({skip: 42}) attempts: int,
  @arg({skip: []}) history: array<string>,
  /** Input files... */
  inputs: array<string>,
  /** The job to run */
  job: string,
}

let run = argv => Clap.tryParseFrom(parser, argv)
