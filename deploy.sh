#!/usr/bin/env bash

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

if [[ "$OSTYPE" == "cygwin" || "$OSTYPE" == "msys" ]]; then
    os="win"
elif [[ "$OSTYPE" == "darwin"* ]]; then
    os="mac"
else
    echo "Unknown OS detected: $OSTYPE" >&2
    exit 1
fi

case $os in
win)
    target_file="$HOME/AppData/Roaming/Code/User/settings.json"
    ;;
mac)
    target_file="$HOME/Library/Application Support/Code/User/settings.json"
    ;;
*)
    echo "Unimplemented OS target: $os" >&2
    exit 1
    ;;
esac

echo "Updating VS Code settings file: $target_file"
cp "${script_dir}/settings.json" "$target_file"
