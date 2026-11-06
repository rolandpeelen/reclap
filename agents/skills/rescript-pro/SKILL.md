---
name: rescript-pro
description: Opinionated rules for writing simple, explicit production ReScript with strong domain modeling, exhaustive pattern matching, pure reducers, typed effects, safe JavaScript interop, React view/store separation, and tests with Vitest and FastCheck. Use whenever writing, reviewing, refactoring, debugging, or testing ReScript code, especially types, state machines, async lifecycles, reducers, actions, effects, React components, APIs, bindings, unit tests, property-based tests, or code suffering from Boolean blindness or illegal states.
# Development skill for this repository; not for installation by users.
metadata:
  internal: true
---

# ReScript Style

Write ReScript as typed functional code, not JavaScript with different syntax. Prefer variants, pattern matching, immutable data, pure functions, and return values. Mutation, exceptions, first-class modules, functors, and unsafe interop are tools, not the default mode.

When in doubt, prefer the simpler thing. Make the domain obvious and invalid states difficult or impossible to construct.

Let repository instructions override generic guidance. Before changing code, read the repository instructions, relevant architecture documentation, and `rescript.json`; inspect nearby types and conventions; and reuse established abstractions such as async state, schema decoders, stores, and effect runners.

For domain work, read the shared [domain-modeling skill](../domain-modeling/SKILL.md)
and [the ReScript domain-modeling reference](references/state-modeling.md).
The shared skill defines the principles; the reference applies them to abstract
types, input boundaries, reducers, and effect ownership.

