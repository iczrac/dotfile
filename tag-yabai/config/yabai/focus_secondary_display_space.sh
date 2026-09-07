#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

# 跳转到"副显示器"（display index 最大的那个，身份固定，不随当前 focus 变化）的第 N 个 space
# arg[1] = N (1-based)

n=${1:?usage: focus_secondary_display_space.sh N}

target_display_index=$(yabai -m query --displays | jq 'max_by(.index).index')

if [[ -z "$target_display_index" || "$target_display_index" == "null" ]]; then
  exit 1
fi

target_space_index=$(yabai -m query --spaces --display "$target_display_index" | jq --argjson n "$n" \
  'map(select(."is-native-fullscreen" == false)) | sort_by(.index) | .[$n-1].index')

if [[ -z "$target_space_index" || "$target_space_index" == "null" ]]; then
  exit 1
fi

yabai -m space --focus "$target_space_index"
