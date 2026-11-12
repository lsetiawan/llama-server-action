---
name: create-issue
description:
  Use when work needs tracking in GitHub rather than implementing it now — a bug
  to file or a feature to capture. Issues are filed only after the user approves
  the final body.
---

# Create Issue

Create a GitHub issue for tracking work.

## Arguments

A description of the issue to create.

## Instructions

1. Based on the description, determine:

   - **Type**: `feat`, `fix`, `refactor`, `docs`, `chore`, `perf`, `ci`,
     `build`, `test`
   - **Scope**: the area of the codebase affected (e.g., `data`, `pipeline`,
     `io`, `cli`, `viz`, `docs`, `ci`, `deps`, `infra`)
   - **Title**: conventional commit format:
     `type(scope): short imperative description`

2. Search open and closed issues for duplicates:
   `pixi run gh issue list --state all --search "<terms>"`. If a duplicate
   exists, stop and show it to the user instead of filing another.

3. Pick the matching form in `.github/ISSUE_TEMPLATE/` (`bug_report.yml` or
   `feature_request.yml`) and draft the body so it answers that form's fields.
   Use the structure below for anything the form does not cover.

4. Mark AI-written text: add a line such as
   `> Drafted with AI assistance (<harness>:<model>), reviewed by <user>.` per
   `AI_POLICY.md`.

5. Show the user the final title and body and get explicit approval. Never file
   an issue autonomously, including follow-up work discovered mid-task — propose
   it to the user instead.

6. Create the issue with the approved content:

```bash
pixi run gh issue create --title "type(scope): description" --body "$(cat <<'EOF'
## Summary

<1-2 sentences describing the problem or feature>

## Requirements

<bulleted list of specific requirements or acceptance criteria>
- [ ] Requirement 1
- [ ] Requirement 2

## Context

<any relevant context, links, or background — omit if not needed>

## Implementation Notes

<optional technical direction or constraints — omit if not needed>
EOF
)"
```

7. Return the issue URL and number to the user.

## Title Convention

| Type             | Example                                                          |
| ---------------- | ---------------------------------------------------------------- |
| `feat(pipeline)` | `feat(pipeline): write processed samples as partitioned Parquet` |
| `fix(io)`        | `fix(io): handle empty input files without crashing`             |
| `refactor(data)` | `refactor(data): derive table schemas from the dataclasses`      |
| `docs(guides)`   | `docs(guides): add notebook setup walkthrough`                   |
| `chore(deps)`    | `chore(deps): bump numpy to 2.4`                                 |

## Rules

- Title must use conventional commit format: `type(scope): description`
- Keep title under 70 characters
- Use imperative mood ("add" not "adds", "fix" not "fixes")
- Requirements section should have checkboxes for trackable items
- Omit sections that aren't relevant (don't pad with empty sections)
- If the description is vague, ask clarifying questions before creating
- Never publish without the duplicate search and the user's approval of the
  final body
- NEVER include sensitive information in the issue body
