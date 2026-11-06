#!/bin/sh
# Negative tests: every fixture in this directory must fail to compile with
# the message in its `// expect:` comment, reported on the line in its
# `// line:` comment. Fixtures may use the runtime, so build the ReScript
# package first (`npx rescript build`) for lib/ocaml.
#
#   sh ppx/test/errors/run.sh    (from packages/reclap, after `dune build`)
set -eu

here=$(cd "$(dirname "$0")" && pwd)
package=$(cd "$here/../../.." && pwd)
bsc="$package/node_modules/.bin/bsc"
[ -x "$bsc" ] || bsc="$package/../../node_modules/.bin/bsc"
ppx="$package/ppx.exe"
work=$(mktemp -d "${TMPDIR:-/tmp}/reclap-errors.XXXXXX")
trap 'rm -rf "$work"' EXIT
passed=0
failed=0

for fixture in "$here"/*.res "$here"/*.resi; do
  [ -e "$fixture" ] || continue
  name=$(basename "$fixture")
  expected=$(sed -n 's#^// expect: ##p' "$fixture")
  line=$(sed -n 's#^// line: ##p' "$fixture")
  cp "$fixture" "$work/$name"
  # Compile from a scratch directory so no build artefacts land in the repo.
  if output=$(cd "$work" && "$bsc" -I "$package/lib/ocaml" -ppx "$ppx" "$name" 2>&1); then
    echo "FAIL $name: compiled, but should have failed"
    failed=$((failed + 1))
    continue
  fi
  plain=$(printf '%s\n' "$output" | sed 's/\x1b\[[0-9;]*m//g' | tr '\n' ' ' | tr -s ' ')
  if ! printf '%s' "$plain" | grep -qF -- "$expected"; then
    echo "FAIL $name: expected message not found: $expected"
    printf '%s\n' "$output" | sed 's/\x1b\[[0-9;]*m//g' | sed 's/^/    /'
    failed=$((failed + 1))
  elif [ -n "$line" ] && ! printf '%s' "$plain" | grep -qF -- "$name:$line:"; then
    echo "FAIL $name: error not reported on line $line"
    printf '%s\n' "$output" | sed 's/\x1b\[[0-9;]*m//g' | sed 's/^/    /'
    failed=$((failed + 1))
  else
    passed=$((passed + 1))
  fi
done

echo "ppx error tests: $passed passed, $failed failed"
[ "$failed" -eq 0 ]
