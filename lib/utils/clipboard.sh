#!/usr/bin/env bash

# utils::copy_to_clipboard
# Attempts to copy the provided text to the system clipboard
# by automatically detecting the available tool.
#
# Arguments:
#   $1 - Text to copy
#
# Returns:
#   EX_SUCCESS if copied successfully.
#   EX_OPERATIONAL_ERROR if no tool found or execution failed.
utils::copy_to_clipboard() {
  local input="$1"

  if type pbcopy >/dev/null 2>&1; then
    # MacOS
    if echo -n "$input" | pbcopy; then
      return "$EX_SUCCESS"
    fi
  elif type wl-copy >/dev/null 2>&1; then
    # Wayland
    if echo -n "$input" | wl-copy; then
      return "$EX_SUCCESS"
    fi
  elif type xclip >/dev/null 2>&1; then
    # X11 (xclip)
    if echo -n "$input" | xclip -selection clipboard; then
      return "$EX_SUCCESS"
    fi
  elif type xsel >/dev/null 2>&1; then
    # X11 (xsel)
    if echo -n "$input" | xsel --clipboard --input; then
      return "$EX_SUCCESS"
    fi
  fi

  # If we reached here, no tool was found or the tool returned failure.
  return "$EX_OPERATIONAL_ERROR"
}
