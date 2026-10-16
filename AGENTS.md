# Project working notes

## Scope and environment

- Bash-based VS Code settings manager; `base.json` is combined with an optional local profile.
- This checkout is Windows-hosted at `D:\Desktop\Stuff\Work\Projects\VSCodeSettings`; shell commands run through WSL at `/mnt/d/Desktop/Stuff/Work/Projects/VSCodeSettings`.
- When launched from WSL, manage Windows VS Code user settings by default. Resolve the Windows application-data directory through PowerShell and translate it with `wslpath`; do not assume the Windows username or drive.
- Preserve native Linux/macOS and existing MSYS/Cygwin path behavior. Remote settings, named VS Code profiles, portable mode, and Insiders are not currently handled.

## Dependencies and sensitive paths

- Runtime: Bash 4+, `jq`, `envsubst`, `diff`, standard shell utilities, and the VS Code `code` CLI. WSL additionally requires `powershell.exe` and `wslpath`.
- No package-manager manifest, pinned tool versions, or CI configuration is currently present.
- `jq` and ShellCheck are available in WSL at `/usr/bin/jq` and `/usr/bin/shellcheck`. ShellCheck 0.9.0 was verified; do not install or upgrade tools without authorization.
- `secrets.env` and local profiles are ignored; do not read secret values. The tracked `profiles/_template_.json` is safe sample configuration.
- `bin/run.sh` checks dependencies before loading an existing `secrets.env` as shell code. It does not create a missing secrets file. Normal execution can still load real secrets and read live settings; use isolated tests for routine validation.
- Apply mode overwrites live settings/keybindings without backups. Do not run it as a test.

## Safe validation

Run from the repository root in WSL:

- `bash -n bin/run.sh bin/utils.sh tests/utils_test.sh tests/run_test.sh`
- `shellcheck -x bin/run.sh bin/utils.sh tests/run_test.sh tests/utils_test.sh` — follows library sources; the real secrets file is explicitly excluded from static analysis.
- `bash tests/utils_test.sh` — mocks Windows tools and platform detection; does not read secrets or access live settings.
- `bash tests/run_test.sh` — Bash tests use disposable project/settings fixtures and a mocked `code` CLI, with automatic cleanup on exit. Comparison cases require `jq` and `envsubst`; missing tools cause explicit skips. No Python or external test framework is required.
- `jq . base.json > /dev/null`
- `jq . profiles/_template_.json > /dev/null`
- `bash bin/run.sh --help` — exits before loading secrets or touching settings.

Syntax/help checks and isolated tests passed. Tests cover target selection, library error returns, dependency preflight before secrets loading, exact option matching, missing values, profile argument boundaries, early help, base/profile comparisons, invalid target JSON, extension mismatches, and command/comparison failures. Apply mode, real extension inventory, JSON-with-comments targets, and backup/recovery remain unverified.

## CLI contract

- `bash bin/run.sh --help` documents defaults, examples, accepted modes, and exit statuses.
- Accept one profile via `-p`/`--profile`, or one positional argument. Preserve spaces; use `--` before a profile beginning with a dash. Duplicate profiles and extra positional arguments are usage errors.
- Long value options accept both `--name=value` and `--name value`; short options take a separate value. Bundled short flags and abbreviated option names are unsupported.
- Modes: `diff` (default), `apply`, and the existing apply aliases `set`/`deploy`.
- Exit 0 for help or successful execution, including ordinary differences; 2 for usage errors; 1 for operational failures. Dependency checks precede secrets loading; help bypasses dependency checks.
## Licensing and branch state

Original material is GPL-3.0-only; preserve existing grants, README, LICENSE and
source notices. Strict JSON files remain comment-free under the README grant.
The existing LICENSE matches the approved GPL resource verbatim.

On October 18, 2026 the separately approved main licensing milestone was published
as 2fb4742. This feature was explicitly authorized for a local rebase onto main;
its behavior and isolated tests remain in scope here, not on main. Feature
force-push/publication remains separately gated. Preserve unrelated branches.
Verified WSL Bash 5.2.21, Git 2.43.0 and jq 1.7; extension-host version remains
unverified. Repository-local core.filemode=false; no active hooks were found.
