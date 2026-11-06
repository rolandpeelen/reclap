/*** Typed bindings to the parts of Node's `process` global that the runtime uses. */

type writable

@val @scope("process") external argv: array<string> = "argv"
@val @scope("process") external env: Dict.t<string> = "env"
@val @scope("process") external exit: int => 'a = "exit"
@val @scope("process") external stdout: writable = "stdout"
@val @scope("process") external stderr: writable = "stderr"
@send external write: (writable, string) => bool = "write"
