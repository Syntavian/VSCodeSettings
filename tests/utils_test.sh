#!/usr/bin/env bash

#
# Generated wholly by gpt-6.1-sol
# Last updated: 2026-10-16
#

# Test platform/path helpers using mocks, without reading live editor settings.

set -Eeuo pipefail

PROJECT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
readonly PROJECT_DIR

source "${PROJECT_DIR}/bin/utils.sh"

function assert_equal() {
    if [[ "$1" != "$2" ]]; then
        printf 'FAIL: expected <%s>, got <%s>\n' "$1" "$2" >&2

        exit 1
    fi
}

# Override environment detection and external tools; never access live settings.
function get_os() { echo linux; }

function powershell.exe() { printf 'C:\\Users\\Test User\\AppData\\Roaming\r\n'; }

function wslpath() {
    assert_equal -u "$1"

    assert_equal 'C:\Users\Test User\AppData\Roaming' "$2"

    printf '/mnt/c/Users/Test User/AppData/Roaming\n'
}

function test_wsl() {
    WSL_DISTRO_NAME=Test

    assert_equal '/mnt/c/Users/Test User/AppData/Roaming/Code/User' "$(get_vscode_user_dir)"

    WSL_DISTRO_NAME=''
    WSL_INTEROP=/test/interop

    assert_equal '/mnt/c/Users/Test User/AppData/Roaming/Code/User' "$(get_vscode_user_dir)"

    WSL_INTEROP=''

    function grep() { return 0; }

    assert_equal '/mnt/c/Users/Test User/AppData/Roaming/Code/User' "$(get_vscode_user_dir)"
}

function assert_failure() {
    if (get_vscode_user_dir) >/dev/null 2>&1; then
        echo 'FAIL: expected settings resolution to fail' >&2

        exit 1
    fi
}

# Redefined mocks are invoked indirectly by the sourced path-resolution helpers.
# shellcheck disable=SC2317
function test_failures_and_native_paths() {
    function powershell.exe() { return 1; }

    assert_failure

    function powershell.exe() { printf '\r\n'; }

    assert_failure

    function powershell.exe() { echo 'C:\Users\Test User\AppData\Roaming'; }

    function wslpath() { return 1; }

    assert_failure

    function wslpath() { return 0; }

    assert_failure

    function command() { return 1; }

    assert_failure

    unset -f command

    function grep() { return 1; }

    HOME='/test/home with spaces'

    assert_equal "${HOME}/.config/Code/User" "$(get_vscode_user_dir)"

    function get_os() { echo mac; }

    assert_equal "${HOME}/Library/Application Support/Code/User" "$(get_vscode_user_dir)"

    function get_os() { echo win; }

    assert_equal "${HOME}/AppData/Roaming/Code/User" "$(get_vscode_user_dir)"

    function get_os() { echo unsupported; }

    assert_failure

    echo 'PASS: WSL detection, Windows path conversion, error handling, and native platform paths'
}

function main() {
    local HOME WSL_DISTRO_NAME='' WSL_INTEROP=''

    test_wsl

    test_failures_and_native_paths

    # A library failure must return control instead of exiting its caller.
    (
        source "${PROJECT_DIR}/bin/utils.sh"

        OSTYPE=unsupported

        if get_os >/dev/null 2>&1; then
            echo 'FAIL: unsupported OS succeeded' >&2

            exit 1
        fi

        if get_vscode_user_dir >/dev/null 2>&1; then
            echo 'FAIL: unsupported settings target succeeded' >&2

            exit 1
        fi

        echo 'PASS: library errors return control to caller'
    )
}

main "$@"
