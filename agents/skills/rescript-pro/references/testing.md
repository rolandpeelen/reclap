# Testing ReScript with Vitest and FastCheck

Use Vitest for concrete behavior and FastCheck for broad invariants. Keep reducer tests at the pure transition boundary unless the effect runner is the behavior under test.

Place tests where the repository keeps them, and run the warnings-as-errors
ReScript build before Vitest runs the generated modules.

## Contents

1. Choose the test shape
2. Write Vitest examples
3. Write FastCheck properties
4. Test reducer transitions
5. Generate reducer action sequences
6. Mock effect handling only when needed

## 1. Choose the Test Shape

Use a Vitest example when the behavior is naturally stated as one scenario:

- a particular action moves a reducer into one state and emits named effects;
- a known malformed value returns a specific error;
- a regression needs one readable fixture;
- success, empty success, failure, retry, and no-op cases need explicit coverage.

Use a FastCheck property when many inputs or action sequences share one invariant:

- applying an operation twice is the same as applying it once;
- parsing and printing round-trip;
- filtering preserves every unrelated item;
- duplicate requests never emit duplicate work;
- a tool-running effect is never emitted while its worktree is preparing.

Prefer constructive generators that produce valid domain values. Bound generated collections and action sequences. Use `filter` only when constructing valid values directly would obscure the domain. Shrinking is most useful when the generator preserves the input's meaning.

## 2. Write Vitest Examples

Open the Vitest runner and matcher bindings explicitly. Keep test inputs and expected outputs visible in the test.

```rescript
open Vitest
open Expect

let expectFiltered = (input, expected) =>
  switch (Main.parse(input), Main.parse(expected)) {
  | (Ok(ast), Ok(expectedAst)) =>
    expect(ast->Utils.removeLogs->Markdown.toString)->toEqual(expectedAst->Markdown.toString)
  | (Error(_), Error(_))
  | (Error(_), Ok(_))
  | (Ok(_), Error(_)) =>
    expect(true)->toEqual(false)
  }

describe("removeLogs - list items", () => {
  test("removes log items and preserves the rest", () => {
    expectFiltered("- Regular task\n- [log] Some log entry", "- Regular task")
  })

  test("removes an item with a log tag later in the line", () => {
    expectFiltered("- Task with [log] tag\n- Normal task", "- Normal task")
  })

  test("removes log items from checkbox lists", () => {
    expectFiltered(
      "- [ ] Normal task\n- [ ] [log] Logged task\n- [ ] Another normal",
      "- [ ] Normal task\n- [ ] Another normal",
    )
  })

  test("keeps every item when none have a log tag", () => {
    let markdown = "- Task one\n- Task two\n- Task three"
    expectFiltered(markdown, markdown)
  })
})

describe("removeLogs - blocks and formatting", () => {
  test("removes paragraphs, headings, and quotes containing log tags", () => {
    expectFiltered(
      "Normal paragraph\n[log] Log paragraph\n## [log] Log heading\n> [log] Log quote\nAnother paragraph",
      "Normal paragraph\nAnother paragraph",
    )
  })

  test("finds log tags inside formatting wrappers", () => {
    expectFiltered(
      "- Normal task\n- **[log]** Bold log entry\n- *[log]* Italic log entry",
      "- Normal task",
    )
  })
})

describe("removeLogs - realistic document", () => {
  test("filters log entries from a daily note", () => {
    expectFiltered(
      `## Morning
- [ ] Review PR
- [log] Had coffee with team

## Logbook
> Place for \`[log]\` entries
- [log] Reviewed architecture doc
- [log] Fixed CI pipeline

## Afternoon
- [ ] Write tests
- [ ] Deploy`,
      `## Morning
- [ ] Review PR

## Logbook
> Place for \`[log]\` entries

## Afternoon
- [ ] Write tests
- [ ] Deploy`,
    )
  })
})
```

The helper handles both `result` constructors explicitly. A parse failure in a fixture fails the test instead of escaping through an unsafe extractor or accidentally comparing two errors as expected output.

## 3. Write FastCheck Properties

Build generators from domain values, then state one Boolean invariant per property. The current bindings expose `arbitrary<'value>`, `Fc`, `fcProperty`, and `fcAssert`.

