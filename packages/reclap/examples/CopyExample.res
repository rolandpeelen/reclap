// Run with: node examples/CopyExample.res.mjs --help
//           node examples/CopyExample.res.mjs -n -vv src/a.txt src/b.txt --dest out
//           COPY_DEST=out node examples/CopyExample.res.mjs src/a.txt

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

let args = Clap.parse(parser)
let files = Array.concat([args.source], args.more)

let action = if args.dryRun {
  "would copy"
} else if args.force {
  "copy (overwrite)"
} else {
  "copy"
}

if args.verbose == 0 {
  Console.log(`${action} ${Int.toString(files->Array.length)} file(s) -> ${args.destination}`)
} else {
  files->Array.forEach(file => Console.log(`${action} ${file} -> ${args.destination}`))
  if args.verbose > 1 {
    Console.log(`${Int.toString(files->Array.length)} file(s)`)
  }
}
