/*** Why parsing stopped. Mirrors `clap::Error` and its `ErrorKind`.

Help and version requests are errors too, as in clap: they stop parsing,
print to stdout and exit with code 0. */

/** The command that failed, for usage lines in messages. */
type context = {
  /** The command names from the program to the failing subcommand, such as `["git", "add"]`. */
  path: array<string>,
  /** The usage line of the failing command, without the `Usage: ` prefix. */
  usage: string,
}

type t =
  | DisplayHelp({output: string})
  | DisplayVersion({output: string})
  | DisplayHelpOnMissingArgumentOrSubcommand({output: string})
  | UnknownArgument({context: context, argument: string, suggestion: option<string>})
  | InvalidSubcommand({context: context, name: string, suggestion: option<string>})
  | InvalidValue({
      context: context,
      argument: string,
      value: string,
      reason: string,
      possibleValues: array<string>,
      suggestion: option<string>,
    })
  | MissingValue({context: context, argument: string})
  | UnexpectedValue({context: context, argument: string, value: string})
  | MissingRequiredArguments({context: context, arguments: array<string>})
  | MissingSubcommand({context: context, name: string, subcommands: array<string>})
  | UsedMultipleTimes({context: context, argument: string})

/** Renders the message exactly as clap prints it, including `error: ` and the `For more information` footer. */
let render: t => string

/** Returns 0 for help and version requests and 2 for every other error, as clap does. */
let exitCode: t => int

/** Returns whether the message belongs on stderr. Help and version requests print to stdout. */
let usesStderr: t => bool

/** Prints the rendered message to stdout or stderr and exits the process with `exitCode`. */
let exit: t => 'a
