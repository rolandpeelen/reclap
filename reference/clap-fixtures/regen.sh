#!/bin/sh
# Regenerates packages/reclap/test/fixtures/clap/*.json from real clap output.
set -eu
cd "$(dirname "$0")"
cargo build --locked --bins
./target/debug/runner ../../packages/reclap/test/fixtures/clap
