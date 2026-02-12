#!/usr/bin/env bash
#
# lib/cli/args.sh
# CLI Argument Parser: Parses command line arguments and flags.
#
# Responsibility: Populates global configuration variables (__CLI_*) based on
# user input and infers the execution mode.

# ----------------------------------------------------------------------
# Global Variables (CLI State)
# ----------------------------------------------------------------------

__CLI_MODE=""               # check, create, verify_string
__CLI_ALGO="sha256"         # Default algorithm
__CLI_ALGO_SET=false        # Set algorithm
__CLI_FILES=()              # Array of target files
__CLI_FILE=""               # Single file target (for convenience)
__CLI_HASH=""               # Expected hash (for verify_string)
__CLI_COPY=false            # Clipboard flag
__CLI_QUIET=false           # Quiet flag
__CLI_STATUS=false          # Status only flag
__CLI_STRICT_SECURITY=false # Verify GPG signatures strictly
__CLI_IGNORE_MISSING=false  # Ignore missing files when processing
__CLI_STRICT=false          # Fail on any non-fatal warnings / enforce strict mode
__CLI_WARN=false            # Show warnings (overrides quiet for warnings)
__CLI_ALL_ALGOS=false       # Flag --all
__CLI_SIGN=false            # Flag --sign
__CLI_ZERO=false            # Flag --zero
__CLI_OUTPUT_FMT="gnu"      # Default output format (gnu, bsd, json, xml)
__CLI_OUTPUT_FILE=""        # File to store hashes (-f)
__CLI_SIGN_MODE=""          # Signature mode: "clear" for inline or "detach"
__CLI_SIGN_ARMOR=false      # Flag --armor

# ----------------------------------------------------------------------
# Public Functions
# ----------------------------------------------------------------------

# Public: Delegates help display to the UI adapter.
#
# Returns nothing.
cli::print_usage() {
  ui::show_help
}

# Public: Parses raw command line arguments and populates global state.
# Handles flag processing and infers the operation mode based on input.
#
# $@ - The command line arguments passed to the script.
#
# Returns 0 on success, or EX_OPERATIONAL_ERROR (2) on parsing failure.
cli::parse_args() {
  # Reset globals to ensures clean state
  __CLI_MODE=""
  __CLI_ALGO="sha256"
  __CLI_ALGO_SET=false
  __CLI_FILES=()
  __CLI_FILE=""
  __CLI_HASH=""
  __CLI_COPY=false
  __CLI_QUIET=false
  __CLI_STATUS=false
  __CLI_STRICT_SECURITY=false
  __CLI_IGNORE_MISSING=false
  __CLI_STRICT=false
  __CLI_WARN=false

  if [[ $# -eq 0 ]]; then
    ui::log_warning "$(ui::get_msg 'warn_arg_missing')"
    cli::print_usage
    return "$EX_OPERATIONAL_ERROR"
  fi

  while [[ $# -gt 0 ]]; do
    case "$1" in
    -c | --check)
      __CLI_MODE="check"
      shift
      ;;
    -a | --algo)
      __CLI_ALGO="$2"
      __CLI_ALGO_SET=true
      shift 2
      ;;
    -v | --verify-sign)
      __CLI_STRICT_SECURITY=true
      shift
      ;;
    -y | --copy)
      __CLI_COPY=true
      shift
      ;;
    --ignore-missing)
      __CLI_IGNORE_MISSING=true
      shift
      ;;
    --strict)
      __CLI_STRICT=true
      shift
      ;;
    -w | --warn)
      __CLI_WARN=true
      shift
      ;;
    -q | --quiet)
      __CLI_QUIET=true
      shift
      ;;
    --status)
      __CLI_STATUS=true
      shift
      ;;
    --all)
      __CLI_ALL_ALGOS=true
      shift
      ;;
    -s | --sign)
      __CLI_SIGN_MODE="clear"
      __CLI_SIGN=true
      shift
      ;;
    --detach-sign)
      __CLI_SIGN_MODE="detach"
      __CLI_SIGN=true
      shift
      ;;
    -f | --file)
      __CLI_OUTPUT_FILE="$2"
      shift 2
      ;;
    --armor)
      __CLI_SIGN_ARMOR=true
      shift
      ;;
    -z | --zero)
      __CLI_ZERO=true
      shift
      ;;
    --tag)
      __CLI_OUTPUT_FMT="bsd"
      shift
      ;;
    -o | --output)
      local fmt="$2"
      if [[ "$fmt" =~ ^(text|gnu|bsd|json|xml)$ ]]; then
        [[ "$fmt" == "text" ]] && fmt="gnu"
        __CLI_OUTPUT_FMT="$fmt"
      else
        ui::log_error "$(ui::fmt_msg 'err_arg_fmt_invalid' "$fmt")"
        return "$EX_OPERATIONAL_ERROR"
      fi
      shift 2
      ;;
    -h | --help)
      cli::print_usage
      exit "$EX_SUCCESS"
      ;;
    --version)
      ui::show_version
      exit "$EX_SUCCESS"
      ;;
    -*)
      ui::log_error "$(ui::fmt_msg 'err_arg_opt_unknown' "$1")"
      return "$EX_OPERATIONAL_ERROR"
      ;;
    *)
      # Positional argument collection
      __CLI_FILES+=("$1")
      shift
      ;;
    esac
  done

  # Mode Inference Logic
  if [[ "$__CLI_MODE" == "check" ]]; then
    if [[ ${#__CLI_FILES[@]} -eq 0 ]]; then
      ui::log_error "$(ui::get_msg 'err_check_no_file')"
      return "$EX_OPERATIONAL_ERROR"
    fi
    return "$EX_SUCCESS"
  fi

  case "${#__CLI_FILES[@]}" in
  1)
    __CLI_MODE="create"
    __CLI_FILES=("${__CLI_FILES[0]}")
    ;;
  2)
    __CLI_MODE="verify_string"
    __CLI_FILE="${__CLI_FILES[0]}"
    __CLI_HASH="${__CLI_FILES[1]}"
    ;;
  *)
    ui::log_error "$(ui::get_msg 'err_ambiguous_mode')"
    return "$EX_OPERATIONAL_ERROR"
    ;;
  esac

  return "$EX_SUCCESS"
}
