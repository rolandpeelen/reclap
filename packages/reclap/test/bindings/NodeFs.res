/*** Typed bindings to `node:fs`. */

@module("node:fs") external readFileUtf8: (string, @as("utf8") _) => string = "readFileSync"
