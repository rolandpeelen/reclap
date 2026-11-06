//! Shared helper for the fixture CLIs.
//!
//! Each CLI calls `run`. On success it writes the parsed value as JSON to the
//! file named by `CLAP_FIXTURE_OUT` and prints nothing, so stdout and stderr
//! only ever contain what clap itself prints.

use serde::Serialize;

pub fn run<T: clap::Parser + Serialize + std::fmt::Debug>() {
    let parsed = T::parse();
    if let Some(path) = std::env::var_os("CLAP_FIXTURE_OUT") {
        let json = serde_json::json!({
            "value": serde_json::to_value(&parsed).expect("serialize"),
            "debug": format!("{parsed:?}"),
        });
        std::fs::write(path, serde_json::to_string_pretty(&json).unwrap()).expect("write parsed");
    }
}