```rescript
open Vitest
open FastCheck

let taskTextGen: arbitrary<string> = Fc.constantFrom([
  "Review PR",
  "Write tests",
  "Deploy feature",
  "Check email",
  "Update docs",
  "Fix bug",
  "Refactor code",
  "Team meeting",
  "Code review",
  "Plan sprint",
])

let listLineGen: arbitrary<(string, bool)> = Fc.tuple2(taskTextGen, Fc.boolean())

let lineToString = ((text, hasLog)) => hasLog ? "- [log] " ++ text : "- " ++ text

let listGen: arbitrary<array<(string, bool)>> = Fc.arrayWithConstraints(
  listLineGen,
  {
    minLength: 1,
    maxLength: 8,
  },
)

let noLogListGen: arbitrary<array<(string, bool)>> = Fc.arrayWithConstraints(
  taskTextGen->Fc.map(text => (text, false)),
  {
    minLength: 1,
    maxLength: 8,
  },
)

let toMarkdown = (lines: array<(string, bool)>): string =>
  lines->Array.map(lineToString)->Array.join("\n")

let rec hasLogInAst = (ast: Ast.t): bool => ast->Array.some(hasLogInBlock)
and hasLogInBlock = (block: Ast.block): bool =>
  switch block {
  | Ast.Paragraph(inlines)
  | Ast.Heading(_, inlines)
  | Ast.Quote(inlines) =>
    Utils.hasLogTag(inlines)
  | Ast.List(_, items) => items->Array.some(hasLogInItem)
  | Ast.Code(_, _)
  | Ast.AiFeedback(_)
  | Ast.Divider(_) => false
  }
and hasLogInItem = (item: Ast.ls): bool =>
  switch item {
  | Ast.Simple(_, _, inlines) => Utils.hasLogTag(inlines)
  | Ast.Nested(_, _, nested) => nested->Array.some(hasLogInItem)
  }

let countListItems = (ast: Ast.t): int =>
  ast->Array.reduce(0, (count, block) =>
    switch block {
    | Ast.List(_, items) => count + Array.length(items)
    | Ast.Paragraph(_)
    | Ast.Heading(_, _)
    | Ast.Quote(_)
    | Ast.Code(_, _)
    | Ast.AiFeedback(_)
    | Ast.Divider(_) => count
    }
  )

let checkParsed = (markdown: string, check: Ast.t => bool): bool =>
  switch Main.parse(markdown) {
  | Ok(ast) => check(ast)
  | Error(_) => false
  }

describe("removeLogs properties", () => {
  test("no log tags survive filtering", () => {
    fcAssert(
      fcProperty(
        listGen,
        lines => checkParsed(toMarkdown(lines), ast => !hasLogInAst(Utils.removeLogs(ast))),
      ),
    )
  })

  test("non-log items are preserved", () => {
    fcAssert(
      fcProperty(
        listGen,
        lines =>
          checkParsed(
            toMarkdown(lines),
            ast => {
              let expectedCount =
                lines
                ->Array.filter(((_text, hasLog)) => !hasLog)
                ->Array.length

              Utils.removeLogs(ast)->countListItems == expectedCount
            },
          ),
      ),
    )
  })

  test("filtering is idempotent", () => {
    fcAssert(
      fcProperty(
        listGen,
        lines =>
          checkParsed(
            toMarkdown(lines),
            ast => {
              let once = Utils.removeLogs(ast)
              Utils.removeLogs(once) == once
            },
          ),
      ),
    )
  })

  test("lists without log items pass through unchanged", () => {
    fcAssert(
      fcProperty(
        noLogListGen,
        lines => checkParsed(toMarkdown(lines), ast => Utils.removeLogs(ast) == ast),
      ),
    )
  })
})
```

`checkParsed` returns `false` on `Error` because `listGen` promises parseable Markdown. Returning `true` would hide a parser regression and allow a vacuous property to pass.

