//! Edge cases of clap's parser, usage and help, written with the builder API.
//!
//! Each subcommand isolates one behaviour; the cases in `runner.rs` name the
//! finding they cover. On success the binary writes every matched argument of
//! every level (raw values and value source) to `CLAP_FIXTURE_OUT`.

use clap::parser::ValueSource;
use clap::{Arg, ArgAction, ArgMatches, Command};
use serde_json::{json, Map, Value};

fn command() -> Command {
    Command::new("edge")
        .version("0.1.0")
        .about("Edge cases of the clap parser")
        .term_width(0)
        .subcommand(
            Command::new("flags")
                .about("Flags and counters read from the environment")
                .arg(
                    Arg::new("flag")
                        .long("flag")
                        .env("FLAG")
                        .action(ArgAction::SetTrue)
                        .help("A SetTrue flag"),
                )
                .arg(
                    Arg::new("plain")
                        .long("plain")
                        .env("PLAIN")
                        .action(ArgAction::SetFalse)
                        .help("A SetFalse flag"),
                )
                .arg(
                    Arg::new("verbose")
                        .short('v')
                        .env("VCOUNT")
                        .action(ArgAction::Count)
                        .help("A counter"),
                ),
        )
        .subcommand(
            Command::new("need")
                .about("Requires an argument, else prints help")
                .arg_required_else_help(true)
                .arg(Arg::new("name").long("name").env("NAME").help("Who")),
        )
        .subcommand(
            Command::new("pos")
                .about("A positional and a subcommand")
                .arg(Arg::new("file").help("A file"))
                .subcommand(Command::new("run").about("Run it")),
        )
        .subcommand(
            Command::new("multi")
                .about("A multi-value positional and a subcommand")
                .arg(Arg::new("files").action(ArgAction::Append).help("Files"))
                .arg(
                    Arg::new("loud")
                        .long("loud")
                        .action(ArgAction::SetTrue)
                        .help("Be loud"),
                )
                .subcommand(Command::new("run").about("Run it")),
        )
        .subcommand(
            Command::new("hid")
                .about("Hidden required arguments")
                .arg(Arg::new("secret").long("secret").required(true).hide(true))
                .arg(Arg::new("out").long("out").required(true).help("Output"))
                .arg(Arg::new("name").long("name").env("NAME").help("Name"))
                .arg(Arg::new("hid").long("hid").hide(true))
                .arg(Arg::new("opt").long("opt").help("Optional"))
                .arg(Arg::new("token").required(true).hide(true)),
        )
        .subcommand(
            Command::new("emoji")
                .about("Non-BMP characters")
                .arg(
                    Arg::new("rocket")
                        .short('🚀')
                        .long("rocket")
                        .action(ArgAction::SetTrue)
                        .help("Launch"),
                )
                .arg(
                    Arg::new("to")
                        .long("to")
                        .value_name("🌍")
                        .help("Destination"),
                )
                .arg(Arg::new("x").short('x').action(ArgAction::SetTrue).help("Ex")),
        )
        .subcommand(
            Command::new("strict")
                .about("A required subcommand and an environment value")
                .subcommand_required(true)
                .arg_required_else_help(true)
                .arg(
                    Arg::new("level")
                        .long("level")
                        .env("LEVEL")
                        .value_parser(clap::value_parser!(u8))
                        .help("Level"),
                )
                .subcommand(Command::new("go").about("Go")),
        )
}

fn source_name(source: ValueSource) -> &'static str {
    match source {
        ValueSource::DefaultValue => "DefaultValue",
        ValueSource::EnvVariable => "EnvVariable",
        ValueSource::CommandLine => "CommandLine",
        _ => "Other",
    }
}

/// Dumps one level: `{"args": {id: {"values": [...], "source": ...}}, "subcommand": ...}`.
fn dump(matches: &ArgMatches) -> Value {
    let mut ids: Vec<String> = matches.ids().map(|id| id.as_str().to_owned()).collect();
    ids.sort();
    let mut args = Map::new();
    for id in ids {
        let values: Vec<Value> = matches
            .get_raw(&id)
            .map(|raw| {
                raw.map(|value| Value::String(value.to_string_lossy().into_owned()))
                    .collect()
            })
            .unwrap_or_default();
        let source = matches.value_source(&id).map(source_name);
        args.insert(id, json!({ "values": values, "source": source }));
    }
    let subcommand = match matches.subcommand() {
        Some((name, sub)) => json!({ "name": name, "matches": dump(sub) }),
        None => Value::Null,
    };
    json!({ "args": args, "subcommand": subcommand })
}

fn main() {
    let matches = command().get_matches();
    if let Some(path) = std::env::var_os("CLAP_FIXTURE_OUT") {
        let json = json!({ "value": dump(&matches) });
        std::fs::write(path, serde_json::to_string_pretty(&json).unwrap()).expect("write parsed");
    }
}
