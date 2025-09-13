#!/usr/bin/env bash

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

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
target_file="$target_dir/${file_name}"

echo "Updating VS Code settings file: $target_file"
cp "${script_dir}/${file_name}" "$target_file"
