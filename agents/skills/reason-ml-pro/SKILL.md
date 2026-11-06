---
name: reasonml-melange-pro
description: Expert ReasonML / Melange developer specializing in type-safe functional programming, JavaScript interop, and React integration. Use PROACTIVELY when working on any ReasonML / Melange code - implementing features, designing APIs, debugging type errors, or reviewing code quality, even if not explicitly requested. Applies unless a more specific subagent role overrides.
# Development skill for this repository; not for installation by users.
metadata:
  internal: true
---

# ReasonML / Melange Pro

Senior-level ReasonML / Melange expertise for production projects. Focuses on type safety, exhaustive pattern matching, clean JavaScript interop, and React integration.

## When Invoked

1. Review `dune-project`, `dune` files, `package.json`, and project Melange configuration
2. For build system setup, invoke the **just-pro** skill
3. Apply ReasonML / OCaml idioms and established project patterns
4. Prefer typed Melange externals over raw JavaScript escapes

## Core Standards

**Required:**

- All pattern matches exhaustive - **NO wildcard `_` on variants you control**
- **NO raw JavaScript escapes in production code** - use typed external bindings
- **NO `Obj.magic` or unsafe type coercion** - fix the types properly
- All external bindings have explicit types
- `dune build` passes with zero warnings
- Formatting enforced on all ReasonML / OCaml code

**Foundational Principles:**

- **Single Responsibility**: One module = one purpose, one function = one job
- **No God Modules**: Split large modules; if it has 10+ top-level functions, decompose
- **Dependency Injection**: Pass dependencies as parameters, don't rely on global state
- **Pipe-First Style**: Use `|>` for data transformations, reads left-to-right
- **Make Illegal States Unrepresentable**: Model domain with variants and records

---

## Project Setup

### Minimal Dune Shape

```lisp
; dune-project
(lang dune 3.15)
(using melange 0.1)

(package
 (name app)
 (depends
  ocaml
  dune
  melange
  reason
  reason-react
  reason-react-ppx
  melange-webapi))
```

```lisp
; src/dune
(melange.emit
 (target output)
 (libraries reason-react melange-webapi)
 (preprocess (pps reason-react-ppx))
 (emit_stdlib false))
```

### Developer Onboarding

```bash
git clone <repo> && cd <repo>
just setup         # Runs mise trust/install + package installation
just check         # Verify everything works
```

Or manually:

```bash
mise trust && mise install
npm ci
dune build
```

**Why ReasonML / Melange?** You get OCaml’s sound type system and module system with readable JavaScript output. Exhaustive pattern matching catches bugs at compile time, while Melange provides typed JavaScript interop.

---

## Build System

**Invoke the `just-pro` skill** for build system setup. It covers:

- Simple repos vs monorepos
- Hierarchical justfile modules
- Language-specific templates

**Why just?** Consistent toolchain frontend between agents and humans. Instead of remembering build commands, use `just build`.

---

## Quality Assurance

**Auto-Fix First** - Always try auto-fix before manual fixes:

```bash
just fix
```

Typical fallback:

```bash
dune build @fmt --auto-promote
npx eslint src/ --fix
```

**Verification:**

```bash
just check
```

Typical fallback:

```bash
dune build
npx eslint src/
npm test
```

**Note:** Compiler warnings should be treated as errors where possible. A clean build means zero warnings. ESLint can validate React hooks and enforce complexity limits on the compiled JavaScript output.

---

## Linting Configuration

ReasonML / Melange uses a **two-layer quality approach**:

1. **Compiler warnings** - Catch ReasonML / OCaml-specific issues, including exhaustiveness and unused bindings

### Warnings Configuration

Prefer strict compiler warnings. Exact warning numbers may vary by OCaml / Melange version, so verify against the project compiler.

Typical goals:

- Enable broad warnings
- Treat warnings as errors in CI
- Avoid suppressing exhaustiveness warnings
- Avoid suppressing unused-value warnings unless intentionally required
- Keep any warning exceptions documented

---

## Quick Reference

### Type System

| Pattern           | Use                                            |
| ----------------- | ---------------------------------------------- |
| Variants          | Model states, tagged unions, enums             |
| Records           | Structured data with named fields              |
| `option('a)`      | Nullable values: `Some` / `None`               |
| `result('a, 'e)`  | Operations that can fail: `Ok` / `Error`       |
| Type parameters   | Generic / polymorphic functions                |
| Labeled arguments | Named params for clarity                       |
| Modules           | Namespacing, abstraction, dependency injection |
| Functors          | Generate modules from modules                  |

### Variants

```reason
/* Simple enum */
type color =
  | Red
  | Green
  | Blue;

/* With payloads */
type shape =
  | Circle({radius: float})
  | Rectangle({width: float, height: float})
  | Triangle({base: float, height: float});

/* Pattern matching - MUST be exhaustive */
let area = shape =>
  switch (shape) {
  | Circle({radius}) =>
    Js.Math._PI *. radius *. radius

  | Rectangle({width, height}) =>
    width *. height

  | Triangle({base, height}) =>
    0.5 *. base *. height

  /* NO: | _ => 0.0
     Wildcard hides future variants. */
  };
```

