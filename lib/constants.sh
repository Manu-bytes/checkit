#!/usr/bin/env bash

# Global constants and exit codes for checkit.
#
# This file contains the standard exit codes and global variables
# used throughout the application to ensure consistency.
# shellcheck disable=SC2034

# ----------------------------------------------------------------------
# Exit Codes
# ----------------------------------------------------------------------

# Success: Operation completed successfully (integrity verified or hash generated).
readonly EX_SUCCESS=0

# Integrity Failure: Checksum mismatch found.
readonly EX_INTEGRITY_FAIL=1

# Operational Error: File not found, invalid argument, permission denied.
readonly EX_OPERATIONAL_ERROR=2

# Security Failure: Invalid or untrusted signature (.asc/.sig).
readonly EX_SECURITY_FAIL=3

# Version file
readonly VERSION_FILE="$PROJECT_ROOT/VERSION"

if [[ -f "$VERSION_FILE" ]]; then
  CHECKIT_VERSION=$(cat "$VERSION_FILE")
  readonly CHECKIT_VERSION
else
  readonly CHECKIT_VERSION="unknown"
fi

# ----------------------------------------------------------------------
# Metadata & Branding
# ----------------------------------------------------------------------
readonly APP_NAME="checkit"
readonly APP_AUTHOR="Manu-bytes"
APP_YEAR="$(date +%Y)"
readonly APP_YEAR
readonly APP_LICENSE="GPLv3+"
readonly APP_WEBSITE="https://github.com/Manu-bytes/checkit"

# Configuration & Colors
# -------------------------
# Use colors only when output is an interactive terminal (not a pipe)
if [[ -t 1 ]]; then
  readonly C_R="\033[0m"              # Reset
  readonly C_BOLD="\033[1m"           # Bold
  readonly C_RED="\033[38;5;196m"     # Red
  readonly C_REDH="\033[38;5;160m"    # Redh
  readonly C_GREEN="\033[32m"         # Green
  readonly C_GREENH="\033[38;5;46m"   # Green
  readonly C_YELLOW="\033[33m"        # Yellow
  readonly C_ORANGE="\033[38;5;208m"  # Orange
  readonly C_LORANGE="\033[38;5;167m" # LOrange
  readonly C_BLUE="\033[38;5;63m"     # Blue
  readonly C_CYAN="\033[36m"          # Cyan
  readonly C_CYANG="\033[38;5;49m"    # CyanG
  readonly C_MAGENTA="\033[35m"       # Magenta
  readonly C_MSG1="\033[38;5;243m"    # gray
  readonly C_MSG2="\033[38;5;250m"    # gray
else
  readonly C_R=""
  readonly C_BOLD=""
  readonly C_RED=""
  readonly C_GREEN=""
  readonly C_YELLOW=""
  readonly C_ORANGE=""
  readonly C_LORANGE=""
  readonly C_BLUE=""
  readonly C_CYAN=""
  readonly C_CYANG=""
  readonly C_MAGENTA=""
  readonly C_MSG1=""
  readonly C_MSG2=""
fi

# Configuration Symbols
# ---------------------------

# Path & Defaults
# ---------------------------
readonly CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/checkit"
readonly CONFIG_FILE="$CONFIG_DIR/checkit.conf"

# Default mode if nothing is found
MODE="ascii"

# ---------------------------
# Load Configuration
# ---------------------------
if [[ -f "$CONFIG_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$CONFIG_FILE"
fi

# 2. Normalize MODE to lowercase
# We use the modern syntax with a fallback for older Bash versions
if [[ "${BASH_VERSINFO[0]}" -ge 4 ]]; then
  MODE="${MODE,,}"
else
  MODE=$(echo "$MODE" | tr '[:upper:]' '[:lower:]')
fi

case $MODE in
"nerd" | "nerdfonts" | "nerdfont")
  # LOG_LEVEL: High (Nerd Fonts Detected)
  readonly SYMBOL_INFO=" "
  readonly SYMBOL_CHECK="✔"
  readonly SYMBOL_MISSING="󰃹"
  readonly SYMBOL_FAILED="󱈸"
  readonly SYMBOL_SKIPPED="󱔕"
  readonly SYMBOL_SIGNED=" "
  readonly SYMBOL_BAD=""
  readonly SYMBOL_WARNING=" "
  readonly SYMBOL_REPORT="󰅾"
  readonly SYMBOL_ERROR=" "
  readonly SYMBOL_CRITICAL="󰝧 "
  readonly SYMBOL_CLIPB="󰢨 "
  ;;
"unicode" | "icons" | "icon")
  # LOG_LEVEL: Medium (Unicode/Emojis Supported)
  readonly SYMBOL_INFO="🏷️"
  readonly SYMBOL_CHECK="✅"
  readonly SYMBOL_MISSING="🔍"
  readonly SYMBOL_FAILED="❗"
  readonly SYMBOL_SKIPPED="🦘"
  readonly SYMBOL_SIGNED="📝"
  readonly SYMBOL_BAD=" 📝❌"
  readonly SYMBOL_WARNING="⚠️"
  readonly SYMBOL_REPORT="📑"
  readonly SYMBOL_ERROR="❌"
  readonly SYMBOL_CRITICAL="⛔"
  readonly SYMBOL_CLIPB="📋"
  ;;
*)
  # LOG_LEVEL: Low (ASCII only)
  readonly SYMBOL_INFO="   [INFO] "
  readonly SYMBOL_CHECK="     [OK]"
  readonly SYMBOL_MISSING="[MISSING]"
  readonly SYMBOL_FAILED=" [FAILED]"
  readonly SYMBOL_SKIPPED="[SKIPPED]"
  readonly SYMBOL_SIGNED="[SIGNED]"
  readonly SYMBOL_BAD="[BAD SIGNED]"
  readonly SYMBOL_WARNING="[WARNING]"
  readonly SYMBOL_REPORT=" WARNING:"
  readonly SYMBOL_ERROR="ERROR: "
  readonly SYMBOL_CRITICAL="[CRITICAL]"
  readonly SYMBOL_CLIPB="[Context]"
  ;;
esac
