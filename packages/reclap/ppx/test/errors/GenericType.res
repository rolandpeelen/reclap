// expect: @clap types cannot have type parameters.
// line: 4
@clap.args
type t<'a> = {name: string}