When syntax, standard-library APIs, JavaScript interop, React bindings, or build-system behavior need confirmation, start at the official [ReScript documentation for LLMs](https://rescript-lang.org/llms.txt) and load the narrowest relevant linked document. Treat the repository configuration and compiler output as authoritative for the version and packages the project actually uses.

## Tooling — non-negotiable

Run the repository's ReScript formatter, clean zero-warning build, and test
suite before considering a change done, with the commands the repository
documents.

Run relevant tests when the project has them. Do not substitute `npm`, `npx`, Prettier, or a generic formatter when the repository specifies another workflow. Never edit or commit generated `.res.mjs` files.

Treat compiler warnings as failures. Do not relax compiler settings or add a warning suppression to make a change pass. A narrowly targeted suppression is acceptable only when the warning is wrong for the specific case and an adjacent comment explains why.

Do not use any of these in production code:

- wildcard matches on variants you control;
- `%raw`;
- `Obj.magic` or type coercion;
- untyped external bindings;
- unchecked JSON access after the interop boundary.

Repair the model or the boundary instead of escaping the type system.

## Coding style

### 1. Keep control flow flat

Treat three indentation levels as the soft ceiling. At four, restructure with pattern destructuring, guarded switch arms, a tuple switch, or a named operation that owns a distinct responsibility.

Avoid `switch -> if -> switch` pyramids:

```rescript
let notify = userId =>
  switch lookup(userId) {
  | None => ()
  | Some(user) =>
    if user.active {
      switch user.email {
      | None => ()
      | Some(email) => send(email)
      }
    }
  }
```

Flatten the preconditions into explicit arms:

```rescript
let notify = userId =>
  switch lookup(userId) {
  | None => ()
  | Some(user) if !user.active => ()
  | Some({email: None}) => ()
  | Some({email: Some(email)}) => send(email)
  }
```

Make the shape on the page match the shape of the logic: a short sequence of cases followed by the work.

### 2. Put categorical dispatch in `switch`; use `if` for residual conditions

Dispatch variants, modes, statuses, and other closed categories with `switch`. Use a short guard when one constructor needs an additional condition, then follow it with an unguarded arm for the same constructor:

```rescript
switch status {
| Pending if canPromote() => promote()
| Pending => wait()
| Active => run()
| Closed => archive()
}
```

Do not bury the categorical decision inside chained conditionals. Keep guards short and local. If several arms repeat a guard or the guard contains real domain logic, name that decision or improve the model.

Match every constructor of a controlled variant, including intentional no-op transitions. Never end a state machine with `_ => state`; adding a constructor should produce useful compiler failures at every affected decision.

Use a wildcard only for a genuinely open or unbounded external domain, such as an exception boundary or arbitrary integer. Never use one to hide a case in a closed domain.

### 3. Keep mutation local and invisible

Treat records, variants, arrays, and collections as immutable values by default. Return a new value instead of changing state shared with callers.

Use local mutation only when an algorithm or interop API clearly requires it. Keep the mutable value inside one small function so the function remains pure from the caller's perspective. Do not expose mutable record fields, refs, or JavaScript objects whose correct use depends on call order such as `prepare()` before `run()`.

Building a collection is not such a case. Do not build an array with `Array.forEach` plus `Array.push`, or a lookup with `Dict.make` plus `Dict.set`, when `Array.map`, `Array.mapWithIndex`, `Array.reduce`, `Array.concat`, `Array.filterMap`, or `Map.fromArray` expresses the result.

```rescript
// Bad: mutation to express a map
let rows = []
messages->Array.forEachWithIndex((message, index) => rows->Array.push(toRow(message, index)))

// Good
let rows = messages->Array.mapWithIndex(toRow)
```

When ordering matters, model the phases as variants or separate types. In React, use reducer/store transitions or React state rather than mutating captured values.

### 4. Make illegal states unrepresentable

Use variants for mutually exclusive phases and modes. Use records for facts that vary independently. Put phase-specific data in the relevant variant payload.

Avoid Boolean blindness. A Boolean is appropriate only for a stable, independently meaningful yes/no fact such as `disabled` or `checked`. Replace it when `true` needs a comment, changes meaning over time, duplicates another field, or collapses more than two states.

Avoid flag soups:

```rescript
type request = {
  authenticated: bool,
  userId: option<userId>,
  apiKey: option<apiKey>,
}
```

Use a type in which every constructor means one valid thing:

```rescript
type request =
  | Anonymous
  | User(userId)
  | Service(apiKey)
```

Prefer a lifecycle such as this:

```rescript
type remoteData<'value, 'error> =
  | Initial
  | Loading
  | Refreshing('value)
  | Success('value)
  | Failure('error)
```

Do not replace it with `{data, loading, live, failed}`.

Do not overload absence or container values. `None` means absence, `[]` means a successfully known empty collection, and `""` means an empty string. If the domain means `UseDefault`, `NotLoaded`, or `Unavailable`, give it a constructor.

Before accepting a state type, ask:

1. What does each constructor or field mean in domain language?
2. Can the type represent contradictory phases or modes?
3. Is a Boolean encoding provenance, freshness, lifecycle, permission, or another multi-state concept?
4. Does a sentinel value secretly mean a named domain case?
5. Is stored state derived from other stored state and able to drift?
6. Does each field have the same lifetime and owner?

Read [state-modeling.md](references/state-modeling.md) when designing or reviewing application state, async resources, reducers, stores, effects, or React consumers.

### 5. Do not build inheritance-shaped module hierarchies

Use modules to group a type with its operations. Use module types to describe a real contract, and functors to build a genuinely repeated compile-time abstraction. Do not introduce module types, functors, or first-class modules merely to make ordinary code look architected.

For a closed set of implementations, prefer a variant and exhaustive dispatch. For a single behavior supplied by a caller, prefer a function argument. For a small runtime capability bundle, consider a typed record of functions. Call a concrete module directly when there is only one implementation.

A module abstraction must have more than one real consumer or implementation and must remove meaningful duplication or enforce a meaningful invariant. A hypothetical future implementation does not count. A project standard-library extension is the deliberate exception: the standard type provides the ownership boundary even when the missing generic operation is first discovered at one call site.

### 6. Use simple types and constructs until they stop being enough

Reach first for ordinary variants, records, tuples, `option`, `result`, arrays, lists, modules, and functions.

Reuse an established generic component before reconstructing its lower-level
implementation. When its typed configuration already expresses the required
behavior, specialize it to presentation data instead of bypassing it. For
example, a generic picker that supports disabled entries can render an empty
state without introducing a domain value:

```rescript
<GenericPicker
  items=["Nothing available"]
  selected="Nothing available"
  key={message => message}
  render={message => message}
  isDisabled={_ => true}
  onChange={_ => ()}
/>
```

Prefer this reuse over rebuilding the same behavior from lower-level bindings.
Drop to the lower layer only when the established component cannot express the
required behavior or semantics.

Treat these as design smells when they appear reflexively:

| Smell | Ask first |
| --- | --- |
| Polymorphic variants in application-domain state | Is this a closed domain that should use an ordinary variant? Reserve polymorphic variants mainly for tight interop or genuinely open rows. |
| First-class modules | Would a direct module, function argument, or typed record of functions be clearer? |
| A functor with one instantiation | Is compile-time generic construction earning its complexity? |
| `JSON.t` beyond a decoder | Can the boundary decode once into a domain type? |
| A promise stored as application state | Should state describe the async lifecycle while the promise remains in the effect layer? |
| Mutable fields or refs | Can the function return the updated value? |
| An `option<bool>` | Are there actually three named domain cases? |
| A broad React context | Does this state have one owner, or has the context become ambient mutable state? |

Prefer ordinary variants over clever encodings and a concrete function over a speculative abstraction.

### 7. Keep functions cohesive, named, and mostly pure

- Give one function one cohesive job. Treat length as a prompt to inspect responsibilities, not a reason to split code.
- Pass dependencies and values as arguments instead of reading ambient mutable state.
- Keep side effects at the edges: use a pure core and a thin I/O shell.
- Return decisions as data instead of hiding them in callbacks.
- Keep one-use transition logic at its decision point when extracting it would hide the complete state change.
- Extract a helper only when it names a real decision, domain rule, or shared transformation that could drift.
- Do not add a wrapper that merely renames one field access or repackages one existing function.

Use names that reveal the domain decision. `reconcileSelection` earns its name; `getName` for `user.name` and `mapOpened` for a one-expression `Async.map` do not.

### 8. Keep domain data and its operations together

Put a domain type and the pure operations that define it in the same module. Avoid action-shaped modules such as `ScanInserter`, `RequestBuilder`, or `CardRenderer`, and avoid `Helpers` grab bags.

Prefer a domain module:

```rescript
module Scan = {
  type t = {
    repositoryId: repositoryId,
    baseRef: string,
    headSha: string,
  }

  let make = (~repositoryId, ~baseRef, ~headSha) => {
    repositoryId,
    baseRef,
    headSha,
  }

  let insert = (scan, repository) => Repository.insertScan(repository, scan)
  let summarize = (scan, repository) => Repository.summarizeScan(repository, scan)
}
```

Do not stutter the type at call sites: prefer `Scan.insert(scan, repository)` over `Scan.insertScan(scan, repository)`.

An accessor belongs to the type it reads. A function that returns one field or one derived value of a variant or record (`Message.turnId`, `Entry.turnId`) is defined in that type's module, next to the type, as the one `switch` over its constructors. Callers compare the result inline. Do not write a predicate in a component that switches over another module's variant (`belongsToTurn(message, turnId)`), and do not define the accessor in the consumer "near where it is used". When a type has no module yet, that is the signal to give it one.

```rescript
// Bad: a component owns a switch over Transcript's Message.t
let belongsToTurn = (message, turnId) =>
  switch message {
  | Request(id, _) | Response(id, _) | Notice(id, _) => id == turnId
  | ToolCall(id, _, _, _) => id == turnId
  }

// Good: Transcript.Message owns the accessor; the component compares
module Message = {
  type t = ...
  let turnId = message =>
    switch message {
    | Request(id, _) | Response(id, _) | Notice(id, _) | ToolCall(id, _, _, _) => id
    }
}
let rows = messages->Array.filter(message => Message.turnId(message) == turnId)
```

Let return values that are genuine domain nouns, such as `ScanSummary`, have their own types. Do not create a type or module whose existence is merely an action.

In feature-oriented projects, keep subcomponents and stores within the established feature structure. Use facade modules for external consumers, not for calls between sibling submodules when that would create cycles.

#### Hide owned representations with an abstract `type t`

Use a module signature with an abstract `type t` when one domain module must
own construction and representation access. An abstract type is also called an
opaque type. Define the concrete type only in the implementation:

```rescript
module Topic: {
  type t
  let make: (string, string) => t
  let get: t => string
  let getRoom: t => option<string>
} = {
  type t = string

  let make = (room, id): t => `${room}:${id}`
  let get = (topic: t) => topic
  let getRoom = (topic: t) => topic->String.split(":")->Array.get(0)
}
```

The implementation knows that `t` is a string. Consumers only know `Topic.t`.
They cannot construct one from an arbitrary string, coerce it to a string, or
inspect its representation. They must use `Topic.make` and the operations that
the signature exposes.

Use this boundary to enforce a concrete invariant or to prevent consumers from
depending on a representation. Do not add an abstract type only to rename a
primitive. The module can later replace the string with a record or variant if
each public operation keeps its contract.

An accessor that returns the complete representation still exposes that data.
Consumers can parse the string returned by `get`. Omit a general accessor when
the module must own all parsing. Prefer semantic names such as `getRoom`,
`toWireString`, and `toDisplayString` when the values have different purposes.
For example, `toDisplayString` can redact part of a user ID, but
`toWireString` must preserve the room identifier.

#### Split large reducers without hiding dispatch

When a reducer contains a cohesive nested domain, move that domain's `type t` and reusable pure operations into a `MainModule__SubModule.res` file. Alias the submodule near the top of the main module when the generated name is unwieldy, but keep its ownership explicit at every call site: prefer `ReviewState.ReviewIdle` and `Transcript.appendNotice` over unqualified constructors or functions.

Do not `include` a domain submodule into the reducer and do not re-export its constructors or operations through facade type or value aliases. Both obscure where behavior lives and make shadowing easier. Keep the reducer's one exhaustive action switch visible; the submodule should transform its own data, not become a hidden second reducer over a subtype.

#### Use the project standard library for generic vocabulary

Before adding a local helper for an array, option, result, string, or another standard type, check the current official ReScript documentation and the project's standard-library package. If ReScript does not provide the operation and it is independent of application domains, extend the project module that owns the standard type rather than scattering feature-local helpers.

When the project has such a package, preserve the underlying module with an include such as `include Stdlib.Array`, add the generic operation there, and call it through the owning module such as `items->Array.toggle(item)`.

Do not duplicate an operation ReScript already provides, redefine a standard operation with different semantics, or put application policy in the shared standard library. Keep domain-specific behavior inline or on the module that owns the domain type.

### 9. Treat expected failure as typed data

Use `result<'value, 'error>` when callers can recover, retry, render, test, or otherwise reason about failure. Use `option<'value>` only when absence is the complete and meaningful outcome.

Model error categories with a variant. Do not collapse branchable failures into `Error(string)` or a Boolean:

```rescript
type loadError =
  | Offline
  | Unauthorized
  | InvalidResponse(decodeError)
```

Keep display text at the presentation boundary. Preserve structured facts in the error value.

Normalize JavaScript exceptions and promise rejections at the interop or effect boundary. Domain reducers should receive `result`, not exception mechanics. Do not use exceptions for ordinary control flow.

Avoid unsafe extractors such as unchecked array access or nullable getters. When an invariant genuinely proves an unsafe operation valid, keep it in one small function and document the invariant adjacent to the operation.

Handle `option` and `result` explicitly. Do not silently replace failure with a default unless the domain defines that fallback.

### 10. Keep collection pipelines readable

Use `Array`, `List`, `Option`, and `Result` combinators when they express a short linear transformation. Stop chaining when the pipeline grows long, contains nested callbacks, repeats traversal, or hides branching. Name intermediate values or use an explicit loop or recursive function when that makes ownership and control flow clearer.

Do not extract one-use wrappers around standard combinators merely to shorten a pipeline. Extract a function when its name communicates a domain rule.

Prefer one traversal when it remains clear, but do not compress code into an opaque `reduce` to avoid two obvious passes. Clarity comes first; measure before optimizing.

Two passes that read the same data are one pass when the second only switches on the first's result: put the `switch` inside the `reduce`. When a loop needs a lookup per element (insertions by index, entries by id), build a keyed `Map` once before the loop; do not scan the source array for each element. Delete a branch whose arms all produce the same value as the fallback.

### 11. Comment why; document public contracts

Do not narrate syntax. Explain constraints, protocol decisions, external behavior, and invariants that the code cannot express.

Bad:

```rescript
// Increment the retry count.
let retryCount = retryCount + 1
```

Good:

```rescript
// The upstream returns 503 for roughly 30 seconds after deploys.
let retryCount = retryCount + 1
```

Use `.resi` files when a stable public module boundary benefits from an explicit interface.

Every exported function declared by a reusable library module has a `/** ... */`
doc comment. Repository instructions define the library boundary; inherited
declarations brought in with `include` keep their upstream documentation. Use
`/*** ... */` for standalone file or module documentation. Application
implementation functions do not need doc comments merely because the absence
of a `.resi` file makes them technically visible.

Place an attached doc comment immediately before its declaration. When a
standalone decorator such as `@@live` precedes the declaration, put the doc
comment after that decorator; the formatter otherwise treats it as unattached
and removes it.

Treat every doc comment as part of the caller-facing contract:

- Start with one third-person, present-tense summary sentence ending in a
  period. Add a blank line before details.
- Describe behavior, ordering, units, invariants, fallbacks, and meaningful
  return semantics. Do not restate the signature.
- For a function returning `result`, add an `**Errors**` section that names
  every expected failure condition. Document contract-valid exceptions,
  rejected promises, and unsafe preconditions just as explicitly.
- Describe parameters in prose by name. Do not add mechanical argument or
  return-value inventories.
- Put ReScript names in backticks and qualify them when ownership would
  otherwise be unclear. ReScript has no rustdoc-style checked intra-doc links.
- Add a Markdown example when the API is not self-evident. ReScript has no
  doctests, so behavior promised by an example must also be covered by an
  executable test when it is significant.
- Keep one honest line for a trivial contract. Do not pad documentation or
  document generated declarations and standard APIs inherited through
  `include`.

Doc comments explain what callers may rely on. Inline `//` comments explain
why the implementation has a non-obvious shape.

Do not explain by reference. A comment such as "Same hover-reveal copy affordance as `Markdown.SourceCode`" sends the reader to another file and states nothing. State the constraint here, or delete the comment. Do not add a comment that narrates what a change did ("now uses `mapWithIndex` instead of a loop"); the diff and the commit message carry that. Write each kept comment as complete sentences in plain language.

### 12. Spell out variable names

Do not use single-letter runtime variable names. Use `index`, `item`, `user`, `error`, and `result`, not `i`, `x`, `u`, `e`, and `r`.

Apply the rule to function parameters, callback parameters, pattern captures, loop bindings, and reducer accumulators. Prefer `context` over `ctx`, `request` over `req`, `response` over `resp`, `error` over `err`, and `index` over `idx`.

Apply the same rule to module names. A reader must know what a module is from its name alone: `SandboxRuntime`, not `Srt`; `ChildProcess`, not `Cp`.

Keep genuine terms of art such as `id`, `url`, `api`, `db`, and `ui`. Conventional generic type parameters such as `'a`, `'value`, and `'error` are also fine; prefer descriptive generic names once a signature has more than one non-obvious role.

Use `_` only for a deliberately ignored value. Use a named leading-underscore binding such as `_error` when the ignored value's role helps the reader.

Name functions with verbs. Name stable Boolean facts and predicates with forms such as `isOpen`, `hasAccess`, or `canRetry`; if the name cannot say exactly what `true` means, replace the Boolean with a variant.

Name a value for the domain fact it holds, not for a mechanism metaphor. `initialPrompt` and `pendingForkForEdit` say what the value is; `seed` and `composerSeed` say how someone imagined it flowing. Name a component for what it renders (`Spinner`), not for its slot (`Row`).

### 13. Declare before use and make module boundaries obvious

ReScript files read and compile top to bottom. Declare a value before code that uses it; do not create avoidable forward-reference or mutual-recursion structures.

Use this default order:

1. narrow `open` declarations and module aliases;
2. types and module types;
3. external bindings and constants;
4. small pure helpers, with callees above callers;
5. the public functions or component `make` that compose those helpers.

Keep related variant constructors and function definitions together. Prefer qualified module calls over a broad file-level `open` that makes names ambiguous. Put JavaScript bindings in their own file under the package's `bindings/` directory (see [Keep interop typed and narrow](#keep-interop-typed-and-narrow)), never in a nested module inside domain code.

Use `let rec` only for genuine recursion. If two functions are mutually recursive, verify that the model cannot be made clearer before using `and`.

## Application architecture

### Model async work honestly

- Represent an owned asynchronous resource with the project's async state type, commonly `Async.t<'value, 'error>`.
- Transition to `Loading` when the reducer starts the request, not when the response arrives.
- Make repeated initialization while `Loading` a deliberate no-op unless concurrent requests are part of the domain.
- Model retry and refresh semantics explicitly. Preserve stale successful data with `Refreshing(value)` when the project's type supports it; do not bolt on a `live` or `refreshing` Boolean.
- Treat an empty returned collection as success unless the API contract explicitly makes emptiness an error.
- Track request identity when stale responses can arrive out of order.

### Keep reducers authoritative

Let reducers own transitions, reconciliation, fallback, validity, selection, and persistence decisions. Keep `next(state, action)` pure and return the new state plus typed effects. Keep a one-use transition complete in its matching arm when extraction would only shorten the reducer and separate the reader from the state change.

Let views select state, render every relevant case, and dispatch user intent. Do not repair store state in `React.useEffect`, reconcile stale selections in components, or duplicate availability rules. Move corrective logic to the state producer.

Keep state with the owner whose lifetime matches the behavior. Centralize state that must survive navigation or be shared. Keep temporary presentation state local. Derive values with selectors instead of storing copies that can drift.

When doing work with reducers, don't return the raw return type `(state, [])` but rather use the helpers (`update(state)` / `update(state, ~sideEffect=...)` / `update(state, ~sideEffects=[...])`)

### Use an explicit effect protocol

Name effects after complete operations: `FetchModels`, `LoadUser`, `SavePreferences`. Avoid context-dependent names such as `Fetch`, `Load`, or `Run`.

For each fallible asynchronous effect:

1. Dispatch an operation action that changes state and emits the effect.
2. Define a paired result action such as `FetchModelsResult(result<modelList, fetchError>)`.
3. Normalize success, returned error, promise rejection, or exception into that `result` at the effect boundary.
4. Dispatch the result action exactly once.
5. Apply the result in the reducer, even when the deliberate outcome is no state change.

Omit a result action only for a consciously fire-and-forget operation whose success or failure cannot affect behavior. Keep effect handlers thin: execute I/O, translate the outcome, and dispatch. Do not put domain transitions in promise callbacks.

### Keep React a projection of state

- Keep business state and corrective logic out of components.
- Read typed state through props and selectors.
- Dispatch domain actions from event handlers.
- Reserve React effects for synchronization with systems outside React, not for enforcing invariants between stores.
- Follow hook rules and include complete dependencies.
- Merge conditional Tailwind fragments through the repository's class-merging helper rather than interpolation or concatenation.
- Render nothing with the repository's empty component when it has one.

### Keep interop typed and narrow

- Give every JavaScript API a typed `external` declaration.
- Convert null and undefined at the boundary.
- Decode untrusted JSON with the repository's schema system before domain code sees it.
- Represent closed JavaScript string enums with typed variants at the binding boundary.
- Put each library's bindings in one file under the package's `bindings/` directory and follow that package's convention. Never declare a `module Foo = { ... external ... }` inside a domain, feature, or tool module, even for a single external.
- Name a binding module after the library or API it binds, spelled out: `SandboxRuntime` for `@anthropic-ai/sandbox-runtime`, not `Srt`.
- Never use `%raw` or `Obj.magic` to avoid writing a correct binding.

### Using Sury / Data Modeling

When modeling data, and interop through JSON with sury-ppx / schema, there are different ways to define optional fields, and depending on the way you do it, it is semantically different.

`@s.null` makes it so that a value has to be serialized through `null`.

```rescript
@schema
type t = {
    a: @s.null option<string> // Key required in Rescript, key required in JSON
    b?: @s.null string // Key not required in Rescript, key required in JSON (!)
}
```

`@s.nullable` makes it so that a value can be serialized either through `null` or through `undefined`.

```rescript
@schema
type t = {
    a: @s.nullable option<string> // Key required in Rescript, key not-required in JSON
    b?: @s.nullable string // Key not required in Rescript, key not-required in JSON (!)
}
```

From a Rescript perspective (ie - Rescript owns the data):
- When the key is required in Rescript, we should use `@s.null`.
- When the key is not-required in Rescript, we should use `@s.nullable` (accepting both `null` and `undefined` - both of which deserialize to `None`).

From a data perspective (Rescript code is not the owner / data comes in foreign).
- If we _know_ the key is always there (ie. server always serializes to `null`), we can use `@s.null`.
- In all other cases `@s.nullable` is probably a better mapping.

Datamodeling wise, the difference between a key being there but the value being null, or the key being omitted, is a hard distinction to make. Because the question "what does this mean" is hard to answer, and most often means nothing / is just a short-cut for not having to type the entire record. So, strongly prefer to not use optional fields (`foo?: string`) but rather keep the record shape the same with optional values (`foo: option<string>`) as it simplifies the code (same record always looks the same, not context dependently different). For interop, it can be helpful to have fields be optional outright.

Clear exception being a record where more than half of the record has optional fields (though that probably needs a differently designed type in that case).

### Brittle Pattern Matching

Strongly prefer non-brittle pattern matching. The compiler will enforce this for core packages. In App / Runtime (the 'edges') you can be more liberal, but prefer to only do this for built-in types.

Turning this:
```
  | (None, Some(_) | None) | (Some((0, 0, 0)), Some(_) | None) => Error("Some Error")
```

Into this:
```
  | (None, _) | (Some((0, 0, 0)), _) => Error("Some Error")
```

Is probably fine, the internal types are not brittle, and the second version is more readable

Turning this:
```
type messageKind = | UserRequest | ModelResponse | UserResponse

...

  | UserResponse => Some("Responded")
  | UserRequest | ModelResponse => None
```

Into this:
```
  | UserResponse => Some("Responded")
  | _ => None
```

Is probably not, the type is under our control and it feels like it could be expanded upon at some point.

## Review and test

Use Vitest for concrete examples: individual transitions, known edge cases, failures, regressions, and scenario sequences. Use FastCheck when one invariant should hold across a broad generated input space or action sequence, such as idempotence, preservation, deduplication, round trips, or an effect forbidden during a lifecycle phase. Do not turn a short finite scenario table into a generator merely to call it property-based.

Test reducers through their pure `next(state, action)` function by default. Assert both the returned state and typed effects; effects are part of the transition contract. Use a `StateStore` with a test reducer module that delegates `name` and `next` but replaces `handleEffect` only when the effect-to-action orchestration itself needs coverage.

Make invalid generated setup fail the property. If a generator promises valid parseable input, a parse error returns `false` or otherwise fails the test; never return `true` and hide the broken precondition.

Review stateful code by enumerating transitions, not just by reading the happy path. Test at least:

- initial request and immediate transition to loading;
- duplicate request actions while loading;
- success, empty success, and failure;
- retry or refresh behavior when supported;
- invalid or unavailable selections;
- stale responses when request identity matters;
- every intentional no-op result and transition.

Read [testing.md](references/testing.md) when writing Vitest tests, FastCheck properties, reducer transition tests, or a mocked effect harness.

## Self-review checklist

Before finishing:

- [ ] Read the relevant architecture documentation before editing and update it when the behavior or contract changes.
- [ ] Consult the official ReScript LLM documentation index when language or toolchain details need confirmation.
- [ ] Run the repository's ReScript formatter, zero-warning build, and relevant tests.
- [ ] Add no warning suppression without an adjacent justification.
- [ ] Keep nesting to three levels or fewer.
- [ ] Match every constructor of controlled variants; add no wildcard fallback for a closed domain.
- [ ] Use no Boolean or sentinel to hide a lifecycle, provenance, mode, or multi-state concept.
- [ ] Use no `%raw`, `Obj.magic`, type coercion, untyped external, or unchecked JSON access.
- [ ] Put every new `external` in its library's file under `bindings/`, never in an inline binding module in domain code, and give that module a spelled-out name.
- [ ] Add no exposed mutation, ref, first-class module, or functor without a concrete reason the simpler alternative fails.
- [ ] Represent expected failures with typed `result` values and structured errors.
- [ ] Normalize promise rejections and exceptions at the boundary; never swallow them in effects.
- [ ] Add no trivial wrapper helper, action-shaped module, or `Helpers` grab bag.
- [ ] Check every generic local helper against ReScript's standard library and the project's standard-library extensions.
- [ ] Give every exported function declared by a reusable library module a contract-focused `/** ... */` doc comment.
- [ ] Spell out runtime variable names and name functions with verbs.
- [ ] Declare types and helper functions above their callers; keep binding and domain boundaries obvious.
- [ ] Keep reducers authoritative, effect handlers thin, and React components focused on rendering and intent.
- [ ] Choose example-based or property-based tests deliberately; assert reducer effects as well as state and never let invalid generated setup pass.

## References

- [state-modeling.md](references/state-modeling.md) — detailed domain modeling, async resources, reducers, effects, and view ownership
- [testing.md](references/testing.md) — Vitest, FastCheck, reducer transition tests, generated action invariants, and mocked effect handlers
- [patterns.md](references/patterns.md) — supplementary examples for ReScript modules, bindings, React, and typed errors; apply this skill's coding rules when adapting them
- `references/gitignore` — ReScript build-output ignores
