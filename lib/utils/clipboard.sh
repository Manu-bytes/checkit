#!/usr/bin/env bash
#
# lib/utils/clipboard.sh
# Clipboard Utility: System clipboard integration.
#
# Responsibility: Detect the available display server (X11, Wayland, macOS)
# and interface with the corresponding clipboard tool to copy text.

# ----------------------------------------------------------------------
# Public Functions
# ----------------------------------------------------------------------

# Public: Copies the provided text to the system clipboard.
# iterate through common clipboard providers (pbcopy, wl-copy, xclip, xsel)
# until one succeeds.
#
# $1 - text - The string content to copy.
#
# Returns EX_SUCCESS (0) if copied, EX_OPERATIONAL_ERROR (2) otherwise.
utils::copy_to_clipboard() {
  local input

  # Use argument $1 if provided; otherwise read from STDIN (supports piping)
  if [[ -n "$1" ]]; then
    input="$1"
  else
    input="$(cat)"
  fi

  # MacOS (pbcopy)
  if command -v pbcopy >/dev/null 2>&1; then
    if printf '%s' "$input" | pbcopy; then
      return "$EX_SUCCESS"
    fi

  # Wayland (wl-copy)
  elif command -v wl-copy >/dev/null 2>&1; then
    if printf '%s' "$input" | wl-copy; then
      return "$EX_SUCCESS"
    fi

  # X11 (xclip)
  elif command -v xclip >/dev/null 2>&1; then
    if printf '%s' "$input" | xclip -selection clipboard; then
      return "$EX_SUCCESS"
    fi

  # X11 (xsel)
  elif command -v xsel >/dev/null 2>&1; then
    if printf '%s' "$input" | xsel --clipboard --input; then
      return "$EX_SUCCESS"
    fi
  fi

  # Fallback: No tool found or execution failed
  return "$EX_OPERATIONAL_ERROR"
}
