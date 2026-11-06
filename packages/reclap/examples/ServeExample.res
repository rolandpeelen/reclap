// Run with: node examples/ServeExample.res.mjs --help
//           node examples/ServeExample.res.mjs --root ./public -p 3000 --level debug
//           PORT=3000 node examples/ServeExample.res.mjs --no-color -H "Cache-Control: no-store"

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

let args = Clap.parse(parser)
let Port(port) = args.port
let headers = switch args.header {
| None => ""
| Some(headers) => ` [${headers->Array.join(", ")}]`
}
let color = args.color ? "color" : "plain"
Console.log(
  `serve ${args.root} on :${Int.toString(port)} (${describeLevel(args.level)}, ${color})${headers}`,
)
