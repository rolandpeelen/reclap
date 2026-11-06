// expect: Optional record fields (`name?: ...`) are not supported. Use `name: option<...>`
// line: 5
@clap.args
type t = {
  name?: string,
}
