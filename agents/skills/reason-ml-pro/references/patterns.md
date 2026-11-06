# ReasonML / Melange Patterns Reference

## Variant Patterns

### State Machines

```reason
type connectionState =
  | Disconnected
  | Connecting({attempt: int, startedAt: float})
  | Connected({sessionId: string})
  | Reconnecting({lastSession: string, attempt: int})
  | Error({message: string});

type connectionAction =
  | Connect
  | Disconnect
  | ConnectionSuccess(string)
  | ConnectionFailed(string)
  | Retry;

let transition =
    (state: connectionState, action: connectionAction): connectionState =>
  switch ((state, action)) {
  | (Disconnected, Connect) =>
    Connecting({attempt: 1, startedAt: Js.Date.now()})

  | (Connecting(_), ConnectionSuccess(sessionId)) =>
    Connected({sessionId: sessionId})

  | (Connecting({attempt}), ConnectionFailed(_msg)) when attempt < 3 =>
    Reconnecting({lastSession: "", attempt: attempt + 1})

  | (Connecting(_), ConnectionFailed(msg)) =>
    Error({message: msg})

  | (Connected(_), Disconnect) =>
    Disconnected

  | (Reconnecting({attempt}), Retry) when attempt < 3 =>
    Connecting({attempt: attempt + 1, startedAt: Js.Date.now()})

  | (Reconnecting(_), Retry) =>
    Error({message: "Max retries exceeded"})

  | (Error(_), Connect) =>
    Connecting({attempt: 1, startedAt: Js.Date.now()})

  | _ =>
    state /* Ignore invalid transitions */
  };
```

### Result Chaining

```reason
type parseError =
  | InvalidJson
  | MissingField(string)
  | InvalidType(string);

/* Assumes this exists somewhere */
type user = {
  id: string,
  name: string,
  email: string,
};

let optionToResult = (opt, err) =>
  switch (opt) {
  | Some(value) => Ok(value)
  | None => Error(err)
  };

let resultFlatMap = (result, fn) =>
  switch (result) {
  | Ok(value) => fn(value)
  | Error(_) as err => err
  };

let parseUser = (json: Js.Json.t): result(user, parseError) =>
  json
  |> Js.Json.decodeObject
  |> optionToResult(_, InvalidJson)
  |> resultFlatMap(obj => {
       let id =
         obj
         |> Js.Dict.get(_, "id")
         |> optionToResult(_, MissingField("id"));

       let name =
         obj
         |> Js.Dict.get(_, "name")
         |> optionToResult(_, MissingField("name"));

       let email =
         obj
         |> Js.Dict.get(_, "email")
         |> optionToResult(_, MissingField("email"));

       switch ((id, name, email)) {
       | (Ok(id), Ok(name), Ok(email)) =>
         switch ((
           Js.Json.decodeString(id),
           Js.Json.decodeString(name),
           Js.Json.decodeString(email),
         )) {
         | (Some(id), Some(name), Some(email)) =>
           Ok({id, name, email})
         | _ =>
           Error(InvalidType("Expected strings"))
         }

       | (Error(e), _, _)
       | (_, Error(e), _)
       | (_, _, Error(e)) =>
         Error(e)
       };
     });
```

### Polymorphic Variants for Interop

```reason
/* Use polymorphic variants for JS string enums */

[@mel.module "./api"]
external setLogLevel:
  (
    [@mel.unwrap]
    [
      | `debug
      | `info
      | `warn
      | `error
    ]
  ) =>
  unit =
  "setLogLevel";

[@mel.module "./api"]
external setTheme:
  (
    [@mel.unwrap]
    [
      | `light
      | `dark
      | `system
    ]
  ) =>
  unit =
  "setTheme";

/* Usage - type-safe string values */
setLogLevel(`warn);
setTheme(`dark);

/* For more complex cases with payloads */
type apiResponse('a) = [
  | `Success('a)
  | `Error(string)
  | `Loading
  | `NotFound
];

let handleResponse = (response: apiResponse(user)) =>
  switch (response) {
  | `Success(user) =>
    Console.log("Found: " ++ user.name)

  | `Error(msg) =>
    Console.error(msg)

  | `Loading =>
    Console.log("Loading...")

  | `NotFound =>
    Console.log("User not found")
  };
```

## Module Patterns

### Module Functors

```reason
/* Module type for comparable items */
module type Comparable = {
  type t;
  let compare: (t, t) => int;
};

/* Generic sorted set module */
module MakeSortedSet = (Item: Comparable) => {
  type t = list(Item.t);

  let empty: t = [];

  let add = (set: t, item: Item.t): t => {
    let rec insert = (lst, item) =>
      switch (lst) {
      | [] =>
        [item]

      | [head, ...tail] =>
        switch (Item.compare(item, head)) {
        | n when n < 0 =>
          [item, head, ...tail]

        | 0 =>
          lst /* Already exists */

        | _ =>
          [head, ...insert(tail, item)]
        }
      };

    insert(set, item);
  };

  let toArray = (set: t): array(Item.t) =>
    Array.of_list(set);
};

