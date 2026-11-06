//! Runs every fixture CLI against its argv cases and writes one JSON file per
//! CLI. Usage: `runner <output-dir>`. Build all binaries first
//! (`cargo build --bins`); see `regen.sh`.

use std::path::{Path, PathBuf};
use std::process::Command;

use serde::Serialize;
use serde_json::Value;

struct Case {
    name: &'static str,
    argv: &'static [&'static str],
    env: &'static [(&'static str, &'static str)],
}

const fn case(name: &'static str, argv: &'static [&'static str]) -> Case {
    Case { name, argv, env: &[] }
}

const fn case_env(
    name: &'static str,
    argv: &'static [&'static str],
    env: &'static [(&'static str, &'static str)],
) -> Case {
    Case { name, argv, env }
}

const GREET: &[Case] = &[
    // Help and version.
    case("short-help", &["-h"]),
    case("long-help", &["--help"]),
    case("short-version", &["-V"]),
    case("long-version", &["--version"]),
    case("help-after-args", &["-n", "x", "--help"]),
    case_env("long-help-with-env-set", &["--help"], &[("GREET_LANG", "fr")]),
    case("help-subcommand-absent", &["help"]),
    case("empty-argv", &[]),
    // Successful parses.
    case("long-equals", &["--name=Ann"]),
    case("long-space", &["--name", "Ann"]),
    case("short-attached", &["-nAnn"]),
    case("short-space", &["-n", "Ann"]),
    case("short-equals", &["-n=Ann"]),
    case("count-vvv", &["-n", "Ann", "-vvv"]),
    case("count-separate", &["-v", "-n", "Ann", "-v"]),
    case("combined-flags-then-value", &["-vn", "Ann"]),
    case("combined-flags-attached-value", &["-vsnAnn"]),
    case("default-fallback", &["--name", "Ann"]),
    case("explicit-count", &["--name", "Ann", "--count", "3"]),
    case("explicit-count-short-attached", &["--name", "Ann", "-c4"]),
    case("positional", &["--name", "Ann", "Hi"]),
    case("double-dash-positional", &["--name", "Ann", "--", "-dashed"]),
    case("double-dash-then-option-like", &["--name", "Ann", "--", "--count"]),
    case("append-repeated", &["-n", "Ann", "-t", "a", "--tag", "b", "--tag=c", "-td"]),
    case_env("env-fallback", &["--name", "Ann"], &[("GREET_LANG", "fr")]),
    case_env("env-overridden-by-arg", &["--name", "Ann", "--lang", "de"], &[("GREET_LANG", "fr")]),
    case_env("env-empty", &["--name", "Ann"], &[("GREET_LANG", "")]),
    case("value-enum", &["--name", "Ann", "--color", "always"]),
    case("value-enum-alias", &["--name", "Ann", "--color", "off"]),
    case("negative-number-equals", &["--name", "Ann", "--offset=-3"]),
    case("negative-number-attached-short-like", &["--name", "Ann", "--offset", "-3"]),
    case("hidden-arg", &["--name", "Ann", "--secret", "s"]),
    case("bool-flag", &["--name", "Ann", "--shout"]),
    case("positional-before-options", &["Hi", "--name", "Ann"]),
    case("single-dash-positional", &["--name", "Ann", "-"]),
    // Errors.
    case("missing-required", &[]),
    case("missing-required-with-other-args", &["-v", "Hi"]),
    case("missing-value-long-at-end", &["--name"]),
    case("missing-value-short-at-end", &["-n"]),
    case("missing-value-before-flag", &["--name", "--shout"]),
    case("missing-value-equals-empty", &["--name="]),
    case("unknown-long-with-suggestion", &["--name", "Ann", "--cout", "2"]),
    case("unknown-long-without-suggestion", &["--name", "Ann", "--zzz"]),
    case("unknown-short", &["--name", "Ann", "-x"]),
    case("unknown-short-in-cluster", &["--name", "Ann", "-vx"]),
    case("unexpected-extra-positional", &["--name", "Ann", "Hi", "extra"]),
    case("invalid-int", &["--name", "Ann", "--count", "abc"]),
    case("invalid-int-too-large", &["--name", "Ann", "--count", "300"]),
    case("invalid-int-negative-for-unsigned", &["--name", "Ann", "--count=-1"]),
    case("invalid-int-empty", &["--name", "Ann", "--count="]),
    case("negative-number-unsigned-space", &["--name", "Ann", "--count", "-1"]),
    case("invalid-value-enum-with-suggestion", &["--name", "Ann", "--color", "alwys"]),
    case("missing-value-enum", &["--name", "Ann", "--color"]),
    case("invalid-value-enum-without-suggestion", &["--name", "Ann", "--color", "purple"]),
    case("flag-with-value", &["--name", "Ann", "--shout=x"]),
    case("flag-with-empty-value", &["--name", "Ann", "--shout="]),
    case("repeated-single-value-arg", &["--name", "Ann", "--name", "Bob"]),
    case("repeated-single-value-arg-long-and-short", &["--name", "Ann", "--count", "3", "-c4"]),
    case("repeated-flag", &["--name", "Ann", "--shout", "--shout"]),
    case("repeated-short-flag", &["--name", "Ann", "-ss"]),
    case("unknown-argument-looks-like-positional-dash", &["--name", "Ann", "-dashed"]),
];

