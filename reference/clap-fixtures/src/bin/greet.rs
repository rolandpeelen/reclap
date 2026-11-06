use clap::{ArgAction, Parser, ValueEnum};
use serde::Serialize;

/// Simple program to greet a person
///
/// Greets NAME a number of times. This second paragraph only appears in the
/// long help (`--help`), as clap's `long_about`.
#[derive(Parser, Debug, Serialize)]
#[command(name = "greet", version = "1.0.0", term_width = 0)]
struct Greet {
    /// Name of the person to greet
    #[arg(short, long)]
    name: String,

    /// Number of times to greet
    #[arg(short, long, default_value_t = 1)]
    count: u8,

    /// Increase verbosity
    #[arg(short, action = ArgAction::Count)]
    verbose: u8,

    /// Greeting to use instead of "Hello"
    greeting: Option<String>,

    /// Tag to attach (repeatable)
    #[arg(short, long)]
    tag: Vec<String>,

    /// Language of the greeting
    #[arg(long, env = "GREET_LANG")]
    lang: Option<String>,

    /// Colour of the output
    #[arg(long, value_enum, default_value_t = Color::Auto)]
    color: Color,

    /// Offset added to the count.
    #[arg(long, default_value_t = 0)]
    offset: i32,

    /// Internal option, hidden from help
    #[arg(long, hide = true)]
    secret: Option<String>,

    /// Shout the greeting.
    ///
    /// Prints the greeting in upper case and appends an exclamation mark.
    /// Only `--help` shows this paragraph.
    #[arg(short, long)]
    shout: bool,
}

#[derive(ValueEnum, Clone, Debug, Serialize)]
enum Color {
    /// Always colour the output
    Always,
    /// Never colour the output
    #[value(alias = "off")]
    Never,
    /// Colour the output when stdout is a terminal
    Auto,
}

fn main() {
    clap_fixtures::run::<Greet>();
}
