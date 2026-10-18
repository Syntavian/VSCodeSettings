# VSCodeSettings main-line guidance

Verified October 18, 2026 for standalone licensing work targeting main.

## Scope and environment

Root: D:/Desktop/Stuff/Work/Projects/VSCodeSettings (WSL
/mnt/d/Desktop/Stuff/Work/Projects/VSCodeSettings). Bash scripts combine base.json
and an optional local profile to compare/apply VS Code settings and keybindings.
Original material is GPL-3.0-only; preserve existing grants, LICENSE and notices.
Strict JSON settings remain comment-free and are covered by the README grant.

Windows-hosted VS Code workspace; commands run in WSL. Verified Bash 5.2.21,
Git 2.43.0, jq 1.7, and available envsubst/diff. Active extension host and intended
runtime setup remain unverified. No dependencies were installed.

## Safety and validation

This main-line implementation differs from feature/bash-cleanup: normal startup
creates/sources secrets.env, reads live settings and inventories extensions.
Apply/set/deploy overwrites settings without a verified backup process. Do not
run normal/apply modes for validation or read ignored secrets/local profiles.
Runtime requires Bash, jq, envsubst, diff and code; do not silently substitute
Windows/WSL tools or apply settings to establish compatibility.

Safe checks from root: bash -n bin/run.sh bin/utils.sh, and
jq empty base.json profiles/_template_.json. Both passed before notice edits.
For notice-only changes compare the original source bodies byte-for-byte.
Validate document links/LF/newlines/whitespace and exact LICENSE bytes.
No tests, CI, manifest or lockfile exist on this main-based milestone. Tests and
behavioral changes on feature/bash-cleanup are outside this milestone; do not
copy them into this branch. Runtime and platform behavior remain unverified.

## Git milestone

Standalone work branch work/w1-license-rollout targets main, baseline 3b4b939
matching fetched origin/main. feature/bash-cleanup must remain unchanged at
2f8b1ab; do not integrate that feature as part of licensing. At inspection it was
two commits ahead of main. Feature guidance differs and may require reconciliation
in a separately authorized future integration.

Current scope is licensing notices, README and required main-line AGENTS.md only.
Integration/push require a further approval boundary and applicable restrictions
check. Existing LICENSE remains byte-identical to the approved GPL resource.
Repository-local core.filemode=false; no active hooks/custom hooks path or local
instruction/skill files found. Preserve unrelated branches and changes.
