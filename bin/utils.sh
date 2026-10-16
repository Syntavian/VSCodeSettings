#!/usr/bin/env bash

# Copyright (C) 2026 Thomas Sloman (Syntavian)
# SPDX-License-Identifier: GPL-3.0-only
# Licensed under the GNU General Public License, version 3 only.
# See the repository LICENSE for the full terms.
# Sourced platform/path helpers; leave shell options and exit policy to the caller.

# Print win, mac, or linux from OSTYPE; return 1 for unsupported platforms.
function get_os() {
    if [[ "${OSTYPE}" == cygwin || "${OSTYPE}" == msys ]]; then
        echo win
    elif [[ "${OSTYPE}" == darwin* ]]; then
        echo mac
    elif [[ "${OSTYPE}" == linux-gnu* ]]; then
        echo linux
    else
        echo -e "\nUnknown OS detected: '${OSTYPE}'" >&2

        return 1
    fi
}

# Test WSL environment markers and kernel fallback; return 1 on native Linux.
function is_wsl() {
    [[ -n "${WSL_DISTRO_NAME:-}" || -n "${WSL_INTEROP:-}" ]] ||
        grep -qi microsoft /proc/sys/kernel/osrelease 2>/dev/null
}

# Print the user settings directory, targeting Windows from WSL. Read HOME/WSL
# markers and invoke PowerShell/wslpath in WSL. Return 1 with stderr diagnostics
# for unsupported platforms, missing tools, or path-resolution failures.
function get_vscode_user_dir() {
    local os

    os=$(get_os) || return 1

    if [[ "${os}" == linux ]] && is_wsl; then
        local appdata windows_path

        if ! command -v powershell.exe >/dev/null || ! command -v wslpath >/dev/null; then
            echo 'Resolving Windows settings from WSL requires powershell.exe and wslpath' >&2

            return 1
        fi

        if ! appdata=$(powershell.exe -NoProfile -NonInteractive \
            -Command '[Environment]::GetFolderPath("ApplicationData")'); then
            echo 'Unable to resolve the Windows application-data directory' >&2

            return 1
        fi

        appdata=${appdata//$'\r'/}

        if [[ -z "${appdata}" ]]; then
            echo 'Windows application-data directory is empty' >&2

            return 1
        fi

        if ! windows_path=$(wslpath -u "${appdata}"); then
            echo 'Unable to translate the Windows application-data directory' >&2

            return 1
        fi

        if [[ -z "${windows_path}" ]]; then
            echo 'Translated Windows application-data directory is empty' >&2

            return 1
        fi

        printf '%s/Code/User\n' "${windows_path}"

        return 0
    fi

    case "${os}" in
    win)
        echo "${HOME}/AppData/Roaming/Code/User"
        ;;
    mac)
        echo "${HOME}/Library/Application Support/Code/User"
        ;;
    linux)
        echo "${HOME}/.config/Code/User"
        ;;
    *)
        echo -e "\nUnimplemented OS: '${os}'" >&2

        return 1
        ;;
    esac
}
