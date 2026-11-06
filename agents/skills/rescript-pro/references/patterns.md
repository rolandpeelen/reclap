# ReScript Patterns Reference

Use these examples only when the abstraction matches a real need. Apply the simplicity, naming, exhaustive-matching, error, and interop rules from the main skill when adapting them.

## Contents

1. Variant patterns
2. Module patterns
3. FFI patterns
4. React patterns
5. Error handling patterns

## Variant Patterns

### State Machines

```rescript
type downloadState = Idle | Downloading | Complete(int) | Failed(string)

type downloadAction = Start | Finished(int) | DownloadFailed(string) | Reset

let transition = (state: downloadState, action: downloadAction): downloadState =>
  switch (state, action) {
  | (Idle, Start) | (Failed(_), Start) => Downloading
  | (Downloading, Start) | (Complete(_), Start) => state
  | (Downloading, Finished(bytes)) => Complete(bytes)
  | (Idle, Finished(_)) | (Complete(_), Finished(_)) | (Failed(_), Finished(_)) => state
  | (Downloading, DownloadFailed(message)) => Failed(message)
  | (Idle, DownloadFailed(_))
  | (Complete(_), DownloadFailed(_))
  | (Failed(_), DownloadFailed(_)) => state
  | (Idle, Reset) | (Downloading, Reset) | (Complete(_), Reset) | (Failed(_), Reset) => Idle
  }
```

### Polymorphic Variants for Interop

```rescript
// Use polymorphic variants for JS string enums
@module("./api")
external setLogLevel: (@unwrap [#debug | #info | #warn | #error]) => unit = "setLogLevel"

@module("./api")
external setTheme: (@unwrap [#light | #dark | #system]) => unit = "setTheme"

// Usage - type-safe string values
setLogLevel(#warn)
setTheme(#dark)

```

Keep application-domain states as ordinary variants. Use polymorphic variants here because `@unwrap` maps this closed set directly to JavaScript strings.

## Module Patterns

### Module Functors

Use a functor only when multiple real modules need the same compile-time construction. Prefer direct modules for a single instantiation.

```rescript
// Module type for comparable items
module type Comparable = {
  type t
  let compare: (t, t) => int
}

// Generic sorted set module
module MakeSortedSet = (Item: Comparable) => {
  type t = list<Item.t>

  let empty: t = list{}

  let add = (set: t, item: Item.t): t => {
    let rec insert = (lst, item) =>
      switch lst {
      | list{} => list{item}
      | list{head, ...tail} =>
        switch Item.compare(item, head) {
        | n if n < 0 => list{item, head, ...tail}
        | 0 => lst  // Already exists
        | _positive => list{head, ...insert(tail, item)}
        }
      }
    insert(set, item)
  }

  let toArray = (set: t): array<Item.t> => List.toArray(set)
}

// Usage
module IntSet = MakeSortedSet({
  type t = int
  let compare = (left, right) => left - right
})

let set = IntSet.empty->IntSet.add(3)->IntSet.add(1)->IntSet.add(2)
```

### First-Class Modules

Use a first-class module only when the implementation must be selected or passed at runtime. Prefer a direct module call when it does not.

```rescript
module type Storage = {
  let get: string => option<string>
  let set: (string, string) => unit
  let remove: string => unit
}

// Pack module as value
let localStorage: module(Storage) = module({
  @val @scope("localStorage")
  external getItem: string => Nullable.t<string> = "getItem"
  @val @scope("localStorage")
  external setItem: (string, string) => unit = "setItem"
  @val @scope("localStorage")
  external removeItem: string => unit = "removeItem"

  let get = key => getItem(key)->Nullable.toOption
  let set = setItem
  let remove = removeItem
})

// Use with any storage implementation
let saveData = (storage: module(Storage), key: string, value: string) => {
  module S = unpack(storage)
  S.set(key, value)
}
```

## FFI Patterns

### Binding to Classes

```rescript
// ES6 class binding
type websocket
type messageEvent
type event

// This application protocol accepts text messages only.
@new external makeWebSocket: string => websocket = "WebSocket"
@send external send: (websocket, string) => unit = "send"
@send external close: websocket => unit = "close"
@get external readyState: websocket => int = "readyState"
@get external messageData: messageEvent => string = "data"
@set external onmessage: (websocket, messageEvent => unit) => unit = "onmessage"
@set external onerror: (websocket, event => unit) => unit = "onerror"

// Usage
let ws = makeWebSocket("wss://example.com/socket")
ws->onmessage(event => Console.log2("Received:", event->messageData))
ws->send(`{"type": "ping"}`)
```

### Binding to Object Methods

