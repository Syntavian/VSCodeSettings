#!/usr/bin/env bash

set -e

mode="${1:-diff}"
profile="$2"

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
secrets_file="$script_dir/secrets.env"

touch "$secrets_file"

set -a

# shellcheck source=./secrets.env
. "$secrets_file"

set +a

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

config_types=("settings" "keybindings")
default_config=$(envsubst <"$script_dir/profiles/default.json" | jq)
profile_config="{}"

if [ -f "$script_dir/profiles/$profile.json" ]; then
    profile_config=$(envsubst <"$script_dir/profiles/$profile.json" | jq)
fi

for config in "${config_types[@]}"; do
    target_file="$target_dir/$config.json"

    config_output=$(echo "$default_config" | jq --argjson profile "$profile_config" '.'"$config"' + $profile.'"$config")

    if [ "$mode" == "diff" ]; then
        echo -e "\nChecking $config file: $target_file..."

        file_diff=$(diff -cw <(echo "$config_output") "$target_file" || :)

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
