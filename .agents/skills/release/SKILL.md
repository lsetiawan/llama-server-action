---
name: release
description:
  Use when a new version needs cutting — a semver bump, changelog entry, git
  tag, and GitHub release.
---

# Release

Create a versioned release with changelog, tag, and GitHub release. Release
assets are optional; see
[Optional: plugin zip assets](#optional-plugin-zip-assets).

## Arguments

Optional: version bump type — `patch`, `minor`, or `major`. Defaults to
analyzing changes.

## Instructions

1. Determine the version bump:

   - If `patch`, `minor`, or `major` was passed, use that
   - If not specified, analyze commits since the last tag to determine:
     - `major`: breaking changes (commits with `!` or `BREAKING CHANGE`)
     - `minor`: new features (`feat:` commits)
     - `patch`: fixes, refactors, docs, chores only

2. Get the current version:

   - Check `git tag --sort=-v:refname | head -1` for the latest tag
   - If no tags exist, start at `v0.1.0`

3. Calculate the new version following semver.

4. Verify readiness:

   - `git status` — no uncommitted changes
   - `git switch main && git pull origin main` — up to date with `main`
   - Stop and warn if either check fails

5. Read `CHANGELOG.md` and check that the `[Unreleased]` section has content. If
   the file or section is missing, warn and ask how to proceed.

6. Prepare the changelog on a release branch, never directly on `main`:

   ```bash
   git switch -c release/vX.Y.Z
   ```

   - Rename `[Unreleased]` to `[X.Y.Z] -- YYYY-MM-DD` (today's date)
   - Add a new empty `[Unreleased]` section above it

7. Commit the changelog update:

   ```bash
   git add CHANGELOG.md
   git commit -m "chore(release): prepare vX.Y.Z" -m "Assisted-by: <harness>:<model>"
   ```

   The trailer follows the `commit` skill's AI Attribution section. Omit it
   entirely if the release was cut without AI assistance.

8. Open a PR for the release branch with the `create-pr` skill and get it merged
   with the `merge-pr` skill. Both gates (pre-commit and the user's diff
   approval) apply.

9. Tag the merged commit on `main`. Ask for confirmation before pushing the tag:

   ```bash
   git switch main && git pull origin main
   git tag -a vX.Y.Z -m "vX.Y.Z"
   git push origin vX.Y.Z
   ```

10. Create the GitHub release:

    ```bash
    pixi run gh release create vX.Y.Z --title "vX.Y.Z" \
      --notes "$(cat <<'EOF'
    ## What's Changed

    <extract the relevant section from CHANGELOG.md>

    **Full Changelog**: <repo compare URL>/compare/vPREVIOUS...vX.Y.Z
    EOF
    )"
    ```

    If the project has adopted plugin zip assets, build them first and append
    the zip paths to this command.

11. Confirm: "Released vX.Y.Z — <release URL>"

## Optional: plugin zip assets

Only applies if the project has a `plugins/` directory and has chosen to ship
each plugin as a release asset. Skip this section otherwise.

- For each directory in `plugins/`, create a zip archive named
  `plugin_name_MM_DD_YYYY.zip` (snake_case plugin name + date). If a release
  already exists for today (check `pixi run gh release list`), append a sequence
  suffix starting at `_2`.
- Zip from inside `plugins/` so the zip root is the plugin folder, excluding
  `.DS_Store`, `__pycache__`, and `*.pyc`:
  ```bash
  cd plugins && zip -r ../plugin_name_MM_DD_YYYY.zip plugin-dir-name/ -x "*.DS_Store" "*__pycache__/*" "*.pyc" && cd ..
  ```
- Add a "Plugin Assets" section to the release notes listing each zip.
- Delete the zips from the repo root after upload. Never commit them.

## Version Guidelines

| Bump            | When                               | Example             |
| --------------- | ---------------------------------- | ------------------- |
| `patch` (0.1.X) | Bug fixes, docs, chores, refactors | `v0.1.1` → `v0.1.2` |
| `minor` (0.X.0) | New features, non-breaking changes | `v0.1.2` → `v0.2.0` |
| `major` (X.0.0) | Breaking changes, major rewrites   | `v0.2.0` → `v1.0.0` |

## Rules

- Never commit release changes directly to `main`; they land through a PR
- Tag only the merged commit on `main`, never a feature or release branch
- Tag format is always `vX.Y.Z` (with `v` prefix)
- Ask for confirmation before pushing the tag and creating the release
- Must have content in `[Unreleased]` section of CHANGELOG.md
- NEVER add "Generated with" or similar marketing lines to the release notes
- NEVER include sensitive information in the release notes or changelog
