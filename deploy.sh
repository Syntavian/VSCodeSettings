#!/usr/bin/env bash

set -e

profile="$1"
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
secrets_file="$script_dir/secrets.env"

touch "$secrets_file"

# shellcheck source=./secrets.env
. "$secrets_file"

if [[ "$OSTYPE" == "cygwin" || "$OSTYPE" == "msys" ]]; then
    os="win"
elif [[ "$OSTYPE" == "darwin"* ]]; then
    os="mac"
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    os="linux"
else
    echo "Unknown OS detected: $OSTYPE" >&2
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
    echo "Unimplemented OS target: $os" >&2
    exit 1
    ;;
esac

file_names=("settings.json" "keybindings.json")

for file_name in "${file_names[@]}"; do
    target_file="$target_dir/$file_name"

    echo "Updating VS Code $file_name: $target_file"

    if [[ -f "$script_dir/profiles/$profile.$file_name" ]]; then
        profile_json=$(
            jq -n \
                --arg JIRA_PROJECT_KEY "$JIRA_PROJECT_KEY" \
                --arg JIRA_SITE_ID "$JIRA_SITE_ID" \
                -f "$script_dir/profiles/$profile.$file_name"
        )

        jq --argjson profile "$profile_json" '. + $profile' "$script_dir/$file_name" >"$target_file"
    else
        jq -fn "$script_dir/$file_name" >"$target_file"
    fi
done
