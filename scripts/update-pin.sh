#!/usr/bin/env bash
# Rewrite llama-cpp-pin.json with the newest llama.cpp build that has been
# public for at least COOLDOWN_DAYS (default 7) and ships every archive this
# action supports. The checksums are the SHA-256 digests GitHub recorded when
# the archives were uploaded.
#
# Requires `gh` and `jq`. Run by .github/workflows/bump-llama-cpp.yml.
set -euo pipefail

repo=ggml-org/llama.cpp
cooldown_days=${COOLDOWN_DAYS:-7}
pin_file="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/llama-cpp-pin.json"

# Keep in sync with the platform table in setup.sh.
suffixes='[
  "macos-arm64.tar.gz",
  "macos-x64.tar.gz",
  "ubuntu-arm64.tar.gz",
  "ubuntu-x64.tar.gz",
  "win-cpu-arm64.zip",
  "win-cpu-x64.zip"
]'

# shellcheck disable=SC2016 # $-names below are jq variables, not shell ones
select_pin='
  (now - $days * 86400) as $cutoff
  | [ .[]
      | select(.draft | not)
      | select(.tag_name | test("^b[0-9]+$"))
      | select((.published_at | fromdateiso8601) <= $cutoff)
      | . as $release
      | {
          version: .tag_name,
          sha256: (
            [ $suffixes[]
              | "llama-\($release.tag_name)-bin-\(.)" as $name
              | $release.assets[]
              | select(.name == $name)
              | select((.digest // "") | test("^sha256:[0-9a-f]{64}$"))
              | { key: .name, value: (.digest | ltrimstr("sha256:")) }
            ] | from_entries
          )
        }
      | select((.sha256 | length) == ($suffixes | length))
    ]
  | first // empty
'

# Releases are listed newest first; llama.cpp publishes many builds a day, so
# the first one past the cooldown can be several pages in.
pin=""
for page in $(seq 1 20); do
  releases=$(gh api "repos/$repo/releases?per_page=100&page=$page")
  if [ "$(jq 'length' <<<"$releases")" -eq 0 ]; then
    break
  fi
  pin=$(jq --argjson days "$cooldown_days" --argjson suffixes "$suffixes" \
    "$select_pin" <<<"$releases")
  if [ -n "$pin" ]; then
    break
  fi
done

if [ -z "$pin" ]; then
  echo "No llama.cpp build older than $cooldown_days days has all archives" >&2
  exit 1
fi

printf '%s\n' "$pin" >"$pin_file"
echo "Pinned llama.cpp $(jq -r .version "$pin_file")"
