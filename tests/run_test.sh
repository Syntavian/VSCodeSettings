#!/usr/bin/env bash

# Exercise the CLI in disposable fixtures, never against live editor settings.

# Generated wholly by gpt-6.1-sol
# Last updated: 2026-10-16

set -Eeuo pipefail

PROJECT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
readonly PROJECT_DIR

BASH_PATH=$(command -v bash)
readonly BASH_PATH

ORIGINAL_PATH=${PATH}
readonly ORIGINAL_PATH

TEMP_DIR=$(mktemp -d "${TMPDIR:-/tmp}/vscode-settings-test.XXXXXXXX")
readonly TEMP_DIR

trap 'rm -rf -- "${TEMP_DIR}"' EXIT

function fail() {
    printf 'FAIL: %s\n' "$1" >&2

    if [[ -f "${fixture:-}/stderr" ]]; then
        cat "${fixture}/stderr" >&2
    fi

    exit 1
}

function assert_contains() {
    grep -Fq -- "$2" "$1" || fail "Expected '$2' in '$1'"
}

function assert_not_contains() {
    if grep -Fq -- "$2" "$1"; then
        fail "Unexpected '$2' in '$1'"
    fi
}

# Set main's fixture/cli_path locals and export the disposable settings target.
function new_fixture() {
    fixture="${TEMP_DIR}/$1"

    mkdir -p "${fixture}/bin" "${fixture}/profiles" \
        "${fixture}/target with spaces" "${fixture}/tools"

    cp "${PROJECT_DIR}/bin/run.sh" "${fixture}/bin/run.sh"

    # Expand TEST_TARGET when the generated helper runs, not while writing it.
    # shellcheck disable=SC2016
    printf '%s\n' 'get_vscode_user_dir() { printf "%s\n" "${TEST_TARGET}"; }' \
        >"${fixture}/bin/utils.sh"

    export TEST_TARGET="${fixture}/target with spaces"
    cli_path=${ORIGINAL_PATH}
}

function run_cli() {
    status=0

    PATH="${cli_path}" "${BASH_PATH}" "${fixture}/bin/run.sh" "$@" \
        >"${fixture}/stdout" 2>"${fixture}/stderr" || status=$?
}

function add_secrets_marker() {
    # This synthetic fixture contains no credentials and needs no external command.
    # Preserve TEST_TARGET for expansion when the fixture is sourced.
    # shellcheck disable=SC2016
    printf '%s\n' ': > "${TEST_TARGET}/secret-loaded"' >"${fixture}/secrets.env"
}

function test_preflight() {
    local tool

    new_fixture invalid-mode

    add_secrets_marker

    run_cli --mode=invalid

    (( status == 2 )) || fail 'Invalid mode did not return usage status 2'
    assert_contains "${fixture}/stderr" 'Unknown mode'
    [[ ! -e "${TEST_TARGET}/secret-loaded" ]] || fail 'Invalid mode loaded secrets'

    echo 'PASS: invalid mode does not source secrets'

    new_fixture missing-dependencies

    add_secrets_marker

    for tool in dirname cat; do
        ln -s "$(command -v "${tool}")" "${fixture}/tools/${tool}"
    done

    cli_path="${fixture}/tools"

    run_cli

    (( status != 0 )) || fail 'Missing dependencies succeeded'
    assert_contains "${fixture}/stderr" 'Missing required dependencies: jq'
    [[ ! -e "${TEST_TARGET}/secret-loaded" ]] || fail 'Missing dependencies loaded secrets'

    echo 'PASS: missing dependencies do not source secrets'
}

function prepare_comparison() {
    new_fixture "$1"

    printf '#!%s\nprintf "example.extension@1.0\\n"\n' "${BASH_PATH}" >"${fixture}/tools/code"

    chmod +x "${fixture}/tools/code"

    cli_path="${fixture}/tools:${ORIGINAL_PATH}"

    cat >"${fixture}/base.json" <<'JSON'
{
    "settings": {"example": "base", "retained": true},
    "keybindings": [{"key": "ctrl+a", "command": "example"}],
    "extensions": ["example.extension@1.0"]
}
JSON

    cat >"${fixture}/profiles/test.json" <<'JSON'
{"settings":{"example":"profile"},"keybindings":[],"extensions":[]}
JSON

    printf '%s\n' '{"example":"profile","retained":true}' >"${TEST_TARGET}/settings.json"

    jq '.keybindings' "${fixture}/base.json" >"${TEST_TARGET}/keybindings.json"

    cp -R "${TEST_TARGET}" "${fixture}/before"
}

