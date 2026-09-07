#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

# mode:
#   (empty)     -> only focus next display
#   move_window -> send current window to next display, then follow focus
#   move_space  -> send whole current space to next display, then follow focus
#                  (requires SIP disabled / scripting-addition)
mode=${1:-}
all_display_indices_array=($(yabai -m query --displays | jq '.[].index | @sh' | tr -d \'\" | sort))

if [[ 1 -eq ${#all_display_indices_array[@]} ]]; then
  # only one display, do not move
  exit 1
fi

current_display_index=$(yabai -m query --displays --display | jq '.index')

# get next display display by cycle
for idx in "${!all_display_indices_array[@]}"; do
  if [[ $current_display_index -eq ${all_display_indices_array[idx]} ]]; then
      next_display_index=$(( (idx + 1) % ${#all_display_indices_array[@]} ))
    break
  fi
done

if [[ -n ${next_display_index:+x} ]]; then
  index=${all_display_indices_array[next_display_index]}
  case "$mode" in
    move_window)
      yabai -m window --display $index
      ;;
    move_space)
      # move the whole space to the target display; it follows automatically
      yabai -m space --display $index
      ;;
  esac
  yabai -m display --focus $index
fi
