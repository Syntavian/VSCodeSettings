#!/usr/bin/env bash

set -e

mode="${1:-diff}"
profile="$2"

if [[ "$OSTYPE" == "cygwin" || "$OSTYPE" == "msys" ]]; then
    os="win"
elif [[ "$OSTYPE" == "darwin"* ]]; then
    os="mac"
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    os="linux"
else
    echo -e "\nUnknown OS detected: $OSTYPE" >&2
    exit 1
fi

case $os in
win)
    target_dir="$HOME/AppData/Roaming/Code/User"
    ;;
mac)
    target_dir="$HOME/Library/Application Support/Code/User"
    ;;
linux)
    target_dir="$HOME/.config/Code/User"
    ;;
*)
    echo -e "\nUnimplemented OS target: $os" >&2
    exit 1
    ;;
esac

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
secrets_file="$script_dir/secrets.env"

touch "$secrets_file"

set -a

# shellcheck source=./secrets.env
. "$secrets_file"

set +a

subbed_vars=()

# Read the file line by line
while IFS= read -r line; do
    subbed_vars+=("$(echo "$line" | cut -d "=" -f 1)")
done <"$secrets_file"

# shellcheck disable=SC2016
subbed_var_string=$(printf '${%s} ' "${subbed_vars[@]}")

default_config=$(envsubst "$subbed_var_string" <"$script_dir/base.json" | jq)

if [ -f "$script_dir/profiles/$profile.json" ]; then
    profile_config=$(envsubst "$subbed_var_string" <"$script_dir/profiles/$profile.json" | jq)
else
    profile_config="{}"
fi

config_types=("settings" "keybindings")

for config in "${config_types[@]}"; do
    target_file="$target_dir/$config.json"

    config_output=$(echo "$default_config" | jq --sort-keys --argjson profile "$profile_config" '.'"$config"' + $profile.'"$config")

    if [ "$mode" == "diff" ]; then
        echo -e "\nChecking $config file: $target_file..."

        file_diff=$(diff -cw <(echo "$config_output") <(jq -n --sort-keys -f "$target_file") || :)

        if [[ -n $file_diff ]]; then
            echo -e "\n$file_diff"
        else
            echo -e "\n${config^} file matched"
        fi
    elif [ "$mode" == "apply" ]; then
        echo -e "\nUpdating $config file: $target_file"...

        echo "$config_output" >"$target_file"

        echo -e "\nDone"
    fi
done

echo -e "\nChecking extensions..."

readarray -t extensions < <(echo "$default_config" |
    jq --argjson profile "$profile_config" '.extensions + $profile.extensions' |
    jq -cr ".[]")

extension_diff=$(diff -cw <(echo "${extensions[@]}" | tr ' ' '\n' | sort -u) <(code --list-extensions --show-versions | sort) || :)

if [[ -n $extension_diff ]]; then
    echo -e "\nExtension mismatch found:"

    changed_extensions=$(echo "$extension_diff" | grep "^\!.*@" | cut -c3-)
    added_extensions=$(echo "$extension_diff" | grep "^+.*@" | cut -c3- | sed 's/^/    /')
    missing_extensions=$(echo "$extension_diff" | grep "^-.*@" | cut -c3- | sed 's/^/    /')

    if [[ -n $changed_extensions ]]; then
        echo -e "\n  Extensions changed in VS Code:"
        echo -e "    Expected:"

        while IFS=$'\n' read -r extension; do
            if [[ ${extensions[*]} =~ $extension ]]; then
                echo "      $extension"
            fi
        done <<<"$changed_extensions"

        echo -e "    Found:"

        while IFS=$'\n' read -r extension; do
            if ! [[ ${extensions[*]} =~ $extension ]]; then
                echo "      $extension"
            fi
        done <<<"$changed_extensions"
    fi

    if [[ -n $added_extensions ]]; then
        echo -e "\n  Extensions added to VS Code:"
        echo "$added_extensions"
    fi

    if [[ -n $missing_extensions ]]; then
        echo -e "\n  Extensions missing in VS Code:"
        echo "$missing_extensions"
    fi
else
    echo -e "\nAll extensions matched"
fi