const GIT: &[Case] = &[
    // Help and version.
    case("empty-argv", &[]),
    case("short-help", &["-h"]),
    case("long-help", &["--help"]),
    case("short-version", &["-V"]),
    case("long-version", &["--version"]),
    case("help", &["help"]),
    case("help-clone", &["help", "clone"]),
    case("help-remote", &["help", "remote"]),
    case("help-remote-add", &["help", "remote", "add"]),
    case("help-help", &["help", "help"]),
    case("help-unknown", &["help", "nope"]),
    case("help-alias", &["help", "ci"]),
    case("clone-short-help", &["clone", "-h"]),
    case("clone-long-help", &["clone", "--help"]),
    case("add-help", &["add", "--help"]),
    case("status-help", &["status", "--help"]),
    case("commit-help", &["commit", "--help"]),
    case("remote-help", &["remote", "--help"]),
    case("remote-add-help", &["remote", "add", "--help"]),
    case("stash-help", &["stash", "--help"]),
    case("stash-empty", &["stash"]),
    case("rm-help", &["rm", "-h"]),
    case("subcommand-version", &["clone", "--version"]),
    // Successful parses.
    case("clone", &["clone", "https://example.com/repo"]),
    case("clone-with-dir", &["clone", "--depth", "1", "https://example.com/repo", "out"]),
    case("global-before-subcommand", &["-C", "/tmp", "-q", "status"]),
    case("global-after-subcommand", &["status", "-q"]),
    case("add-newtype", &["add", "-n", "a.txt", "b.txt"]),
    case("add-no-paths", &["add"]),
    case("unit-variant", &["status"]),
    case("hidden-alias", &["st"]),
    case("visible-alias", &["ci", "-m", "msg"]),
    case("commit-combined", &["commit", "-am", "msg"]),
    case("remote-without-subcommand", &["remote"]),
    case("remote-verbose", &["remote", "-v"]),
    case("remote-add", &["remote", "add", "origin", "https://example.com/repo"]),
    case("remote-remove-alias", &["remote", "rm", "origin"]),
    case("stash-push", &["stash", "push", "-m", "wip"]),
    case("stash-pop", &["stash", "pop"]),
    case("stash-pop-help", &["stash", "pop", "-h"]),
    case("stash-pop-long-help", &["stash", "pop", "--help"]),
    case("undocumented-subcommand", &["gc"]),
    case("rm-many", &["rm", "a", "b", "c"]),
    case("rm-double-dash", &["rm", "--", "-a", "--b"]),
    case("rm-none", &["rm"]),
    // Errors.
    case("unknown-subcommand-with-suggestion", &["comit"]),
    case("unknown-subcommand-without-suggestion", &["frobnicate"]),
    case("unknown-nested-subcommand", &["remote", "ad", "x", "y"]),
    case("unknown-long-top", &["--quite", "status"]),
    case("unknown-long-in-subcommand", &["commit", "--mesage", "x"]),
    case("unknown-long-for-other-subcommand", &["status", "--depth", "1"]),
    case("missing-required-in-subcommand", &["commit"]),
    case("missing-positional", &["clone"]),
    case("missing-nested-positionals", &["remote", "add"]),
    case("invalid-int-in-subcommand", &["clone", "--depth", "x", "r"]),
    case("unexpected-positional-for-unit-variant", &["status", "extra"]),
    case("flag-with-value", &["-q=yes", "status"]),
    case("missing-value-short", &["-C"]),
    case("missing-subcommand-with-args", &["-q"]),
    case("unknown-subcommand-several-suggestions", &["sta"]),
    case("unknown-long-suggested-from-subcommand", &["--dept", "1", "clone", "r"]),
    case("double-dash-before-subcommand", &["--", "status"]),
    case("nested-help-subcommand", &["remote", "help", "add"]),
    case("unexpected-extra-positional-nested", &["remote", "add", "a", "b", "c"]),
];

