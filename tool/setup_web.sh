#!/usr/bin/env bash
# Puts sqlite3.wasm (the browser database engine) into web/.
#
# `dart run sqflite_common_ffi_web:setup` does this, but it also runs sqlite3's
# native build hook, which downloads a library from GitHub and fails whenever
# GitHub has a hiccup. So: try that a few times, then fall back to downloading
# just sqlite3.wasm for the sqlite3 version in pubspec.lock.
set -uo pipefail

for attempt in 1 2 3; do
  if dart run sqflite_common_ffi_web:setup; then
    exit 0
  fi
  echo "setup attempt ${attempt} failed"
  sleep $((attempt * 10))
done

echo "Falling back to downloading sqlite3.wasm directly"
version=$(awk '/^  sqlite3:/{f=1} f && /version:/{gsub(/"/, "", $2); print $2; exit}' pubspec.lock)
if [ -z "${version}" ]; then
  echo "Could not find the sqlite3 version in pubspec.lock" >&2
  exit 1
fi
echo "sqlite3 version ${version}"
mkdir -p web
curl --fail --location --retry 5 --retry-delay 10 \
  -o web/sqlite3.wasm \
  "https://github.com/simolus3/sqlite3.dart/releases/download/sqlite3-${version}/sqlite3.wasm"
