/*** Code point helpers. JavaScript strings index UTF-16 code units, while clap, written in
Rust, works with characters; a short name such as `-🚀` is one character but two code units. */

/** Splits `text` into its code points, so that a character outside the Basic Multilingual
Plane stays whole. */
let codePoints: string => array<string>

/** Returns the number of code points in `text`, the display width clap uses for the
characters reclap supports. */
let width: string => int