### Records

```reason
/* Type declaration */
type user = {
  id: string,
  name: string,
  email: string,
  age: int,
};

/* Creation */
let user = {
  id: "123",
  name: "Alice",
  email: "alice@example.com",
  age: 30,
};

/* Update - immutable by default */
let updatedUser = {...user, age: 31};

/* Mutable fields when needed */
type counter = {
  mutable count: int,
};
```

### Option and Result

```reason
/* Option for nullable values */
let findUser = (users, id): option(user) =>
  users |> Array.find(u => u.id == id);

/* Handle option explicitly */
let greeting =
  switch (findUser(users, "123")) {
  | Some(user) =>
    "Hello, " ++ user.name ++ "!"

  | None =>
    "User not found"
  };

/* Result for operations that can fail */
type fetchError =
  | NetworkError
  | NotFound
  | ParseError(string);

let fetchUser = async id: result(user, fetchError) => {
  try {
    let response = await(fetch("/users/" ++ id));

    if (response |> Response.ok) {
      let data = await(Response.json(response));
      Ok(parseUser(data));
    } else {
      Error(NotFound);
    };
  } catch {
  | _ =>
    Error(NetworkError)
  };
};

/* Chain results with a Result module */
let processUser = id =>
  id
  |> fetchUser
  |> Result.map(user => user.name |> String.uppercase_ascii)
  |> Result.mapError(err => "Failed: " ++ errorToString(err));
```

### Pipe Operator

```reason
/* Pipe-first style: data flows left to right */
let result =
  users
  |> Array.filter(u => u.age >= 18)
  |> Array.map(u => u.name)
  |> Array.sort(String.compare)
  |> Array.join(", ");

/* Underscore placeholder for non-first position */
let contains = str |> String.includes("test", _);
```

### Labeled Arguments

```reason
/* Use labeled args for functions with multiple params of same type */
let createRect = (~width: float, ~height: float) =>
  Rectangle({width, height});

/* Optional with default */
let greet = (~greeting="Hello", ~name) =>
  greeting ++ ", " ++ name ++ "!";

/* Call with labels */
let rect = createRect(~width=10.0, ~height=5.0);
let msg = greet(~name="Alice"); /* Uses default greeting */
```

### Modules

```reason
/* Module definition */
module User = {
  type t = {
    id: string,
    name: string,
  };

  let make = (~id, ~name) => {id, name};

  let toString = (user: t) =>
    user.name ++ " (" ++ user.id ++ ")";
};

/* Module usage */
let user = User.make(~id="123", ~name="Alice");
Console.log(User.toString(user));

/* Open for local scope */
{
  open User;

  let u = make(~id="456", ~name="Bob");
  Console.log(toString(u));
};

/* Module signatures */
module type Printable = {
  type t;
  let toString: t => string;
};
```

---

## JavaScript Interop

### External Bindings

```reason
/* Global value */
[@mel.val]
external document: Dom.document = "document";

/* Global function */
[@mel.val]
external parseInt: string => int = "parseInt";

/* Module import */
[@mel.module "lodash"]
external chunk: (array('a), int) => array(array('a)) = "chunk";

/* Default export */
[@mel.module "./config"]
external config: Js.t({..}) = "default";

/* Method call on object */
[@mel.send]
external focus: Dom.element => unit = "focus";

[@mel.send]
external getAttribute: (Dom.element, string) => Js.Nullable.t(string) = "getAttribute";

/* Property access */
[@mel.get]
external length: array('a) => int = "length";

[@mel.set]
external setTitle: (Dom.document, string) => unit = "title";

/* Constructor */
[@mel.new]
external makeDate: unit => Js.Date.t = "Date";

[@mel.new]
external makeDateFromString: string => Js.Date.t = "Date";
```

### Common FFI Patterns

```reason
/* Nullable values from JS */
[@mel.module "./api"]
external getUser: string => Js.Nullable.t(user) = "getUser";

let user = getUser("123");

switch (user |> Js.Nullable.toOption) {
| Some(u) =>
  Console.log(u.name)

| None =>
  Console.log("Not found")
};

/* Variadic functions */
[@mel.module "path"] [@mel.variadic]
external join: array(string) => string = "join";

let fullPath = join([|"users", "alice", "documents"|]);

/* Object with optional fields */
type options = {
  timeout: option(int),
  retries: option(int),
};

[@mel.module "./fetch"]
external request: (string, options) => promise(response) = "request";

/* Polymorphic variants for JS string enums */
[@mel.module "./api"]
external setMode:
  (
    [@mel.unwrap]
    [
      | `development
      | `production
      | `test
    ]
  ) =>
  unit =
  "setMode";

