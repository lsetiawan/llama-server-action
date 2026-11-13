# Repository Map

**Load when:** you need to know what this repository is, where a file lives, or
what CI runs against it.

## Repository Overview

This repository is a **composite GitHub Action**. It downloads a pinned
[llama.cpp](https://github.com/ggml-org/llama.cpp) build, starts `llama-server`
with a Hugging Face GGUF model, sends one prompt, and returns the reply as the
`response` output. It was started from a Pixi-based project template, which
provides the community health files, pre-commit configuration, and AI agent
setup.

**Repository Stats:**

- **Type:** Composite GitHub Action
- **Size:** Small
- **Languages:** Bash, plus configuration files (TOML, YAML, Markdown)
- **Build System:** Pixi (v0.49.0+)
- **Platform:** macOS (osx-arm64) and Linux (linux-64, linux-aarch64)
- **License:** BSD 3-Clause

## Project Structure & Key Files

```
.
├── .devcontainer/               # Codespaces / Dev Containers image: pixi + coding agent CLIs
├── .agents/
│   ├── rules/                   # On-demand rules referenced by AGENTS.md
│   └── skills/                  # User-invocable skills (/commit, /create-pr, ...)
├── .claude/
│   └── skills -> ../.agents/skills  # Symlink so Claude Code discovers the skills
├── .github/
│   ├── dependabot.yml           # Dependabot config for GitHub Actions
│   ├── pull_request_template.md # PR template (requires pre-commit checks)
│   ├── release.yml              # Release notes configuration
│   ├── workflows/               # GitHub Actions (tests, llama.cpp bump, Copilot agent setup)
│   └── ISSUE_TEMPLATE/          # Issue templates (bug, feature)
├── knowledge/                   # OKF project memory, managed by the okf CLI (okf-memory skill)
├── scripts/
│   ├── setup.sh                 # Validates inputs; downloads and verifies llama.cpp
│   ├── run.sh                   # Starts llama-server, sends the prompt, writes the output
│   └── update-pin.sh            # Rewrites llama-cpp-pin.json (used by the bump workflow)
├── action.yml                   # **THE ACTION**: inputs, outputs, and composite steps
├── llama-cpp-pin.json           # Default llama.cpp build and its SHA-256 checksums
├── .pre-commit-config.yaml      # Pre-commit hook configuration
├── pixi.toml                    # **PRIMARY CONFIG**: Dependencies, tasks, features
├── pixi.lock                    # Lock file (auto-generated, don't manually edit)
├── .gitignore                   # Ignores .pixi/ and .DS_Store
├── AGENTS.md                    # Entry point for AI assistants
├── CLAUDE.md                    # Points Claude Code at AGENTS.md (@AGENTS.md)
├── CODE_OF_CONDUCT.md           # Contributor Covenant v2.0
├── CONTRIBUTING.md              # Contribution guidelines (references Conventional Commits)
├── LICENSE                      # BSD 3-Clause License
└── README.md                    # Project documentation
```

## Continuous Integration & Validation

**Action tests:** `.github/workflows/test.yml` runs the action on Ubuntu, macOS,
and Windows with a tiny model. It is the only end-to-end check: nothing run
locally starts a real `llama-server`.

**llama.cpp bump:** `.github/workflows/bump-llama-cpp.yml` runs weekly, picks
the newest llama.cpp build that is at least seven days old, and opens a pull
request that updates `llama-cpp-pin.json`. Never edit that file by hand; run
`scripts/update-pin.sh`.

**Workflow security lint:** the `zizmor` pre-commit hook runs
[zizmor](https://github.com/zizmorcore/zizmor) static analysis on workflow files
and on `action.yml`. Changes to `action.yml` or anything under
`.github/workflows/` must keep this check passing.

**Copilot cloud agent:** `.github/workflows/copilot-setup-steps.yml` prepares
the GitHub Copilot coding agent's environment (pixi install from `pixi.lock`,
pre-commit hook environments). Copilot reads `AGENTS.md` and `.agents/skills/`
on its own; keep the pinned `pixi-version` in sync with
`.devcontainer/Dockerfile`.

**Pre-commit.ci Integration:** The `.pre-commit-config.yaml` includes a `ci:`
section, suggesting integration with https://pre-commit.ci for automated PR
checks. Verify if enabled on the repository.

**Dependabot:** Configured to update GitHub Actions weekly (groups all action
updates together).
