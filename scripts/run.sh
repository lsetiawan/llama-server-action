#!/usr/bin/env bash
# Start llama-server, send one chat request, and write the reply to the
# `response` output.
#
# The prompt is untrusted data from start to finish: it arrives as an
# environment variable, is written to a file, and reaches the server as a JSON
# string built by jq. It is never evaluated by the shell and never passed as a
# command-line argument.
set -euo pipefail

# Print a file to the job log with workflow commands switched off, so text
# that came from the model or the server cannot issue commands such as
# ::add-mask:: or ::error::.
print_guarded() {
  local token
  token=$(openssl rand -hex 16)
  echo "::group::$1"
  echo "::stop-commands::$token"
  cat "$2"
  echo
  echo "::$token::"
  echo "::endgroup::"
}

fail() {
  echo "::error::$1"
  if [ -s response.json ]; then
    print_guarded "Server response" response.json
  fi
  if [ -s server.log ]; then
    print_guarded "llama-server log" server.log
  fi
  exit 1
}

if [ -z "${INPUT_PROMPT:-}" ]; then
  echo "::error::The prompt input is empty"
  exit 1
fi

# Work in a private directory and refer to files by relative name, which
# keeps Git Bash on Windows from rewriting arguments it takes for paths.
cd "$(mktemp -d)"

# Model downloads go to the directory that action.yml caches.
cache_dir="$HOME/.cache/llama-server-action"
mkdir -p "$cache_dir"
if command -v cygpath >/dev/null; then
  cache_dir=$(cygpath -m "$cache_dir")
fi
export LLAMA_CACHE="$cache_dir"

# The model gets no tools: never let the caller's environment switch on
# llama-server's built-in shell and file tools or its MCP client.
unset LLAMA_ARG_TOOLS LLAMA_ARG_MCP_SERVERS_CONFIG LLAMA_ARG_MCP_SERVERS_JSON \
  LLAMA_ARG_UI_MCP_PROXY

printf '%s' "$INPUT_PROMPT" >prompt.txt

jq -n -c --rawfile prompt prompt.txt \
  '{messages: [{role: "user", content: $prompt}], stream: false}' >request.json

# Loopback only, on a port that is unlikely to be taken, without the web UI.
port=$((49152 + RANDOM % 16384))
url="http://127.0.0.1:$port"

"$LLAMA_SERVER_BIN" -hf "$INPUT_MODEL" --host 127.0.0.1 --port "$port" \
  --no-webui >server.log 2>&1 &
server_pid=$!
trap 'kill "$server_pid" 2>/dev/null || true' EXIT

# The server only starts listening once the model is downloaded and loaded.
# There is no timeout here; the job's timeout-minutes is the limit.
echo "Waiting for llama-server to download and load the model"
until curl -fsS -o /dev/null "$url/health" 2>/dev/null; do
  if ! kill -0 "$server_pid" 2>/dev/null; then
    fail "llama-server exited before the model was ready"
  fi
  sleep 2
done

curl -sS --fail-with-body -H 'Content-Type: application/json' \
  --data-binary @request.json -o response.json "$url/v1/chat/completions" ||
  fail "The chat completion request failed"

# jq on Windows writes CRLF line endings; drop the carriage returns.
jq -r '.choices[0].message.content // empty' response.json | tr -d '\r' >response.txt
if ! grep -q '[^[:space:]]' response.txt; then
  fail "The model returned an empty response"
fi

# The delimiter is random and chosen after the response exists, so the
# response cannot close the block early and write other outputs.
delimiter="RESPONSE_$(openssl rand -hex 16)"
{
  echo "response<<$delimiter"
  cat response.txt
  echo "$delimiter"
} >>"$GITHUB_OUTPUT"