function test_comparisons() {
    prepare_comparison read-only

    run_cli --profile=test

    (( status == 0 )) || fail 'Profile comparison failed'
    assert_contains "${fixture}/stdout" 'Settings file matched'
    assert_contains "${fixture}/stdout" 'Keybindings file matched'
    assert_contains "${fixture}/stdout" 'All extensions matched'

    diff -r "${fixture}/before" "${TEST_TARGET}" || fail 'Comparison changed target files'

    [[ ! -e "${fixture}/secrets.env" ]] || fail 'Comparison created secrets.env'

    echo 'PASS: profile comparison is read-only'

    prepare_comparison invalid-json

    printf '%s\n' 'invalid JSON' >"${TEST_TARGET}/settings.json"

    run_cli --profile=test

    (( status != 0 )) || fail 'Invalid target JSON succeeded'
    assert_not_contains "${fixture}/stdout" 'Settings file matched'

    echo 'PASS: invalid target JSON fails'

    prepare_comparison mismatches

    printf '%s\n' '{"example":"different"}' >"${TEST_TARGET}/settings.json"

    printf '#!%s\nprintf "other.extension@2.0\\n"\n' "${BASH_PATH}" >"${fixture}/tools/code"

    cp "${TEST_TARGET}/settings.json" "${fixture}/before/settings.json"

    run_cli --profile=test

    (( status == 0 )) || fail 'Mismatch comparison failed'
    assert_not_contains "${fixture}/stdout" 'Settings file matched'
    assert_contains "${fixture}/stdout" 'Extension mismatch found'

    diff -r "${fixture}/before" "${TEST_TARGET}" || fail 'Mismatch comparison changed target files'

    echo 'PASS: mismatches are reported without writes'

    echo 'PASS: original 5 CLI regression tests'
}

function test_arguments() {
    local option

    for option in --mode --profile -m -p --mode= --profile= --model=diff -mp; do
        new_fixture invalid-argument

        add_secrets_marker

        run_cli "${option}"

        (( status == 2 )) || fail "Expected usage error for '${option}'"
        [[ ! -e "${TEST_TARGET}/secret-loaded" ]] || fail 'Usage error loaded secrets'
    done

    run_cli --profile=test extra

    (( status == 2 )) || fail 'Duplicate profile accepted'

    run_cli -- first second

    (( status == 2 )) || fail 'Multiple positional arguments accepted'

    cli_path="${fixture}/tools"

    ln -s "$(command -v dirname)" "${fixture}/tools/dirname"
    ln -s "$(command -v cat)" "${fixture}/tools/cat"

    run_cli --help

    (( status == 0 )) || fail 'Help required runtime dependencies'
    assert_contains "${fixture}/stdout" 'Exit status:'

    echo 'PASS: exact options, missing values, positional validation, and early help'
}

function main() {
    # Fixture helpers and run_cli intentionally update these shared caller locals.
    local fixture cli_path status

    test_preflight

    test_arguments

    if ! command -v jq >/dev/null || ! command -v envsubst >/dev/null; then
        echo 'SKIP: comparison tests require jq and envsubst'

        return 0
    fi

    test_comparisons

    local -a args=()
    local form

    for form in separate short positional terminator spaces leading-dash; do
        prepare_comparison "${form}"

        case "${form}" in
        separate) args=(--mode diff --profile test) ;;
        short) args=(-m diff -p test) ;;
        positional) args=(test) ;;
        terminator) args=(-- test) ;;
        spaces)
            cp "${fixture}/profiles/test.json" "${fixture}/profiles/test profile.json"

            args=(-- 'test profile')
            ;;
        leading-dash)
            cp "${fixture}/profiles/test.json" "${fixture}/profiles/-test.json"

            args=(-- -test)
            ;;
        esac

        run_cli "${args[@]}"

        (( status == 0 )) || fail "Profile form '${form}' failed"
        assert_contains "${fixture}/stdout" 'Settings file matched'
    done

    prepare_comparison code-failure

    printf '#!%s\nexit 9\n' "${BASH_PATH}" >"${fixture}/tools/code"

    run_cli --profile=test

    (( status == 1 )) || fail 'Extension command failure did not return 1'

    prepare_comparison diff-failure

    printf '#!%s\nexit 2\n' "${BASH_PATH}" >"${fixture}/tools/diff"

    chmod +x "${fixture}/tools/diff"

    run_cli --profile=test

    (( status == 1 )) || fail 'Diff failure did not return 1'

    echo 'PASS: profile argument forms and operational failure statuses'

    prepare_comparison base-only

    printf '%s\n' '{"example":"base","retained":true}' >"${TEST_TARGET}/settings.json"

    run_cli

    (( status == 0 )) || fail 'Base-only comparison failed'
    assert_contains "${fixture}/stdout" 'Settings file matched'

    prepare_comparison extension-addition

    printf '#!%s\nprintf "example.extension@1.0\\nextra.extension@1.0\\n"\n' \
        "${BASH_PATH}" >"${fixture}/tools/code"

    run_cli --profile=test

    (( status == 0 )) || fail 'Extension addition comparison failed'
    assert_contains "${fixture}/stdout" 'Extensions added to VS Code:'
    assert_contains "${fixture}/stdout" 'extra.extension@1.0'

    prepare_comparison extension-removal

    printf '#!%s\nexit 0\n' "${BASH_PATH}" >"${fixture}/tools/code"

    run_cli --profile=test

    (( status == 0 )) || fail 'Extension removal comparison failed'
    assert_contains "${fixture}/stdout" 'Extensions missing in VS Code:'
    assert_contains "${fixture}/stdout" 'example.extension@1.0'

    echo 'PASS: base-only configuration and extension additions/removals'
}

main "$@"
