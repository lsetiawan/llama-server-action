# llama-server-action

Run [Hugging Face](https://huggingface.co/models?library=gguf) GGUF language
models with the [llama.cpp](https://github.com/ggml-org/llama.cpp) server in
GitHub Actions.

This action runs a language model inside the workflow job itself, so a workflow
can summarize, classify, or draft text without sending anything to a hosted API.
It downloads a llama.cpp build, starts `llama-server` with a model from Hugging
Face, sends one prompt, and returns the reply as a step output. Any GGUF model
works as long as it fits in the
[runner's memory](https://docs.github.com/en/actions/reference/runners/github-hosted-runners).

The interface follows
[ai-action/ollama-action](https://github.com/ai-action/ollama-action) by
[remarkablemark](https://github.com/remarkablemark), and the way inputs are
handled follows the guidance in the UW Scientific Software Engineering Center
talk
[Security in the Age of AI](https://github.com/uw-ssec/presentations/tree/main/security-in-age-of-ai).

## Quick Start

```yaml
# .github/workflows/llama.yml
on: push

permissions: {}

jobs:
  llama:
    runs-on: ubuntu-latest
    timeout-minutes: 15
    steps:
      - name: Run model
        uses: lsetiawan/llama-server-action@<commit-sha>
        id: model
        with:
          model: ggml-org/gemma-3-1b-it-GGUF
          prompt: Explain the basics of machine learning.

      - name: Print response
        run: printf '%s\n' "$RESPONSE"
        env:
          RESPONSE: ${{ steps.model.outputs.response }}
```

Replace `<commit-sha>` with the full commit SHA of the version to use. A SHA
cannot be moved to different code later, which a tag or branch name can.

The action has no timeout of its own, because a model download can be quick or
slow depending on its size. Set `timeout-minutes` on the job to bound it.

## Inputs

### `model`

**Required**: The Hugging Face repository of a GGUF model, written as
`<user>/<repo>` or `<user>/<repo>:<quant>`. Without a quantization, llama.cpp
picks `Q4_K_M`, or the first file in the repository if there is none.

```yaml
- uses: lsetiawan/llama-server-action@<commit-sha>
  with:
    model: bartowski/SmolLM2-135M-Instruct-GGUF:Q4_K_M
    prompt: Tell me a joke.
```

### `prompt`

**Required**: The instruction for the model. Write it in the workflow file;
anything that comes from outside the repository belongs in
[`untrusted-input`](#untrusted-input).

```yaml
- uses: lsetiawan/llama-server-action@<commit-sha>
  with:
    model: ggml-org/gemma-3-1b-it-GGUF
    prompt: |
      Tell me
      a joke.
```

### `untrusted-input`

**Optional**: Text for the model to work on that the workflow author did not
write, such as a pull request title, an issue body, or the contents of a file.
The action places it after the prompt, fenced between markers that carry a
random suffix, and tells the model to treat it as data and not as instructions.

```yaml
- uses: lsetiawan/llama-server-action@<commit-sha>
  id: summary
  with:
    model: ggml-org/gemma-3-1b-it-GGUF
    prompt: Summarize this issue in one sentence.
    untrusted-input: ${{ github.event.issue.body }}
```

### `version`

**Optional**: A llama.cpp build tag such as `b12137`. See all
[builds](https://github.com/ggml-org/llama.cpp/releases). The default is the
build recorded in [`llama-cpp-pin.json`](llama-cpp-pin.json).

```yaml
- uses: lsetiawan/llama-server-action@<commit-sha>
  with:
    model: ggml-org/gemma-3-1b-it-GGUF
    prompt: Tell me a joke.
    version: b12137
```

### `cache`

**Optional**: Whether to cache the downloaded model between runs. Defaults to
`true`.

```yaml
- uses: lsetiawan/llama-server-action@<commit-sha>
  with:
    model: ggml-org/gemma-3-1b-it-GGUF
    prompt: Tell me a joke.
    cache: false
```

## Outputs

### `response`

The reply from the model.

```yaml
- uses: lsetiawan/llama-server-action@<commit-sha>
  id: answer
  with:
    model: ggml-org/gemma-3-1b-it-GGUF
    prompt: What's 1+1?

- run: printf '%s\n' "$RESPONSE"
  env:
    RESPONSE: ${{ steps.answer.outputs.response }}
```

Pass the response to later steps through `env:` and wrap the variable in double
quotes, as above. Writing `${{ steps.answer.outputs.response }}` directly inside
a `run:` script would let the model's text run as shell code.

## Security

A language model in CI reads text that other people control, so the action
treats its inputs as data at every step and keeps the model away from anything
it could act on.

What the action does:

- **Inputs never run as code.** Every input is bound to an environment variable
  and reaches the server as a JSON string. `model` and `version` must match a
  strict pattern, so neither can add options to the `llama-server` command.
- **Untrusted text is fenced and labeled.** See
  [`untrusted-input`](#untrusted-input). The random suffix on the markers means
  the text cannot close the fence itself.
- **The model has no tools.** It cannot run commands, read files, or reach the
  network. The server listens on `127.0.0.1` only, for the length of one
  request, and the action removes the environment variables that would switch on
  llama-server's built-in tools.
- **The response cannot forge outputs.** It is written to the step output behind
  a random delimiter, and server logs are printed with workflow commands
  switched off.
- **Downloads are verified.** The default llama.cpp build is checked against
  SHA-256 checksums committed in this repository. A build chosen with `version`
  is checked against the digest GitHub recorded for it.

What stays with the workflow author:

- Fencing lowers the chance that injected text steers the model, and it does not
  remove it. Treat `response` as untrusted. Have a person review it before it
  decides anything that matters, and never let it choose what a privileged step
  runs.
- The job log interprets
  [workflow commands](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-commands#stopping-and-starting-workflow-commands).
  Stop them before printing a response that was produced from untrusted input.
- Give the job the smallest `permissions` it needs, and pin this action and
  every other action to a commit SHA.
- A model file is data that llama.cpp parses, so choose repositories you trust,
  and set `cache: false` in workflows that publish releases.

### The pinned llama.cpp build

llama.cpp publishes several builds a day. A weekly workflow,
[`bump-llama-cpp.yml`](.github/workflows/bump-llama-cpp.yml), picks the newest
build that has been public for at least seven days and opens a pull request that
updates [`llama-cpp-pin.json`](llama-cpp-pin.json), so a person reviews every
change to the default build.

## Developing this repository

The rest of this page is for people working on the action itself. Using the
action needs none of it.

### Prerequisites

This project uses [Pixi](https://pixi.sh) for dependency management and task
execution. Install Pixi by following the
[installation instructions](https://pixi.sh/latest/#installation).

### Getting Started

#### GitHub Codespaces / Dev Containers

The repository ships a [`.devcontainer/`](.devcontainer/) configuration. Open it
in GitHub Codespaces (or VS Code Dev Containers) to get a container with Pixi
and the Claude Code, Codex, Copilot CLI, and OpenCode agent CLIs preinstalled;
the Pixi environment is installed and auto-activated on first start.

#### Installation

Install dependencies:

```bash
# Install dependencies (Pixi will automatically create the environment)
pixi install
```

Install the pre-commit hooks:

```bash
pixi run pre-commit-install
```

### Project Structure

This project is organized using Pixi features for modular dependency management:

- **`pre-commit`**: Code quality and consistency checks
- **`gh-cli`**: GitHub CLI for repository interactions
- **`okf`**: The `okf` CLI for reading and writing project memory in
  `knowledge/`

### Available Environments

- **`default`**: Standard development environment with pre-commit hooks, GitHub
  CLI, and the `okf` CLI

### Development

#### Adding Dependencies

Conda packages come from a single channel, the prefix.dev mirror of conda-forge
(`https://prefix.dev/conda-forge`).

Edit `pixi.toml` to add new dependencies:

```toml
[dependencies]
your-package = ">=1.0.0"
```

Then run:

```bash
pixi install
```

or

Directly add packages (this will edit the pixi toml and install):

```bash
pixi add your-package
```

## Harness Customization Framework

The template is set up for AI coding agents such as Claude Code, Codex, Copilot,
Cursor, and Gemini CLI. Everything below is read by agents only; it does not
change how the project builds or runs.

### Instruction entry points

What an agent reads first.

| Path             | Role                                                                                                                      |
| ---------------- | ------------------------------------------------------------------------------------------------------------------------- |
| `AGENTS.md`      | The harness-neutral entry point. Kept short: five non-negotiables, a rule index, and the provenance of the adapted rules. |
| `CLAUDE.md`      | Contains only `@AGENTS.md`, so Claude Code reads the same file.                                                           |
| `.claude/skills` | Symlink to `.agents/skills`, so Claude Code discovers the skills.                                                         |

### On-demand rules

Seven files in [`.agents/rules/`](.agents/rules/). Each opens with a "Load
when:" line, so an agent reads it only when it is relevant.

- **Behavior:** `working-agreement.md` and `contribution-discipline.md` aim to
  reduce common LLM coding mistakes. They are adapted from
  [obra/superpowers](https://github.com/obra/superpowers) and
  [multica-ai/andrej-karpathy-skills](https://github.com/multica-ai/andrej-karpathy-skills).
- **Orientation:** `repository-map.md`, `pixi-environments.md`,
  `pre-commit-and-quality.md`, and `troubleshooting.md` hold context a human
  picks up over time and an agent needs written down.
- **Optional pattern:** `mkdocs-okf-knowledge-bundle.md` covers rendering an
  OKF-managed knowledge bundle with mkdocs.

### Skills

Nine step-by-step recipes at `.agents/skills/<name>/SKILL.md`: `commit`, `push`,
`create-pr`, `merge-pr`, `create-issue`, `release`, `clean-branches`, `docs`,
and `okf-memory`. Each covers a workflow a human does by habit and sets hard
rules for the agent, such as never force-pushing and never force-deleting a
branch.

### Project memory

[`knowledge/`](knowledge/) is an OKF bundle for project memory. It records what
the code cannot show (decisions, data caveats, and constraints) and is kept
separate from any docs site on purpose. The template ships it empty, with only
`index.md` and `log.md`; agents read and write it with `pixi run okf`, as the
`okf-memory` skill describes.

Supporting machinery:

- `okf-agent-memory` is a dependency of the `okf` feature in `pixi.toml`, which
  the `default` environment includes.
- The `okf-memory` skill requires `pixi run okf search --for-path <file>` before
  the first edit in a subsystem. A `hold` hit means stop and confirm with the
  user; a `constraint` hit lists invariants the change must keep.
- `pixi run okf validate --strict --drift` checks the bundle.
- Prettier excludes `knowledge/` in `.pre-commit-config.yaml`, because
  reformatting corrupts the frontmatter.

A project that doesn't want project memory can remove the `okf` feature from the
`default` environment in `pixi.toml`, then delete `.agents/skills/okf-memory/`
and `knowledge/`.

## Contributing

Please read [CONTRIBUTING.md](CONTRIBUTING.md) for details on our code of
conduct and the process for submitting pull requests. If you use AI tools while
contributing, read the [AI Policy](AI_POLICY.md) first: it covers disclosure,
review responsibility, and how to credit AI assistance in commits.

## License

This project is licensed under the terms specified in the [LICENSE](LICENSE)
file.
