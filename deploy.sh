#!/usr/bin/env bash

set -e

profile="$1"
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
secrets_file="$script_dir/secrets.env"

touch "$secrets_file"

# shellcheck source=./secrets.env
. "$secrets_file"

if [[ -z $profile || ! -f "$script_dir/profiles/$profile.json" ]]; then
    echo "Invalid profile: $profile" >&2
    exit 1
fi

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

# TODO: Potentially handle shortcuts & others?

file_name="settings.json"
target_file="$target_dir/$file_name"

profile_json=$(
    jq -n \
        --arg JIRA_PROJECT_KEY "$JIRA_PROJECT_KEY" \
        --arg JIRA_SITE_ID "$JIRA_SITE_ID" \
        -f "$script_dir/profiles/$profile.json"
)

echo "Updating VS Code settings file: $target_file"
jq --argjson profile "$profile_json" '. + $profile' "$script_dir/$file_name" >"$target_file"
