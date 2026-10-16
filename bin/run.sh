#!/usr/bin/env bash
# Merge VS Code configuration with a local profile, then compare or apply it.

# Copyright (C) 2025, 2026 Thomas Sloman (Syntavian)
# SPDX-License-Identifier: GPL-3.0-only
# Licensed under the GNU General Public License, version 3 only.
# See the repository LICENSE for the full terms.

set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
readonly SCRIPT_DIR

PROJECT_DIR=$(cd -- "${SCRIPT_DIR}/.." && pwd)
readonly PROJECT_DIR

# shellcheck source-path=SCRIPTDIR
# shellcheck source=./utils.sh
source "${SCRIPT_DIR}/utils.sh"

function show_help() {
    cat <<'EOF'
Compare or apply VS Code user settings/keybindings and check extensions.

Usage: bash bin/run.sh [options] [--] [profile]

Options:
    -h, --help               Show help and exit.
    -m, --mode MODE          diff (default) or apply; set/deploy alias apply.
    -p, --profile PROFILE    Local profiles/PROFILE.json; default: base only.
    --                      End options; one optional profile may follow.

Long value options also accept --mode=MODE and --profile=PROFILE.
Specify a profile once, either by option or as a positional argument.

Examples:
    bash bin/run.sh --profile home
    bash bin/run.sh --mode=diff -- home

Apply overwrites settings/keybindings without backups; extensions are only checked.
Normal execution may source secrets.env as shell code; use only trusted files.
Exit status: 0 success (including differences/help), 2 usage error, 1 operation failed.
EOF
}

function usage_error() {
    echo "$1" >&2
    echo 'Use --help for usage.' >&2

    exit 2
}

# Sets main's mode/profile locals through intentional Bash dynamic scope.
function read_args() {
    local profile_seen=false option value

    while (( $# > 0 )); do
        case "$1" in
        -h | --help)
            show_help

            exit 0
            ;;
        -m | --mode | -p | --profile)
            option=$1

            (( $# >= 2 )) || usage_error "Missing value for '${option}'"
            [[ -n "$2" && "$2" != -* ]] || usage_error "Missing value for '${option}'"

            value=$2

            shift

            case "${option}" in
            -m | --mode) mode=${value} ;;
            -p | --profile)
                [[ "${profile_seen}" == false ]] || usage_error 'Profile specified more than once'

                profile=${value}
                profile_seen=true
                ;;
            esac
            ;;
        --mode=* | --profile=*)
            option=${1%%=*}
            value=${1#*=}

            [[ -n "${value}" ]] || usage_error "Missing value for '${option}'"

            if [[ "${option}" == --mode ]]; then
                mode=${value}
            else
                [[ "${profile_seen}" == false ]] || usage_error 'Profile specified more than once'

                profile=${value}
                profile_seen=true
            fi
            ;;
        --)
            shift

            (( $# <= 1 )) || usage_error 'Expected at most one profile'

            if (( $# == 1 )); then
                [[ "${profile_seen}" == false ]] || usage_error 'Profile specified more than once'
                [[ -n "$1" ]] || usage_error 'Profile cannot be empty'

                profile=$1
            fi

            break
            ;;
        -*)
            usage_error "Unknown argument: '${1%%=*}'"
            ;;
        *)
            [[ "${profile_seen}" == false ]] || usage_error 'Expected at most one profile'
            [[ -n "$1" ]] || usage_error 'Profile cannot be empty'

            profile=$1
            profile_seen=true
            ;;
        esac

        shift
    done

    case "${mode}" in
    diff | apply | set | deploy) ;;
    *) usage_error "Unknown mode: '${mode}'" ;;
    esac
}

