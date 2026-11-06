// Run with: node examples/JobExample.res.mjs --help
//           node examples/JobExample.res.mjs nightly --timeout 0 -vv
//           JOB_CONFIG=job.toml node examples/JobExample.res.mjs migrate

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

let args = Clap.parse(parser)
let config = switch args.common.config {
| Some(path) => ` config=${path}`
| None => ""
}
Console.log(
  `job ${args.name} timeout=${Int.toString(args.timeout)} verbose=${Int.toString(
      args.common.verbose,
    )}${config}`,
)
