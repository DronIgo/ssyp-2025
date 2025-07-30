#!/bin/sh
echo -ne '\033c\033]0;Final project\a'
base_path="$(dirname "$(realpath "$0")")"
"$base_path/SSYP_25_lab5.x86_64" "$@"
