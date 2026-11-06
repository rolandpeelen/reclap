/*** Code point helpers. JavaScript strings index UTF-16 code units, while clap, written in
Rust, works with characters; a short name such as `-🚀` is one character but two code units. */

/** Splits `text` into its code points, so that a character outside the Basic Multilingual
Plane stays whole. */
let codePoints = text => {
  let rec collect = (index, collected) =>
    switch text->String.codePointAt(index) {
    | None => collected
    | Some(codePoint) =>
      let size = codePoint > 0xFFFF ? 2 : 1
      collect(
        index + size,
        Array.concat(collected, [text->String.slice(~start=index, ~end=index + size)]),
      )
    }
  collect(0, [])
}

/** Returns the number of code points in `text`, the display width clap uses for the
characters reclap supports. */
let width = text => codePoints(text)->Array.length