const EDGE: &[Case] = &[
    // Help, usage and version of the root.
    case("short-help", &["-h"]),
    case("empty-argv", &[]),
    case("help-with-value", &["--help=foo"]),
    case("version-with-value", &["--version=1"]),
    case("subcommand-help-with-value", &["flags", "--help=foo"]),
    // Flags and counters: defaults and environment values.
    case("flags-absent", &["flags"]),
    case("flags-given", &["flags", "--flag", "--plain", "-vv"]),
    case_env("flags-env-true", &["flags"], &[("FLAG", "true"), ("PLAIN", "true")]),
    case_env("flags-env-false", &["flags"], &[("FLAG", "false"), ("PLAIN", "false")]),
    case_env("flag-env-yes", &["flags"], &[("FLAG", "yes")]),
    case_env("flag-env-similar", &["flags"], &[("FLAG", "ture")]),
    case_env("flag-env-empty", &["flags"], &[("FLAG", "")]),
    case_env("set-false-env-garbage", &["flags"], &[("PLAIN", "1")]),
    case_env("flag-env-ignored-when-given", &["flags", "--flag"], &[("FLAG", "garbage")]),
    case_env("count-env", &["flags"], &[("VCOUNT", "3")]),
    case_env("count-env-invalid", &["flags"], &[("VCOUNT", "x")]),
    case_env("count-env-too-large", &["flags"], &[("VCOUNT", "300")]),
    case_env("count-env-ignored-when-given", &["flags", "-v"], &[("VCOUNT", "7")]),
    case_env("flags-help-with-env", &["flags", "--help"], &[("FLAG", "yes"), ("VCOUNT", "2")]),
    // arg_required_else_help counts environment values as given.
    case("need-empty", &["need"]),
    case_env("need-env", &["need"], &[("NAME", "bob")]),
    case("need-given", &["need", "--name", "ann"]),
    // A positional and subcommands.
    case("pos-unexpected-after-full", &["pos", "a", "zzz"]),
    case("pos-transposed-word-after-full", &["pos", "a", "rnu"]),
    case("pos-similar-subcommand-after-full", &["pos", "a", "runn"]),
    case("flags-extra-word-without-subcommands", &["flags", "zzz"]),
    case("pos-similar-word-fills-positional", &["pos", "rnu"]),
    case("pos-then-subcommand", &["pos", "a", "run"]),
    case("pos-help", &["pos", "-h"]),
    case("pos-unknown-long", &["pos", "--zzz"]),
    // A multi-value positional and subcommands.
    case("multi-subcommand-name-is-value", &["multi", "a", "b", "run"]),
    case("multi-subcommand-after-one-value", &["multi", "a", "run"]),
    case("multi-subcommand-first", &["multi", "run"]),
    case("multi-subcommand-after-flag", &["multi", "a", "--loud", "run"]),
    case("multi-subcommand-after-double-dash", &["multi", "--", "run"]),
    // Hidden required arguments.
    case("hid-help", &["hid", "-h"]),
    case_env("hid-missing-with-env", &["hid", "--hid", "h"], &[("NAME", "n")]),
    case("hid-missing", &["hid"]),
    case("hid-unknown-after-hidden", &["hid", "--hid", "h", "--bogus"]),
    case("hid-unknown-after-visible", &["hid", "--opt", "o", "--bogus"]),
    case("hid-unknown-suggests-hidden", &["hid", "--opt", "o", "--secrt", "s"]),
    case("hid-flag-like-value-unknown-short", &["hid", "-q"]),
    case("hid-complete", &["hid", "--secret", "s", "--out", "o", "t"]),
    // Non-BMP characters.
    case("emoji-help", &["emoji", "-h"]),
    case("emoji-short", &["emoji", "-🚀"]),
    case("emoji-cluster", &["emoji", "-x🚀"]),
    case("emoji-repeated", &["emoji", "-🚀🚀"]),
    case("emoji-unknown-short", &["emoji", "-🛸"]),
    // Environment errors before the missing subcommand.
    case_env("strict-invalid-env", &["strict"], &[("LEVEL", "abc")]),
    case_env("strict-valid-env", &["strict"], &[("LEVEL", "3")]),
    case("strict-empty", &["strict"]),
    case_env("strict-invalid-env-with-subcommand", &["strict", "go"], &[("LEVEL", "300")]),
];

