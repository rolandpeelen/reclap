# Domain modeling in ReScript

Read this with the shared [domain-modeling skill](../../domain-modeling/SKILL.md)
when designing domain types, constructors, input boundaries, application state,
reducers, effects, or React consumers.

## Contents

1. Own domain types and model their meanings
2. Separate lifetimes deliberately
3. Async resource pattern
4. Effect/result protocol
5. Producer and view ownership
6. Review checklist

## 1. Own domain types and model their meanings

Put a domain type and its construction, accessors, and pure transitions in the
module that owns the concept. Components should not inspect another module's
variant to reimplement its rules. Do not add a wrapper module for a primitive
that carries no distinct meaning or invariant.

Use records for facts that vary independently. Use variants for mutually
exclusive states, with required data attached to each constructor. Match
variants you own exhaustively. Do not use a wildcard to suppress the compiler's
warning about a new case.

A type alias does not create a distinct type. When mixing IDs or bypassing a
constructor would violate a real rule, hide the representation behind an
abstract module signature or `.resi`. Expose a constructor that returns
`result<t, error>` and the operations callers need. A variant wrapper can
distinguish values, but an exposed constructor does not enforce validation.

At foreign boundaries, type untrusted input as `JSON.t` and decode it before
domain use, with the repository's schema library where it has one. An annotation or external binding alone does not validate runtime
data. Do not use unchecked getters, casts, or throwing conversions to claim a
value is valid.

Use `option` when absence is the complete meaning. Use `result` when failure
has a reason the caller must handle. After parsing, pass the accepted value,
not the original broad input. Separate draft and accepted types only when
their validity rules differ; do not duplicate identical wire and domain types.

Static types cannot prove that a permission, connection, or remote record is
still current. The owning backend operation must check mutable authority when
it acts. A client type or cached projection is not that authority.

### Model resource lifetimes

This record stores values but does not model the resource lifecycle:

```rescript
type state = {
  projects: array<project>,
  live: bool,
}
```

It permits an empty initial value, an empty successful response, stale data, and failure to look identical. `live` has no stable meaning: it might mean fetched once, recently fetched, connected, or continuously synchronized.

Use a lifecycle type:

```rescript
type state = {
  projects: Async.t<array<project>, loadError>,
}
```

Now `Initial`, `Loading`, `Refreshing(projects)`, `Success([])`, `Success(projects)`, and `Failure(error)` are distinct. The reducer and view must address the meaningful cases.

Do not add a Boolean beside a variant to restate its constructor:

```rescript
// Avoid: loading can disagree with projects.
type state = {
  projects: Async.t<array<project>, loadError>,
  loading: bool,
}
```

## 2. Separate Lifetimes Deliberately

Fields do not need to live inside the async value merely because they relate to fetched data.

Keep a value outside the async resource when it has an independent lifetime. For example, a user's selection may survive a refresh or a temporary load failure:

```rescript
type state = {
  projects: Async.t<array<project>, loadError>,
  selectedProject: option<projectId>,
}
```

This is correct only when `None` literally means no selection and a selection may legitimately outlive the current project list. The reducer must own reconciliation when a successful response arrives.

If selection only exists for a loaded collection, put it in the success payload
so an unloaded state cannot carry a selection:

```rescript
type loadedProjects = {
  projects: array<project>,
  selectedProject: option<projectId>,
}

type projectsState = Async.t<loadedProjects, loadError>
```

Choose based on domain lifetime, not nesting convenience.
The reducer must still check that a selected ID belongs to the collection;
the record type alone does not enforce that relationship.

Do not use `None` to mean “use the default project.” Model that explicitly:

```rescript
type selection = UseDefault | Selected(projectId)
```

## 3. Async Resource Pattern

Assume the API already returns `promise<result<projectList, loadError>>`:

```rescript
module Reducer = {
  type state = {
    projects: Async.t<array<project>, loadError>,
  }

  type action =
    | Init
    | FetchProjectsResult(result<projectList, loadError>)

  type effect = FetchProjects

  let next = (state, action) =>
    switch action {
    | Init =>
      switch state.projects {
      | Initial | Failure(_) =>
        update({...state, projects: Loading}, ~sideEffect=FetchProjects)
      | Loading | Refreshing(_) | Success(_) => update(state)
      }
    | FetchProjectsResult(Ok({projects})) =>
      update({...state, projects: Success(projects)})
    | FetchProjectsResult(Error(error)) =>
      update({...state, projects: Failure(error)})
    }

  let handleEffect = (effect, _state, dispatch) =>
    switch effect {
    | FetchProjects =>
      Api.Projects.list()
      ->Promise.forEach(result => dispatch(FetchProjectsResult(result)))
    }
}
```