function check_dependencies() {
    local dependency
    local -a missing=()

    for dependency in jq envsubst diff code sort; do
        if ! command -v "${dependency}" >/dev/null; then
            missing+=("${dependency}")
        fi
    done

    if (( ${#missing[@]} > 0 )); then
        echo "Missing required dependencies: ${missing[*]}" >&2
        return 1
    fi

    return 0
}

# Print a context diff; ordinary differences succeed, operational errors return 1.
function compare_text() {
    local status=0

    diff -cw \
        <(if [[ -n "$1" ]]; then printf '%s\n' "$1"; fi) \
        <(if [[ -n "$2" ]]; then printf '%s\n' "$2"; fi) || status=$?

    if (( status > 1 )); then
        echo 'Unable to compare configuration' >&2
        return 1
    fi

    return 0
}

# Check producers explicitly so process substitution cannot hide their failures.
function check_extensions() {
    local default_config=$1 profile_config=$2
    local expected installed extension_diff line extension
    local -a extensions=() changed=() added=() missing=()

    expected=$(jq -r --argjson profile "${profile_config}" \
        '.extensions + $profile.extensions | .[]' <<<"${default_config}") || return 1
    installed=$(code --list-extensions --show-versions) || return 1
    expected=$(sort -u <<<"${expected}") || return 1
    installed=$(sort <<<"${installed}") || return 1
    extension_diff=$(compare_text "${expected}" "${installed}") || return 1

    if [[ -z "${extension_diff}" ]]; then
        echo -e '\nAll extensions matched'
        return 0
    fi

    echo -e '\nExtension mismatch found:'
    readarray -t extensions <<<"${expected}"

    while IFS= read -r line; do
        case "${line}" in
        '! '*@*) changed+=("${line:2}") ;;
        '+ '*@*) added+=("${line:2}") ;;
        '- '*@*) missing+=("${line:2}") ;;
        esac
    done <<<"${extension_diff}"

    if (( ${#changed[@]} > 0 )); then
        echo -e '\n  Extensions changed in VS Code:\n    Expected:'

        for extension in "${changed[@]}"; do
            for line in "${extensions[@]}"; do
                if [[ "${line}" == "${extension}" ]]; then
                    printf '      %s\n' "${extension}"

                    break
                fi
            done
        done

        echo '    Found:'

        for extension in "${changed[@]}"; do
            for line in "${extensions[@]}"; do
                [[ "${line}" != "${extension}" ]] || continue 2
            done

            printf '      %s\n' "${extension}"
        done
    fi

    if (( ${#added[@]} > 0 )); then
        echo -e '\n  Extensions added to VS Code:'
        printf '    %s\n' "${added[@]}"
    fi

    if (( ${#missing[@]} > 0 )); then
        echo -e '\n  Extensions missing in VS Code:'
        printf '    %s\n' "${missing[@]}"
    fi

    return 0
}

function main() {
    # read_args intentionally sets these caller-local variables.
    local mode=diff profile=''

    read_args "$@"

    check_dependencies

    echo -e '\nVSCode settings orchestration tool started with config:'
    echo "  mode='${mode}'"
    echo "  profile='${profile:-None}'"

    local secrets_file="${PROJECT_DIR}/secrets.env"
    local line var_name subbed_var_string default_config profile_config
    local -a subbed_vars=()

    if [[ -f "${secrets_file}" ]]; then
        echo -e "Reading var file: '${secrets_file}'...\n"

        set -a
        # Local secrets are intentionally excluded from static analysis.
        # shellcheck source=/dev/null
        source "${secrets_file}"
        set +a

        while IFS= read -r line || [[ -n "${line}" ]]; do
            var_name=${line%%=*}
            subbed_vars+=("${var_name}")
        done <"${secrets_file}"
    fi

    # envsubst requires literal variable references.
    # shellcheck disable=SC2016
    subbed_var_string=$(printf '${%s} ' "${subbed_vars[@]}")
    default_config=$(envsubst "${subbed_var_string}" <"${PROJECT_DIR}/base.json" | jq)
    profile_config='{}'

    if [[ -n "${profile}" ]]; then
        local profile_file="${PROJECT_DIR}/profiles/${profile}.json"

        if [[ ! -f "${profile_file}" ]]; then
            echo "Profile file: '${profile_file}' for profile: '${profile}' does not exist" >&2
            return 1
        fi

        profile_config=$(envsubst "${subbed_var_string}" <"${profile_file}" | jq)
    fi

    local target_dir config target_file config_output current_config file_diff

    target_dir=$(get_vscode_user_dir)

    for config in settings keybindings; do
        target_file="${target_dir}/${config}.json"
        config_output=$(jq --sort-keys --argjson profile "${profile_config}" \
            --arg config "${config}" '.[$config] + $profile[$config]' <<<"${default_config}")

        if [[ "${mode}" == diff ]]; then
            echo -e "\nChecking ${config} file: '${target_file}'..."

            current_config=$(jq --sort-keys . "${target_file}")
            file_diff=$(compare_text "${config_output}" "${current_config}")

            if [[ -n "${file_diff}" ]]; then
                printf '\n%s\n' "${file_diff}"
            else
                echo -e "\n${config^} file matched"
            fi
        else
            echo -e "\nUpdating ${config} file: '${target_file}'..."

            printf '%s\n' "${config_output}" >"${target_file}"

            echo -e '\nDone'
        fi
    done

    echo -e '\nChecking extensions...'

    check_extensions "${default_config}" "${profile_config}"
}

# Normalize operational failures without disabling errexit inside main.
trap 'exit 1' ERR

main "$@"