setMode(`production);
```

### Promises and Async/Await

```reason
/* Async function */
let fetchData = async (url: string): result(data, error) => {
  try {
    let response = await(fetch(url));
    let json = await(Response.json(response));

    Ok(parseData(json));
  } catch {
  | Exn.Error(e) =>
    Error(NetworkError(Exn.message(e)))
  };
};

/* Sequential operations */
let fetchUserAndPosts = async userId => {
  let user = await(fetchUser(userId));
  let posts = await(fetchPosts(userId));

  {user, posts};
};

/* Parallel operations */
let fetchAll = async ids => {
  let promises = ids |> Array.map(fetchUser);
  await(Promise.all(promises));
};
```

---

## React Integration

### Basic Component

```reason
[@react.component]
let make = (~name: string, ~age: int) =>
  <div>
    <h1>{React.string("Hello, " ++ name ++ "!")}</h1>
    <p>{React.string("Age: " ++ string_of_int(age))}</p>
  </div>;
```

### Hooks

```reason
type action =
  | Increment
  | Decrement
  | Reset;

type state = {
  count: int,
};

[@react.component]
let make = () => {
  /* State */
  let (count, setCount) = React.useState(() => 0);

  /* Effect */
  React.useEffect0(() => {
    Console.log("Component mounted");
    Some(() => Console.log("Component unmounted"));
  });

  /* Effect with deps */
  React.useEffect1(
    () => {
      Console.log("Count changed to " ++ string_of_int(count));
      None;
    },
    [|count|],
  );

  /* Reducer for complex state */
  let (state, dispatch) =
    React.useReducer(
      (state, action) =>
        switch (action) {
        | Increment =>
          {...state, count: state.count + 1}

        | Decrement =>
          {...state, count: state.count - 1}

        | Reset =>
          {count: 0}
        },
      {count: 0},
    );

  /* Ref */
  let inputRef = React.useRef(Js.Nullable.null);

  <div>
    <p>{React.string(string_of_int(count))}</p>
    <button onClick={_event => setCount(prev => prev + 1)}>
      {React.string("+")}
    </button>
  </div>;
};
```

### Props with Variants

```reason
type buttonVariant =
  | Primary
  | Secondary
  | Danger;

[@react.component]
let make = (~variant: buttonVariant, ~children: React.element) => {
  let className =
    switch (variant) {
    | Primary => "btn-primary"
    | Secondary => "btn-secondary"
    | Danger => "btn-danger"
    };

  <button className>
    children
  </button>;
};
```

### Children and Optional Props

```reason
[@react.component]
let make =
    (~title: string, ~subtitle: option(string)=?, ~children: React.element) =>
  <div>
    <h1>{React.string(title)}</h1>
    {
      switch (subtitle) {
      | Some(s) =>
        <h2>{React.string(s)}</h2>

      | None =>
        React.null
      }
    }
    children
  </div>;

/* Usage */
<Card title="Hello" subtitle={Some("World")}>
  <p>{React.string("Content")}</p>
</Card>;
```

---

## Project Organization

```text
project/
├── src/
│   ├── dune                 # Melange emit stanza
│   ├── Main.re              # Entry point
│   ├── Types.re             # Shared type definitions
│   ├── Utils.re             # Utility functions
│   ├── Components/          # React components
│   │   ├── Button.re
│   │   └── Card.re
│   └── Bindings/            # JS interop
│       └── LocalStorage.re
├── dune-project
├── package.json
├── justfile
└── .mise.toml
```

**Rules:** One module = one purpose. Keep bindings in separate files. Use namespaced modules for libraries.

---

## Anti-Patterns

- Raw JavaScript escapes in production code; use typed bindings
- `Obj.magic` for type coercion; fix the types instead
- Wildcard `_` in `switch` on your own variants; add explicit cases
- Ignoring warnings; treat them as errors
- Mutable state everywhere; use immutable by default
- Deep nesting instead of smaller helper functions
- Giant modules with 10+ functions; split by responsibility
- Stringly-typed APIs; use variants for known values
- Old BuckleScript-era attributes such as `[@bs.*]`; use `[@mel.*]`
- Ignoring `option` return types; always handle `None`

---

## AI Agent Guidelines

**Before writing code:**

1. Read `dune-project`, relevant `dune` files, `package.json`, and any lockfiles
2. Check for existing type definitions and project patterns
3. Identify binding patterns for JavaScript interop
4. Check whether the project uses `.re`, `.ml`, or a mixed layout

**When writing code:**

1. Start with type definitions - model the domain with variants and records
2. Use exhaustive pattern matching - no wildcards on your own types
3. Handle all `option` and `result` cases explicitly
4. Create typed bindings for JS interop - avoid raw JavaScript escapes
5. Keep generated JavaScript shape in mind when binding to external libraries

**Before committing:**

1. Run `just check` if the project uses `just`
2. Fallback: `dune build && npx eslint src/`
3. Fallback: `dune build @fmt --auto-promote` for consistent formatting

---

## References

- `references/dune-project-template` - Strict Dune / Melange project template
- `references/dune-template` - Example Melange emit stanza
- `references/eslint.config.js` - ESLint config for linting compiled JS output
- `references/patterns.md` - Additional ReasonML / Melange patterns
- `references/gitignore` - ReasonML / Melange-specific gitignore
