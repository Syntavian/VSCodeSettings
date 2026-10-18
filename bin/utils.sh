#!/usr/bin/env bash

# Copyright (C) 2026 Thomas Sloman (Syntavian)
# SPDX-License-Identifier: GPL-3.0-only
# Licensed under the GNU General Public License, version 3 only.
# See the repository LICENSE for the full terms.

function get_os() {
    if [[ "$OSTYPE" == "cygwin" || "$OSTYPE" == "msys" ]]; then
        echo "win"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        echo "mac"
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        echo "linux"
    else
        echo -e "\nUnknown OS detected: '$OSTYPE'" >&2
        exit 1
    fi
}

function get_vscode_user_dir() {
    local os
    os=$(get_os)

    case $os in
    win)
        echo "$HOME/AppData/Roaming/Code/User"
        ;;
    mac)
        echo "$HOME/Library/Application Support/Code/User"
        ;;
    linux)
        echo "$HOME/.config/Code/User"
        ;;
    *)
        echo -e "\nUnimplemented OS: '$os'" >&2
        exit 1
        ;;
    esac
}
