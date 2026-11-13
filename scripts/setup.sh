#!/usr/bin/env bash
# Validate the `model` and `version` inputs, then download a llama.cpp build,
# check its SHA-256, and unpack it.
#
# Inputs arrive as environment variables. Neither is ever evaluated by the
# shell, and both must match a strict pattern before they are used.
set -euo pipefail

fail() {
  echo "::error::$1"
  exit 1
}

# jq on Windows writes CRLF line endings; drop the carriage returns.
jq_raw() {
  jq -r "$@" | tr -d '\r'
}

pin_file="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/llama-cpp-pin.json"
pinned=$(jq_raw '.version' "$pin_file")

# Error messages never repeat the rejected value: it is untrusted, and the job
# log interprets workflow commands.
name='[A-Za-z0-9][A-Za-z0-9._-]*'
if [[ ! ${INPUT_MODEL:-} =~ ^$name/$name(:$name)?$ ]]; then
  fail "Invalid model: expected <user>/<repo> or <user>/<repo>:<quant>"
fi

version=${INPUT_VERSION:-$pinned}
if [[ ! $version =~ ^b[0-9]+$ ]]; then
  fail "Invalid version: expected a llama.cpp build tag such as $pinned"
fi

# Keep in sync with the archive list in update-pin.sh.
case "${RUNNER_OS}-${RUNNER_ARCH}" in
  Linux-X64) suffix=ubuntu-x64.tar.gz ;;
  Linux-ARM64) suffix=ubuntu-arm64.tar.gz ;;
  macOS-ARM64) suffix=macos-arm64.tar.gz ;;
  macOS-X64) suffix=macos-x64.tar.gz ;;
  Windows-X64) suffix=win-cpu-x64.zip ;;
  Windows-ARM64) suffix=win-cpu-arm64.zip ;;
  *) fail "Unsupported runner: ${RUNNER_OS} ${RUNNER_ARCH}" ;;
esac
asset="llama-$version-bin-$suffix"

if [ "$version" = "$pinned" ]; then
  # The default build is checked against checksums committed in this repo.
  expected=$(jq_raw --arg asset "$asset" '.sha256[$asset] // empty' "$pin_file")
else
  # Any other build is checked against the digest GitHub recorded for it.
  api="https://api.github.com/repos/ggml-org/llama.cpp/releases/tags/$version"
  if [ -n "${GH_TOKEN:-}" ]; then
    # The token goes to curl on stdin so it never appears in a process list.
    release=$(printf 'Authorization: Bearer %s\n' "$GH_TOKEN" |
      curl -fsSL --retry 3 -H @- "$api") ||
      fail "Could not look up llama.cpp $version"
  else
    release=$(curl -fsSL --retry 3 "$api") ||
      fail "Could not look up llama.cpp $version"
  fi
  expected=$(jq_raw --arg asset "$asset" \
    '.assets[] | select(.name == $asset) | .digest // empty | ltrimstr("sha256:")' \
    <<<"$release")
fi
if [[ ! $expected =~ ^[0-9a-f]{64}$ ]]; then
  fail "No SHA-256 checksum is available for $asset"
fi

cd "$RUNNER_TEMP"
dir=$(mktemp -d llama-server-action-XXXXXX)
cd "$dir"

curl -fsSL --retry 3 -o "$asset" \
  "https://github.com/ggml-org/llama.cpp/releases/download/$version/$asset" ||
  fail "Could not download $asset"

if command -v sha256sum >/dev/null; then
  actual=$(sha256sum "$asset")
else
  actual=$(shasum -a 256 "$asset")
fi
actual=${actual%% *}
if [ "$actual" != "$expected" ]; then
  fail "Checksum mismatch for $asset: expected $expected, got $actual"
fi

case "$asset" in
  *.zip) unzip -q "$asset" ;;
  *) tar -xzf "$asset" ;;
esac

bin=$(find "$PWD" -type f \( -name llama-server -o -name llama-server.exe \) | head -n 1)
if [ -z "$bin" ]; then
  fail "llama-server was not found in $asset"
fi

echo "Installed llama.cpp $version"
{
  echo "bin=$bin"
  echo "model-key=${INPUT_MODEL//[^A-Za-z0-9._-]/-}"
} >>"$GITHUB_OUTPUT"
