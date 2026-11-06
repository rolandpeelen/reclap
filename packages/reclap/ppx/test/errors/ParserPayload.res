// expect: @clap.parser takes no payload. Put options in @command({...}).
// line: 3
@clap.parser({version: "1"})
type t = {name: string}
