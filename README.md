# project-template

Lean, Pixi-based project template with pre-commit checks and AI coding agent
setup.

This includes some default
[community health files](https://docs.github.com/en/communities/setting-up-your-project-for-healthy-contributions/creating-a-default-community-health-file#supported-file-types)
such as a code of conduct and license file.

## Prerequisites

This project uses [Pixi](https://pixi.sh) for dependency management and task
execution. Install Pixi by following the
[installation instructions](https://pixi.sh/latest/#installation).

## Getting Started

### GitHub Codespaces / Dev Containers

The repository ships a [`.devcontainer/`](.devcontainer/) configuration. Open it
in GitHub Codespaces (or VS Code Dev Containers) to get a container with Pixi
and the Claude Code, Codex, Copilot CLI, and OpenCode agent CLIs preinstalled;
the Pixi environment is installed and auto-activated on first start.

### Installation

Install dependencies:

```bash
# Install dependencies (Pixi will automatically create the environment)
pixi install
```

Install the pre-commit hooks:

```bash
pixi run pre-commit-install
```

## Project Structure

This project is organized using Pixi features for modular dependency management:

- **`pre-commit`**: Code quality and consistency checks
- **`gh-cli`**: GitHub CLI for repository interactions
- **`okf`**: The `okf` CLI for reading and writing project memory in
  `knowledge/`

## Available Environments

- **`default`**: Standard development environment with pre-commit hooks, GitHub
  CLI, and the `okf` CLI

## Development

### Adding Dependencies

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
