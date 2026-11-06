/*** Typed bindings to the parts of Vitest that the tests use. */

type expectation<'value>

@module("vitest") external describe: (string, unit => unit) => unit = "describe"
@module("vitest") external test: (string, unit => unit) => unit = "test"
@module("vitest") external expect: 'value => expectation<'value> = "expect"
@send external toBe: (expectation<'value>, 'value) => unit = "toBe"
@send external toEqual: (expectation<'value>, 'value) => unit = "toEqual"