Important properties:

- `Init` changes state to `Loading` in the same transition that emits `FetchProjects`.
- Another `Init` during `Loading` or `Refreshing(_)` is an explicit no-op.
- The result action carries the API's literal `result`; the effect does not swallow failure.
- `Success([])` remains a valid, distinguishable successful response.
- Retry after `Failure` is a visible policy choice. If the domain should not retry on `Init`, enumerate `Failure(_)` with the no-op states instead.

If a foreign operation can throw or reject, lift it with `PromiseResult.make`
at the I/O boundary. Pass a thunk that starts the operation, not an already
started promise. Map the captured exception into the operation's error type,
then dispatch the result. Do not wrap `await` in `try`/`catch` or put throwing
operations inside `PromiseResult` combinator callbacks. The reducer receives
data and does not handle promise mechanics.

The example permits one in-flight load. If the real lifecycle permits request
replacement, entity changes, or overlapping requests, define which completion
may update state. Carry a request identity or generation only when needed to
reject stale results. Include cancellation and store teardown in that policy;
an old completion must not update a new lifecycle.

## 4. Effect/Result Protocol

Use paired, descriptive names:

```rescript
type action =
  | LoadUser
  | LoadUserResult(result<user, loadUserError>)

type effect = LoadUserRequest
```

Alternatively, when another action such as `Init` requests the operation:

```rescript
type action =
  | Init
  | LoadUserResult(result<user, loadUserError>)

type effect = LoadUser
```

Choose names that stay clear when the reducer later gains more operations. Avoid `Fetch`, `Fetched`, `Result`, and `Done` without the operation's subject.

The effect handler performs I/O and converts completion into data. The reducer decides what that data means. Even when the reducer intentionally ignores an outcome, representing it as an action keeps the protocol observable and testable:

```rescript
| SavePreferencesResult(Ok()) => update(state)
| SavePreferencesResult(Error(_error)) => update(state)
```

Omit the result action only when no success or failure can change application behavior and the operation is intentionally fire-and-forget.

Do not emit effects for pure synchronous calculations:

```rescript
| SortProjects(order) =>
  update({...state, projects: sortProjects(state.projects, order)})
```

## 5. Producer and View Ownership

The state producer owns:

- valid transitions;
- async lifecycle;
- selection and deselection;
- reconciliation against new data;
- fallback policy;
- derived availability;
- persistence decisions.

The view owns:

- rendering the current state;
- collecting user input;
- dispatching intent.

Avoid this shape:

```rescript
React.useEffect(() => {
  if selectionIsInvalid {
    Store.dispatch(SelectFallback)
  }
  None
}, (selectionIsInvalid, currentSelection))
```

The producer should reconcile selection in the transition that receives the changed data. This prevents multiple views from implementing different fallback rules and makes the behavior testable without React.

Do not duplicate a derived fact in the store and component. Prefer a pure selector or helper over storing `hasDefault`, `live`, or `available` beside the data from which it is derived.

## 6. Review Checklist

Before accepting stateful ReScript code, verify:

- Domain constructors and operations live on the owning module.
- Abstract types protect a concrete invariant; aliases are not treated as validation.
- Foreign data is decoded before use, and expected failures remain typed values.
- Every field and constructor has one stable meaning.
- No Boolean stands in for a multi-state lifecycle or mode; independent Boolean facts remain valid.
- No sentinel (`None`, `""`, `[]`) carries an unrelated domain meaning.
- Invalid combinations are absent or explicitly justified by independent lifetimes.
- Starting async work changes state immediately.
- Repeated start actions have an explicit policy.
- Every relevant async completion becomes a typed result action.
- Effect handlers contain I/O translation, not domain decisions.
- Reducers own reconciliation and fallback.
- Views render and dispatch instead of repairing state.
- Controlled variants are matched without wildcards.
- Transition tests cover success, empty success, failure, retry, duplicate starts, and stale responses where relevant.

For language details, start at the official
[ReScript documentation index](https://rescript-lang.org/llms.txt) and follow its
language-overview and JavaScript-interop references.
