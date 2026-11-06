---
name: rust-pro
description: Use when writing or reviewing Rust code, including Cargo projects, .rs files, ownership and borrowing changes, async Rust, traits, error handling, clippy findings, and Rust tests.
# Development skill for this repository; not for installation by users.
metadata:
  internal: true
---

Opinionated rules for writing Rust. When in doubt, prefer the simpler thing.

The single most useful sentence here: **write Rust like OCaml**. Sum types, pattern matching, immutable data, pure functions, return values instead of mutating state. Mutation, traits-as-interfaces, smart pointers, and lifetimes are tools — not the default mode.

## Tooling — non-negotiable

Before any change is considered done, all three of these pass:

```bash
cargo fmt --check
cargo clippy --all-targets -- -D warnings
cargo test
```

`-D warnings` promotes warnings to errors. If something is going to slip in, it's going to be in the warnings, so we promote them to errors.

When clippy complains, your first move is:

```bash
cargo clippy --fix --allow-dirty --allow-staged
```

Most clippy suggestions are mechanical and correct. Apply them, re-read the diff, move on. **Do not silence the lint.**

The only acceptable use of `#[allow(clippy::...)]` is with a comment that explains why the lint is wrong for this case, **it should be used sparingly**:

```rust
#[allow(clippy::too_many_arguments)] // FFI signature mirrors the C header verbatim
extern "C" fn ffi_callback(/* … */) { /* … */ }
```

A blanket allow with no comment is treated as a code-review block.

## 1. Flat over nested

If you find yourself indenting four levels deep, restructure. Three is the soft ceiling.

❌ Don't:

```rust
fn notify(user_id: UserId) {
    if let Some(user) = lookup(user_id) {
        if user.is_active() {
            if let Some(email) = user.email() {
                send(email);
            }
        }
    }
}
```

✅ Do — early returns with `let ... else`:

```rust
fn notify(user_id: UserId) {
    let Some(user) = lookup(user_id) else { return };
    if !user.is_active() { return }
    let Some(email) = user.email() else { return };
    send(email);
}
```

The shape on the page now matches the shape of the logic: a sequence of preconditions followed by the work.

## 2. Match outside, `if` inside

When the dispatch is categorical (an enum variant, a status, a kind), `match` it. If a single arm needs a residual conditional, use a `match guard`:

✅ Do:

```rust
match status {
    Status::Pending if can_promote() => promote(),
    Status::Pending => wait(),
    Status::Active => run(),
    Status::Closed => archive(),
}
```

❌ Don't (chained `if` with a `match` buried inside):

```rust
if can_promote() {
    match status {
        Status::Pending => promote(),
        _ => run_or_archive(status),
    }
} else if status == Status::Pending {
    wait();
} else {
    /* … */
}
```

❌ Don't (nest the `if` even deeper):

```rust
match status {
    Status::Pending if can_promote() => {
        if can_promote() {
            promote();
        } else {
            wait();
        }
    }
    Status::Active => run(),
    Status::Closed => archive(),
}
```

This also keeps the match exhaustive — the compiler will yell if you add a `Status` variant later and forget a case.

**Match guards** (`Status::Pending if can_promote() => …`) are great, but they can become hard to read, and can become a problem if there are too many other clauses guarded by it. If you need `_ =>` to satisfy the compiler, you've probably gone too far. The aim is to **always match all arms explicitly**.

## 3. Mutation is local

Mutation inside a function, on a local that's born and dies there, is fine, if required (prefer immutable by default):

```rust
fn build_frobs(items: &[Item]) -> Vec<Frob> {
    let mut out = Vec::with_capacity(items.len());
    for item in items {
        out.push(Frob::from(item));
    }
    out
}
```

From the caller's perspective this function is pure. The `mut` is invisible.

What we don't do: `&mut self` methods that quietly mutate fields shared with other methods, especially when ordering matters ("you have to call `.prepare()` before `.run()`"). If a type has that smell, it's usually two types pretending to be one. Split it, or model the states as an enum.

## 4. Make illegal states unrepresentable

Sum types beat flag soups. The compiler is your exhaustiveness checker — use it.

❌ Don't:

