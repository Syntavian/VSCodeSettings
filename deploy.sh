#!/usr/bin/env bash

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

cp "${script_dir}/settings.json" "${HOME}\AppData\Roaming\Code\User\settings.json"