/* Usage */
module IntSet =
  MakeSortedSet({
    type t = int;

    let compare = (a, b) => a - b;
  });

let set =
  IntSet.empty
  |> IntSet.add(_, 3)
  |> IntSet.add(_, 1)
  |> IntSet.add(_, 2);
```

### First-Class Modules

```reason
module type Storage = {
  let get: string => option(string);
  let set: (string, string) => unit;
  let remove: string => unit;
};

/* Pack module as value */
let localStorage: module(Storage) =
  module({
    [@mel.val] [@mel.scope "localStorage"]
    external getItem: string => Js.Nullable.t(string) = "getItem";

    [@mel.val] [@mel.scope "localStorage"]
    external setItem: (string, string) => unit = "setItem";

    [@mel.val] [@mel.scope "localStorage"]
    external removeItem: string => unit = "removeItem";

    let get = key => getItem(key) |> Js.Nullable.toOption;
    let set = setItem;
    let remove = removeItem;
  });

/* Use with any storage implementation */
let saveData = (storage: module(Storage), key: string, value: string) => {
  module S = (val storage: Storage);

  S.set(key, value);
};
```

## FFI Patterns

### Binding to Classes

```reason
/* ES6 class binding */
type websocket;

[@mel.new]
external makeWebSocket: string => websocket = "WebSocket";

[@mel.send]
external send: (websocket, string) => unit = "send";

[@mel.send]
external close: websocket => unit = "close";

[@mel.get]
external readyState: websocket => int = "readyState";

[@mel.set]
external onmessage: (websocket, Js.Json.t => unit) => unit = "onmessage";

[@mel.set]
external onerror: (websocket, Js.Exn.t => unit) => unit = "onerror";

/* Usage */
let ws = makeWebSocket("wss://example.com/socket");

ws |> onmessage(msg => Console.log2("Received:", msg));
ws |> send("{\"type\": \"ping\"}");
```

### Binding to Object Methods

```reason
/* Object with chainable methods */
type queryBuilder;

[@mel.module "./db"]
external query: string => queryBuilder = "query";

