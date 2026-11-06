/*** The command line parser behind `Clap.getMatchesFrom`. Mirrors clap 4's `Parser` and
`Validator` for the features reclap supports. Internal to reclap. */

/** Parses `argv` against `command`. The first element of `argv` is the program name and is
ignored. `env` supplies environment variables for `ClapArg.env`.

**Errors**: every `ClapError.t` case; help and version requests are errors too, as in clap. */
let getMatchesFrom: (
  ClapCommand.t,
  array<string>,
  ~env: Dict.t<string>,
) => result<ClapMatches.t, ClapError.t>
