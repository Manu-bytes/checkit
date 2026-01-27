#!/usr/bin/env bash

# Global variables for CLI state
__CLI_MODE=""       # check, create, verify_string
__CLI_ALGO="sha256" # Default algorithm
__CLI_FILES=()      # Array of target files
__CLI_FILE=""       # Single file target (for convenience)
__CLI_HASH=""       # Expected hash (for verify_string)
__CLI_COPY=false    # Clipboard flag
__CLI_QUIET=false   # Quiet flag
__CLI_STATUS=false  # Status only flag

# cli::print_usage
cli::print_usage() {
  cat <<EOF
Usage:
  checkit [FILE] [HASH]             # Quick Verify
  checkit [FILE] [--algo ALGO]      # Calculate Hash
  checkit -c [SUMFILE]              # Check multiple hashes

Options:
  -c, --check       Read checksums from file
  -a, --algo <alg>  Specify algorithm (md5, sha256, etc). Default: sha256
  -y, --copy        Copy output to clipboard
  -h, --help        Show this help
      --version     Show version
EOF
}

# cli::parse_args
cli::parse_args() {
  # Reset globals
  __CLI_MODE=""
  __CLI_ALGO="sha256"
  __CLI_FILES=()
  __CLI_FILE=""
  __CLI_HASH=""
  __CLI_COPY=false
  __CLI_QUIET=false
  __CLI_STATUS=false

  if [[ $# -eq 0 ]]; then
    echo "Error: Missing arguments."
    cli::print_usage
    return "$EX_OPERATIONAL_ERROR"
  fi

  # 1. Parse Args Loop
  while [[ $# -gt 0 ]]; do
    case "$1" in
    -h | --help)
      cli::print_usage
      return "$EX_SUCCESS"
      ;;
    --version)
      echo "checkit v0.1.0"
      return "$EX_SUCCESS"
      ;;
    -c | --check)
      __CLI_MODE="check"
      shift
      ;;
    -a | --algo)
      if [[ -n "$2" && "$2" != -* ]]; then
        __CLI_ALGO="$2"
        shift 2
      else
        echo "Error: --algo requires an argument."
        return "$EX_OPERATIONAL_ERROR"
      fi
      ;;
    -y | --copy)
      __CLI_COPY=true
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
    -*)
      echo "Error: Unknown option $1"
      return "$EX_OPERATIONAL_ERROR"
      ;;
    *)
      # Positional argument collection
      __CLI_FILES+=("$1")
      shift
      ;;
    esac
  done

  # 2. Mode Inference (The Logic You Requested)

  # If explicit mode (-c) has already been defined
  if [[ "$__CLI_MODE" == "check" ]]; then
    if [[ ${#__CLI_FILES[@]} -eq 0 ]]; then
      echo "Error: Missing sumfile argument for check mode."
      return "$EX_OPERATIONAL_ERROR"
    fi
    return "$EX_SUCCESS"
  fi

  # If there is NO explicit mode, we infer based on the number of positional arguments.
  case "${#__CLI_FILES[@]}" in
  1)
    # Case: checkit file.txt (or checkit file.txt --algo ...)
    # This is Generation Mode (Create)
    __CLI_MODE="create"
    __CLI_FILES=("${__CLI_FILES[0]}") # Keep consistent
    ;;
  2)
    # Case: checkit file.txt a1b2c3...
    # This is Quick Verification Mode (Verify String)
    __CLI_MODE="verify_string"
    __CLI_FILE="${__CLI_FILES[0]}"
    __CLI_HASH="${__CLI_FILES[1]}"
    ;;
  *)
    # 0 arguments or more than 2 (without explicit flags) is ambiguous or an error
    echo "Error: Invalid number of arguments. Use -h for help."
    return "$EX_OPERATIONAL_ERROR"
    ;;
  esac

  return "$EX_SUCCESS"
}
