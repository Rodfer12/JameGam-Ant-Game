#!/bin/sh
printf '\033c\033]0;%s\a' Silly Ant Game
base_path="$(dirname "$(realpath "$0")")"
"$base_path/SillyLinuxAntGame.x86_64" "$@"
