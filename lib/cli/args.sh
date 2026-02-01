#!/usr/bin/env bash

# Global variables for CLI state
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
__CLI_IGNORE_MISSING=false
__CLI_STRICT=false
__CLI_WARN=false

# cli::print_usage
cli::print_usage() {
  cat <<EOF
Usage:
  checkit [FILE] [HASH]             # Quick Verify
  checkit [FILE] [--algo ALGO]      # Calculate Hash
  checkit -c [SUMFILE] [OPTIONS]    # Check multiple hashes

Options:
  -c, --check           Read checksums from file
  -a, --algo <alg>      Specify algorithm (md5, sha256, etc). Default: sha256
  -v, --verify-sign     Verify GPG signature if present (enforces strict mode)
  -y, --copy            Copy output to clipboard

Check Mode Options:
      --ignore-missing  Don't fail or report status for missing files
      --quiet           Don't print OK for each successfully verified file
      --status          Don't output anything, status code shows success
      --strict          Exit non-zero for improperly formatted checksum lines
  -w, --warn            Warn about improperly formatted checksum lines
  -q, --quiet           Don't print OK

  -h, --help            Show this help
      --version         Show version
EOF
}

# cli::parse_args
cli::parse_args() {
  # Reset globals
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
    echo "Error: Missing arguments."
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
    -h | --help)
      cli::print_usage
      exit "$EX_SUCCESS"
      ;;
    --version)
      echo "checkit v0.8.0"
      exit "$EX_SUCCESS"
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

  # Mode Inference Logic
  if [[ "$__CLI_MODE" == "check" ]]; then
    if [[ ${#__CLI_FILES[@]} -eq 0 ]]; then
      echo "Error: Missing sumfile argument for check mode."
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
    echo "Error: Ambiguous arguments. Use -c for check mode."
    return "$EX_OPERATIONAL_ERROR"
    ;;
  esac

  return "$EX_SUCCESS"
}