[@mel.send]
external where: (queryBuilder, string, 'a) => queryBuilder = "where";

[@mel.send]
external orderBy: (queryBuilder, string) => queryBuilder = "orderBy";

[@mel.send]
external limit: (queryBuilder, int) => queryBuilder = "limit";

[@mel.send]
external execute: queryBuilder => promise(array(Js.Json.t)) = "execute";

/* Chainable usage */
let getUsers = async () => {
  query("users")
  |> where(_, "active", true)
  |> orderBy(_, "created_at")
  |> limit(_, 10)
  |> execute;
};
```

### Binding to Callbacks

```reason
/* Node-style callbacks */
type callback('a) = (Js.Nullable.t(Js.Exn.t), 'a) => unit;

[@mel.module "fs"]
external readFile: (string, string, callback(string)) => unit = "readFile";

/* Promise wrapper */
let readFileAsync = (path: string): promise(result(string, Js.Exn.t)) =>
  Promise.make((resolve, _reject) => {
    readFile(path, "utf8", (err, data) =>
      switch (err |> Js.Nullable.toOption) {
      | Some(e) =>
        resolve(Error(e))

      | None =>
        resolve(Ok(data))
      }
    );
  });
```

### Typed Event Handlers

```reason
type mouseEvent = {
  clientX: int,
  clientY: int,
  button: int,
  preventDefault: unit => unit,
};

type keyboardEvent = {
  key: string,
  code: string,
  altKey: bool,
  ctrlKey: bool,
  shiftKey: bool,
  preventDefault: unit => unit,
};

[@mel.val] [@mel.scope "document"]
external addMouseListener:
  (
    [@mel.string]
    [
      | `click
      | `mousedown
      | `mouseup
      | `mousemove
    ],
    mouseEvent => unit,
  ) =>
  unit =
  "addEventListener";

[@mel.val] [@mel.scope "document"]
external addKeyListener:
  (
    [@mel.string]
    [
      | `keydown
      | `keyup
      | `keypress
    ],
    keyboardEvent => unit,
  ) =>
  unit =
  "addEventListener";

/* Usage */
addMouseListener(`click, event =>
  Console.log2("Clicked at:", (event.clientX, event.clientY))
);

addKeyListener(`keydown, event =>
  if (event.ctrlKey && event.key == "s") {
    event.preventDefault();
    Console.log("Save shortcut pressed");
  }
);
```

## React Patterns

### Context with Variants

```reason
type theme =
  | Light
  | Dark;

type themeContext = {
  theme: theme,
  toggleTheme: unit => unit,
};

let context =
  React.createContext({
    theme: Light,
    toggleTheme: () => (),
  });

module Provider = {
  [@react.component]
  let make = (~children: React.element) => {
    let (theme, setTheme) = React.useState(() => Light);

    let value = {
      theme,
      toggleTheme:
        () =>
          setTheme(prev =>
            switch (prev) {
            | Light => Dark
            | Dark => Light
            }
          ),
    };

    <context.Provider value>
      children
    </context.Provider>;
  };
};

/* Hook for consuming */
let useTheme = () => React.useContext(context);
```

### Custom Hook with Cleanup

```reason
type windowSize = {
  width: int,
  height: int,
};

let useWindowSize = (): windowSize => {
  let (size, setSize) =
    React.useState(() => {
      width: Webapi.Dom.Window.innerWidth(Webapi.Dom.window),
      height: Webapi.Dom.Window.innerHeight(Webapi.Dom.window),
    });

  React.useEffect0(() => {
    let handleResize = _event => {
      setSize(_prev => {
        width: Webapi.Dom.Window.innerWidth(Webapi.Dom.window),
        height: Webapi.Dom.Window.innerHeight(Webapi.Dom.window),
      });
    };

    Webapi.Dom.Window.addEventListener(
      Webapi.Dom.window,
      "resize",
      handleResize,
    );

    Some(
      () =>
        Webapi.Dom.Window.removeEventListener(
          Webapi.Dom.window,
          "resize",
          handleResize,
        ),
    );
  });

  size;
};
```

### Render Props / Children as Function

```reason
type fetchState('a) =
  | Loading
  | Success('a)
  | Error(string);

[@react.component]
let make =
    (~url: string, ~children: fetchState(Js.Json.t) => React.element) => {
  let (state, setState) = React.useState(() => Loading);

  React.useEffect1(
    () => {
      let fetchData = async () => {
        try {
          let response = await(fetch(url));
          let json = await(Response.json(response));

          setState(_prev => Success(json));
        } catch {
        | _ =>
          setState(_prev => Error("Failed to fetch"))
        };
      };

      fetchData() |> ignore;
      None;
    },
    [|url|],
  );

  children(state);
};

/* Usage */
<Fetch url="/api/users">
  {state =>
     switch (state) {
     | Loading =>
       <Spinner />

     | Success(data) =>
       <UserList data />

     | Error(msg) =>
       <ErrorMessage message=msg />
     }
  }
</Fetch>;
```

### Property-Based Testing

```reason
open FastCheck;

/* Test that reverse is involutory */
test("reverse twice returns original", () => {
  fc.assert(
    fc.property(fc.array(fc.integer()), arr => {
      arr |> Array.reverse |> Array.reverse == arr;
    }),
  );
});

/* Test sort invariants */
test("sort produces ordered array", () => {
  fc.assert(
    fc.property(fc.array(fc.integer()), arr => {
      let sorted =
        arr
        |> Array.copy
        |> Array.sort((a, b) => a - b);

      sorted
      |> Array.everyWithIndex((v, i) =>
           i == 0 || sorted |> Array.getUnsafe(i - 1) <= v
         );
    }),
  );
});
```

## Error Handling Patterns

### Railway-Oriented Programming

```reason
module Result = {
  /* Extend Result with more combinators */

  let bind = (result, fn) =>
    switch (result) {
    | Ok(v) =>
      fn(v)

    | Error(_) as e =>
      e
    };

  let map2 = (r1, r2, fn) =>
    switch ((r1, r2)) {
    | (Ok(v1), Ok(v2)) =>
      Ok(fn(v1, v2))

    | (Error(_) as e, _) =>
      e

    | (_, Error(_) as e) =>
      e
    };

  let sequence = (results: array(result('a, 'e))): result(array('a), 'e) =>
    results
    |> Array.reduce(Ok([||]), (acc, r) =>
         switch ((acc, r)) {
         | (Ok(arr), Ok(v)) =>
           Ok(Array.concat(arr, [|v|]))

         | (Error(_) as e, _) =>
           e

         | (_, Error(_) as e) =>
           e
         }
       );
};

/* Usage: compose operations that can fail */
let processOrder = (orderId: string): result(receipt, orderError) =>
  orderId
  |> validateOrderId
  |> Result.bind(fetchOrder)
  |> Result.bind(validateInventory)
  |> Result.bind(processPayment)
  |> Result.bind(generateReceipt);
```

### Tagged Errors

```reason
type apiError =
  | NetworkError({url: string, status: int})
  | ValidationError({field: string, message: string})
  | AuthError({reason: string})
  | RateLimited({retryAfter: int});

let errorToMessage = (error: apiError): string =>
  switch (error) {
  | NetworkError({url, status}) =>
    "Network error: "
    ++ url
    ++ " returned "
    ++ string_of_int(status)

  | ValidationError({field, message}) =>
    "Validation failed for " ++ field ++ ": " ++ message

  | AuthError({reason}) =>
    "Authentication failed: " ++ reason

  | RateLimited({retryAfter}) =>
    "Rate limited. Retry after "
    ++ string_of_int(retryAfter)
    ++ " seconds"
  };

let errorToStatusCode = (error: apiError): int =>
  switch (error) {
  | NetworkError(_) => 502
  | ValidationError(_) => 400
  | AuthError(_) => 401
  | RateLimited(_) => 429
  };
```

## Notes

Reason/Melange uses arrays as `[| ... |]`, while Reason lists are `[ ... ]`.

Polymorphic variants are written with backticks:

```reason
`warn
`dark
`Success(user)
```

Melange externals in Reason generally look like this:

```reason
[@mel.module "./api"]
external foo: string => unit = "foo";
```