#[derive(Serialize)]
struct Fixture<'a> {
    cli: &'a str,
    #[serde(rename = "clapVersion")]
    clap_version: String,
    cases: Vec<CaseResult<'a>>,
}

#[derive(Serialize)]
struct CaseResult<'a> {
    name: &'a str,
    argv: Vec<&'a str>,
    env: serde_json::Map<String, Value>,
    #[serde(rename = "exitCode")]
    exit_code: i32,
    stdout: String,
    stderr: String,
    /// `{value, debug}` on success: `value` is the serde JSON of the parsed
    /// struct, `debug` its `{:?}` rendering. `null` when clap exited.
    parsed: Value,
}

fn clap_version() -> String {
    let lock = std::fs::read_to_string(Path::new(env!("CARGO_MANIFEST_DIR")).join("Cargo.lock"))
        .expect("read Cargo.lock");
    let mut lines = lock.lines();
    while let Some(line) = lines.next() {
        if line == "name = \"clap\"" {
            let version = lines.next().expect("version line");
            return version
                .trim_start_matches("version = \"")
                .trim_end_matches('"')
                .to_string();
        }
    }
    panic!("clap not found in Cargo.lock")
}

fn run_cli(bin_dir: &Path, cli: &'static str, cases: &'static [Case], tmp: &Path) -> Fixture<'static> {
    let exe = bin_dir.join(cli);
    let results = cases
        .iter()
        .map(|c| {
            let out_file = tmp.join(format!("{cli}-{}.json", c.name));
            let _ = std::fs::remove_file(&out_file);
            let mut cmd = Command::new(&exe);
            cmd.args(c.argv).env_clear().env("CLAP_FIXTURE_OUT", &out_file);
            for (k, v) in c.env {
                cmd.env(k, v);
            }
            let output = cmd.output().expect("run cli");
            let parsed = match std::fs::read_to_string(&out_file) {
                Ok(s) => serde_json::from_str(&s).expect("parse parsed json"),
                Err(_) => Value::Null,
            };
            CaseResult {
                name: c.name,
                argv: c.argv.to_vec(),
                env: c
                    .env
                    .iter()
                    .map(|(k, v)| (k.to_string(), Value::String(v.to_string())))
                    .collect(),
                exit_code: output.status.code().expect("exit code"),
                stdout: String::from_utf8(output.stdout).expect("utf8 stdout"),
                stderr: String::from_utf8(output.stderr).expect("utf8 stderr"),
                parsed,
            }
        })
        .collect();
    Fixture { cli, clap_version: clap_version(), cases: results }
}

fn main() {
    let out_dir = PathBuf::from(std::env::args().nth(1).expect("usage: runner <output-dir>"));
    std::fs::create_dir_all(&out_dir).expect("create output dir");
    let bin_dir = std::env::current_exe().unwrap().parent().unwrap().to_path_buf();
    let tmp = std::env::temp_dir().join(format!("clap-fixtures-{}", std::process::id()));
    std::fs::create_dir_all(&tmp).unwrap();
    for (cli, cases) in [("greet", GREET), ("git", GIT), ("edge", EDGE)] {
        let fixture = run_cli(&bin_dir, cli, cases, &tmp);
        let path = out_dir.join(format!("{cli}.json"));
        let mut json = serde_json::to_string_pretty(&fixture).unwrap();
        json.push('\n');
        std::fs::write(&path, json).expect("write fixture");
        println!("wrote {} ({} cases)", path.display(), fixture.cases.len());
    }
    let _ = std::fs::remove_dir_all(&tmp);
}