```rust
struct Request {
    is_authenticated: bool,
    user_id: Option<UserId>,
    api_key: Option<String>,
}
```

What's a `Request { is_authenticated: false, user_id: Some(_), api_key: Some(_) }`? Nothing. It shouldn't be expressible.

✅ Do:

```rust
enum Request {
    Anonymous,
    User(UserId),
    Service { api_key: ApiKey },
}
```

Now every variant is a real, valid state, and `match` forces you to handle each one. Don't fall for the 'boolean blindness' trap.

## 5. Don't simulate inheritance with traits

Traits express **capabilities** (this thing can be hashed, displayed, serialized). They are not for building object hierarchies.

If you're writing `trait Animal { … } trait Dog: Animal { … } trait Poodle: Dog { … }`, stop. Either use an enum with variants for the closed set, or compose structs with the data they actually need. Inheritance-shaped designs in Rust fight the language for the rest of their lives.

A useful test: does the trait have _more than one method that callers actually invoke_? If not, you may be reaching for a trait where a function pointer or a closure would do.

## 6. Simple types until they're not

These appear in real Rust code, and sometimes you genuinely need them. They are also smells when they appear reflexively, before simpler options have been tried:

| Smell                                                                      | First ask yourself                                                                     |
| -------------------------------------------------------------------------- | -------------------------------------------------------------------------------------- |
| `Rc<RefCell<T>>`                                                           | Can this be single-owner? Can I pass `&mut` down or return values up?                  |
| `Arc<Mutex<T>>` everywhere                                                 | Does this _need_ shared mutable state, or can I message-pass with `tokio::sync::mpsc`? |
| `Box<dyn Future<Output = …> + Send>`                                       | Can the function just be `async fn`? Or return `impl Future`?                          |
| `Box<dyn Trait>`                                                           | Would generics work? Is dynamic dispatch actually needed?                              |
| 3-line generic bounds (`where T: Foo + Bar + 'static + Send + Sync, U: …`) | Is this layer of abstraction earning its keep?                                         |

The default vocabulary is `String`, `&str`, `Vec<T>`, `&[T]`, `Option<T>`, `Result<T, E>`, owned structs, plain enums, and `async fn`. That gets you very, very far.

## 7. Functions are small, named, mostly pure

- One function, one job. If you can't name it crisply, it's probably two functions.
- Prefer arguments to captured environment.
- Constructors are `Type::new()` / `Type::with_capacity()`, not free `make_type()` functions.
- Return owned values when you can. Borrows are an optimization, not a default.

## 8. Fat models

When a struct has operations that belong to it, write them as methods on the struct, not as free functions named `verb_struct`. The data and the things you do with it live together — that's what "fat model" means here.

The smell is when the action ends up encoded in the type name (`InsertScan`, `BuildRequest`, `RenderCard`), or in a free function that takes the model as its first argument (`insert_scan(&conn, scan)`, `finalize_scan(&conn, scan_id)`, `summarize(&conn, scan_id, …)`). That's an OO-shaped API written in functional clothes, and it scatters everything a reader would want to know about a `Scan` across the module.

❌ Don't:

```rust
pub struct InsertScan<'a> {
    pub repository_id: i64,
    pub base_ref: &'a str,
    /* … */
}

pub fn insert_scan(connection: &Connection, row: InsertScan<'_>) -> Result<i64> { /* … */ }
pub fn finalize_scan(connection: &Connection, scan_id: i64) -> Result<()> { /* … */ }
pub fn summarize(
    connection: &Connection,
    scan_id: i64,
    repository_id: i64,
) -> Result<ScanSummary> { /* … */ }
```

The struct is named after the action; the free functions take the model by value or by id; there is nowhere a reader can land to "see what a `Scan` is".

✅ Do — one `Scan` type, methods on it, names that don't double-encode `Scan`:

```rust
pub struct Scan {
    pub repository_id: i64,
    pub base_ref: String,
    pub base_sha: String,
    pub merge_base_sha: String,
    pub head_sha: String,
    pub max_depth: u32,
    pub since_date: String,
}

impl Scan {
    /// Persist this scan and return its assigned id.
    pub fn insert(self, connection: &Connection) -> Result<i64> { /* … */ }

    /// Mark a previously-inserted scan as complete.
    pub fn finalize_by_id(connection: &Connection, scan_id: i64) -> Result<()> { /* … */ }

    /// Aggregate counters for a previously-inserted scan.
    pub fn summarize(
        connection: &Connection,
        scan_id: i64,
        repository_id: i64,
    ) -> Result<ScanSummary> { /* … */ }
}
```

Three things changed:

1. **One struct, not a struct-per-action.** `InsertScan` is gone; `Scan` is the model.
2. **Methods, not free functions.** `Scan::insert`, `Scan::finalize_by_id`, and `Scan::summarize` all live on the type. `Scan::insert` takes `self` because you build a `Scan` and then insert it — by-value is right here, because after the insert the in-memory `Scan` has been superseded by the row in the database. `Scan::finalize_by_id` and `Scan::summarize` are associated functions (no `self`) because the only thing they need is the id of an already-persisted row; they say so by name.
3. **Names no longer double-encode the type.** `Scan::insert_scan` would stutter; `Scan::insert` reads cleanly at the call site as `scan.insert(&connection)?`.

