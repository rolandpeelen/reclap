#!/bin/sh
# Regenerates the -dsource snapshots of the PPX fixtures in this directory:
# the source after the reclap PPX, printed by bsc in OCaml-like syntax.
#
#   sh test/ppx/snapshot.sh          rewrite __snapshots__/*.txt
#   sh test/ppx/snapshot.sh --check  fail when a snapshot is out of date
#
# Run `dune build` first so ppx.exe is current.
set -eu

here=$(cd "$(dirname "$0")" && pwd)
package=$(cd "$here/../.." && pwd)
bsc="$package/node_modules/.bin/bsc"
[ -x "$bsc" ] || bsc="$package/../../node_modules/.bin/bsc"
ppx="$package/ppx.exe"
mode=${1:-write}
status=0

actual=$(mktemp "${TMPDIR:-/tmp}/reclap-snapshot.XXXXXX")
trap 'rm -f "$actual"' EXIT

mkdir -p "$here/__snapshots__"
cd "$here"
for source in *.res *.resi; do
  snapshot="__snapshots__/$source.txt"
  # -only-parse stops after the PPX; -dsource prints the result to stderr.
  "$bsc" -only-parse -ppx "$ppx" -dsource "$source" >"$actual" 2>&1
  if [ "$mode" = "--check" ]; then
    if ! diff -u "$snapshot" "$actual"; then
      echo "snapshot out of date: test/ppx/$snapshot"
      status=1
    fi
  else
    cp "$actual" "$snapshot"
  fi
done

if [ "$mode" = "--check" ] && [ "$status" -eq 0 ]; then
  echo "ppx snapshots: all up to date"
fi
exit "$status"