```rescript
// Object with chainable methods
type queryBuilder

@module("./db") external query: string => queryBuilder = "query"
@send external where: (queryBuilder, string, 'a) => queryBuilder = "where"
@send external orderBy: (queryBuilder, string) => queryBuilder = "orderBy"
@send external limit: (queryBuilder, int) => queryBuilder = "limit"
@send external execute: queryBuilder => promise<array<JSON.t>> = "execute"

// Chainable usage
let getUsers = async () => {
  query("users")
    ->where("active", true)
    ->orderBy("created_at")
    ->limit(10)
    ->execute
}
```

### Binding to Callbacks

```rescript
// Node-style callbacks
type callback<'a> = (Nullable.t<JsExn.t>, 'a) => unit

@module("fs")
external readFile: (string, string, callback<string>) => unit = "readFile"

// Promise wrapper
let readFileAsync = (path: string): promise<result<string, JsExn.t>> => {
  Promise.make((resolve, _reject) => {
    readFile(path, "utf8", (nullableError, data) => {
      switch nullableError->Nullable.toOption {
      | Some(error) => resolve(Error(error))
      | None => resolve(Ok(data))
      }
    })
  })
}
```

### Typed Event Handlers

```rescript
type mouseEvent = {
  clientX: int,
  clientY: int,
  button: int,
  preventDefault: unit => unit,
}

type keyboardEvent = {
  key: string,
  code: string,
  altKey: bool,
  ctrlKey: bool,
  shiftKey: bool,
  preventDefault: unit => unit,
}

@val @scope("document")
external addMouseListener: (
  @string [#click | #mousedown | #mouseup | #mousemove],
  mouseEvent => unit
) => unit = "addEventListener"

@val @scope("document")
external addKeyListener: (
  @string [#keydown | #keyup | #keypress],
  keyboardEvent => unit
) => unit = "addEventListener"

// Usage
addMouseListener(#click, event => {
  Console.log2("Clicked at:", (event.clientX, event.clientY))
})

addKeyListener(#keydown, event => {
  if event.ctrlKey && event.key == "s" {
    event.preventDefault()
    Console.log("Save shortcut pressed")
  }
})
```

## React Patterns

### Context with Variants

```rescript
type theme = Light | Dark

type themeContext = {
  theme: theme,
  toggleTheme: unit => unit,
}

let context = React.createContext({
  theme: Light,
  toggleTheme: () => (),
})

module Provider = {
  @react.component
  let make = (~children: React.element) => {
    let (theme, setTheme) = React.useState(_ => Light)

    let value = {
      theme,
      toggleTheme: () =>
        setTheme(prev =>
          switch prev {
          | Light => Dark
          | Dark => Light
          }
        ),
    }

    <context.Provider value>
      {children}
    </context.Provider>
  }
}

// Hook for consuming
let useTheme = () => React.useContext(context)
```

### Custom Hook with Cleanup

```rescript
type windowSize = {
  width: int,
  height: int,
}

let useWindowSize = (): windowSize => {
  let (size, setSize) = React.useState(_ => {
    width: Webapi.Dom.Window.innerWidth(Webapi.Dom.window),
    height: Webapi.Dom.Window.innerHeight(Webapi.Dom.window),
  })

  React.useEffect0(() => {
    let handleResize = _ => {
      setSize(_ => {
        width: Webapi.Dom.Window.innerWidth(Webapi.Dom.window),
        height: Webapi.Dom.Window.innerHeight(Webapi.Dom.window),
      })
    }

    Webapi.Dom.Window.addEventListener(Webapi.Dom.window, "resize", handleResize)

    Some(
      () =>
        Webapi.Dom.Window.removeEventListener(
          Webapi.Dom.window,
          "resize",
          handleResize,
        ),
    )
  })

  size
}
```

## Error Handling Patterns

### Tagged Errors

```rescript
type apiError =
  | NetworkError({url: string, status: int})
  | ValidationError({field: string, message: string})
  | AuthError({reason: string})
  | RateLimited({retryAfter: int})

let errorToMessage = (error: apiError): string =>
  switch error {
  | NetworkError({url, status}) => `Network error: ${url} returned ${Int.toString(status)}`
  | ValidationError({field, message}) => `Validation failed for ${field}: ${message}`
  | AuthError({reason}) => `Authentication failed: ${reason}`
  | RateLimited({retryAfter}) => `Rate limited. Retry after ${Int.toString(retryAfter)} seconds`
  }

let errorToStatusCode = (error: apiError): int =>
  switch error {
  | NetworkError(_) => 502
  | ValidationError(_) => 400
  | AuthError(_) => 401
  | RateLimited(_) => 429
  }
```