When the field list is long enough that `Scan { … }` is awkward to construct (or callers don't have all the fields at once), reach for a `Scan::new(…)` constructor or derive a builder — but the builder lives on `Scan`, not as a separate `BuildScan` type.

**Return types that are genuinely their own noun are fine as separate structs.** `ScanSummary` is a result, not an action — it's the _answer_ `Scan::summarize` produces, and it earns its own struct (with its own `impl` if behavior accretes on it). The line: a struct whose existence _is_ the action (`InsertScan`, `BuildRequest`) is a smell; a struct that names a noun in the domain (`ScanSummary`, `Repository`, `BlameRequest`) is not.

## 9. Errors

Already covered in `README.md`, restated here as a rule:

- **Apps / `main.rs`** → `anyhow::Result`, propagate with `?`, add `.context("what was happening")`.
- **Libraries / public APIs** → `thiserror`-derived error enum, one variant per failure mode.
- **Never `.unwrap()`. Anywhere.** Not in app code, not in library code, not in tests, not in examples. There is no context where `.unwrap()` is the right choice — `.expect("message")` is strictly better because the panic carries a clue about what was assumed. If you catch yourself reaching for `.unwrap()`, replace it with `.expect()` at minimum, and almost certainly with something better than that.
- **`.expect()` is a last resort, not a convenience.** Use it only when the program genuinely cannot continue and crashing the whole process is the correct response — e.g. a missing compiled-in resource at startup, a poisoned mutex that indicates the process is already corrupt. In practice this is ~0.001% of cases. The default move when you have a `Result` or `Option` is to handle it: propagate with `?`, `match` on it and return an error, or exit with a non-zero status code via `std::process::exit`. Returning an error and letting the caller decide is almost always better than panicking.
- **In tests, prefer `?` over `.expect()`.** Write tests that return `Result<()>` and use `?` so a failure surfaces as a normal test failure with the underlying error, rather than a panic message you wrote by hand. If you do need to assert "this must be `Ok`" inline, use `.expect("…")` — never `.unwrap()`.

Avoid stringly-typed errors (`MyError(String)`) — they're the error-handling equivalent of flag soups.

## 10. Iterators, within reason

`items.iter().filter(…).map(…).collect()` is great — until the chain is eight steps long or four lines tall. Then it stops being clearer than a `for` loop. Start / prefer iterators, but when needed, break it up, give the intermediate values names.

## 11. Comments

Comment **why**, not **what**. The code already says what.

Bad:

```rust
// increments counter
counter += 1;
```

Good:

```rust
// retry budget — server returns 503 for ~30s after a deploy, so we burn a few attempts
counter += 1;
```

Public items (`pub fn`, `pub struct`, `pub enum`) get `///` doc comments. The first sentence is a one-line summary; the rest can elaborate.

## 12. Variable names are spelled out

No single-letter variable names. Not `i` for a loop index, not `x` for a closure parameter, not `e` for an error binding, not `n` for a count. Every binding gets a name that says what it is, in full words.

❌ Don't:

```rust
for i in 0..items.len() {
    let x = &items[i];
    process(x);
}

let total: i32 = nums.iter().map(|n| n * 2).sum();

result.map_err(|e| log_error(e))?;
```

✅ Do:

```rust
for index in 0..items.len() {
    let item = &items[index];
    process(item);
}

let total: i32 = numbers.iter().map(|number| number * 2).sum();

result.map_err(|error| log_error(error))?;
```

The rule covers every binding site: `let`, function parameters, closure parameters, `for` variables, `match` arm captures, `if let` / `while let`.

Spell things out, too. Prefer `context` over `ctx`, `request` over `req`, `response` over `resp`, `error` over `err`, `index` over `idx`, `count` over `cnt`, `buffer` over `buf`. The exception is when the short form is the genuine term of art for the domain — `api_key` is fine, nobody writes `application_programming_interface_key`; `url`, `id`, `db` are likewise terms in their own right. The test is whether a new reader, encountering the name cold, would know what it refers to.

The one carve-out from the no-single-letter rule is **generic type parameters** — `T`, `U`, `E`, `K`, `V` and friends. Those are not runtime variables, and the single-uppercase-letter convention is universal across the Rust ecosystem. Use it.

Finally: `_` as a deliberate "I am ignoring this" binding (`let _ = …`, `|_| …`, `Ok(_) => …`) is not a name and is fine. A leading-underscore name (`_unused_buffer`) for a value you must keep alive but won't read is also fine.

## 13. Declare before use

The Rust compiler doesn't care about item order within a file — a function near the top can freely call a function defined at the bottom, reference a type declared later, and so on. **We don't take advantage of that**. Files read top-to-bottom: every item appears **above** the code that uses it. No forward references, no "hoisting".

The order within a file is therefore:

1. `use` statements
2. Constants and statics
3. Type definitions (`struct`, `enum`, `type`), each followed immediately by its `impl` blocks
4. Free functions, with callees above callers
5. `fn main` (in a binary)
6. `#[cfg(test)] mod tests { … }`

❌ Don't — caller above callee:

```rust
fn main() {
    let result = double(21);
    println!("{result}");
}

fn double(value: i32) -> i32 {
    value * 2
}
```

✅ Do — callee above caller:

```rust
fn double(value: i32) -> i32 {
    value * 2
}

fn main() {
    let result = double(21);
    println!("{result}");
}
```

❌ Don't — function references a type declared below it:

```rust
fn render(card: &Card) { /* … */ }

struct Card {
    title: String,
    body: String,
}
```

✅ Do — type and its `impl` first, functions that use it after:

```rust
struct Card {
    title: String,
    body: String,
}

impl Card { /* … */ }

fn render(card: &Card) { /* … */ }
```

The one place this rule genuinely can't hold is **mutual recursion** — two functions that call each other can't both come first. Pick the one that's the more natural entry point of the pair and put the other above it; a short comment helps when it isn't obvious which is which.

The test module is the intentional exception: `#[cfg(test)] mod tests` sits at the bottom and references everything above it. That's fine — tests are always callers, never callees.

## Self-review checklist

Before you push:

- [ ] `cargo fmt`, `cargo clippy --all-targets -- -D warnings`, `cargo test` all pass
- [ ] No `#[allow(...)]` without a one-line justification comment
- [ ] No nesting deeper than three levels
- [ ] No `.unwrap()` anywhere — not in src, not in tests, not in examples
- [ ] No `.expect()` unless the process genuinely cannot continue (with a comment explaining why); prefer `?` / `match` / `process::exit` instead
- [ ] No `.clone()` added to silence the borrow checker without first trying to restructure
- [ ] No `Rc<RefCell<_>>` / `Arc<Mutex<_>>` / `Box<dyn …>` without a one-line justification
- [ ] No struct-per-action (`InsertScan`, `BuildRequest`) — actions are methods on the model, named without re-stuttering the type
- [ ] No single-letter variable names (generic type parameters like `T`, `U`, `E` excepted); names are spelled out in full rather than abbreviated
- [ ] No forward references — every item appears in the file above the code that uses it (tests module excepted)
- [ ] Public items have `///` doc comments
- [ ] Function names are verbs that describe what they do