## 4. Test Reducer Transitions

Call `next` directly for ordinary reducer tests. Feed the returned state into the next action when the scenario spans several transitions, and assert emitted effects alongside state.

`ToolReducer` below stands for the production reducer under test; use its real state, action, and effect constructors.

```rescript
open Vitest
open Expect

module Reducer = ToolReducer

describe("tool reducer", () => {
  test("run requests stay blocked while the worktree is preparing", () => {
    let (preparing, preparationEffects) = Reducer.next(
      Reducer.initialState,
      Reducer.PrepareRequested,
    )

    expect(preparing)->toEqual(Reducer.Preparing)
    expect(preparationEffects)->toEqual([Reducer.PrepareWorktree])

    let (stillPreparing, runEffects) = Reducer.next(preparing, Reducer.RunRequested)

    expect(stillPreparing)->toEqual(Reducer.Preparing)
    expect(runEffects)->toEqual([])
  })
})
```

Do not construct a store, render React, or run real effects for a transition that `next` exposes as plain data.

## 5. Generate Reducer Action Sequences

Generate bounded action arrays when an invariant must survive arbitrary ordering. Check the invariant after every transition, not only in the final state.

```rescript
open Vitest
open FastCheck

module Reducer = ToolReducer

let actionGen: arbitrary<Reducer.action> = Fc.constantFrom([
  Reducer.PrepareRequested,
  Reducer.PreparationFinished,
  Reducer.RunRequested,
])

let actionSequenceGen = Fc.arrayWithConstraints(
  actionGen,
  {
    minLength: 0,
    maxLength: 40,
  },
)

type trace = {
  state: Reducer.state,
  safe: bool,
}

let applyAction = (trace, action) => {
  let (state, effects) = Reducer.next(trace.state, action)
  let emittedRun = effects->Array.some(effect =>
    switch effect {
    | Reducer.RunTool => true
    | Reducer.PrepareWorktree => false
    }
  )

  {
    state,
    safe: trace.safe && !(state == Reducer.Preparing && emittedRun),
  }
}

test("a tool call never runs while its worktree is preparing", () => {
  fcAssert(
    fcProperty(actionSequenceGen, actions => {
      let finalTrace = actions->Array.reduce(
        {
          state: Reducer.initialState,
          safe: true,
        },
        applyAction,
      )
      finalTrace.safe
    }),
  )
})
```

Generate from the reducer's real constructors so compiler errors reveal new actions or effects that need a testing decision. Prefer a small semantic action vocabulary over arbitrary record fields that mostly produce irrelevant cases.

## 6. Mock Effect Handling Only When Needed

Use a `StateStore` harness only when the test must cover an emitted effect dispatching another action. Delegate the production transition logic and replace only the I/O boundary.

```rescript
open Vitest
open Expect

let observedEffects: ref<array<ToolReducer.effect>> = ref([])

module TestReducer = {
  type state = ToolReducer.state
  type action = ToolReducer.action
  type effect = ToolReducer.effect

  let name = ToolReducer.name
  let next = ToolReducer.next

  let handleEffect = (effect, _state, dispatch) => {
    observedEffects := [...observedEffects.contents, effect]

    switch effect {
    | ToolReducer.PrepareWorktree => dispatch(ToolReducer.PreparationFinished)
    | ToolReducer.RunTool => ()
    }
  }
}

let makeStore = () => {
  observedEffects := []
  StateStore.make(module(TestReducer), ToolReducer.initialState)
}

test("the mocked preparation effect feeds completion back into the reducer", () => {
  let store = makeStore()

  store->StateStore.dispatch(ToolReducer.PrepareRequested)

  expect(store->StateStore.getState)->toEqual(ToolReducer.Ready)
  expect(observedEffects.contents)->toEqual([ToolReducer.PrepareWorktree])
})
```

Reset mutable test capture for every store. Keep the mock deterministic, perform no real I/O, and dispatch only the result actions needed to exercise the reducer/effect protocol.
