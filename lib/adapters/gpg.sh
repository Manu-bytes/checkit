#!/usr/bin/env bash
#
# lib/adapters/gpg.sh
# GPG Adapter: Wrapper for GnuPG operations.
#
# Responsibility: Handle cryptographic signing and verification of files
# and data streams, abstracting the complexity of the 'gpg' binary.

# ----------------------------------------------------------------------
# Internal Helper Functions
# ----------------------------------------------------------------------

# Internal: Locates a detached signature file for a given target.
# Checks for standard extensions (.asc, .sig, .gpg) in order of preference.
#
# $1 - file - The path to the target file.
#
# Returns the path to the signature file to stdout, or returns 1 if not found.
gpg::find_detached_sig() {
  local file="$1"
  local ext

  for ext in ".asc" ".sig" ".gpg"; do
    if [[ -f "${file}${ext}" ]]; then
      echo "${file}${ext}"
      return 0
    fi
  done
  return 1
}

# ----------------------------------------------------------------------
# Public Functions
# ----------------------------------------------------------------------

# Public: Detects if a file contains a PGP signature.
# Checks for both inline clear-signed headers and the presence of detached
# signature files.
#
# $1 - file - The path to the file to inspect.
#
# Returns 0 if a signature is detected, 1 otherwise.
gpg::detect_signature() {
  local file="$1"

  # Check 1: Inline Clear-Sign header detection
  if grep -q "^-----BEGIN PGP SIGNED MESSAGE-----" "$file" 2>/dev/null; then
    return 0
  fi

  # Check 2: Detached signature presence
  if gpg::find_detached_sig "$file" >/dev/null; then
    return 0
  fi

  return 1
}

# Public: Verifies the signature of a SUMFILE (List).
# This is used for the main list verification (checkit -c list.txt).
# Returns the output on failure for logging.
#
# $1 - file - The path to the file to verify.
#
# Returns EX_SUCCESS, EX_SECURITY_FAIL, or EX_OPERATIONAL_ERROR.
gpg::verify() {
  local file="$1"
  local output
  local status

  # 1. Determine Verification Mode
  local detached_sig
  detached_sig=$(gpg::find_detached_sig "$file")

  # 2. Execute GPG
  if [[ -n "$detached_sig" ]]; then
    # Mode: Detached (gpg --verify SIG DATA)
    output=$(gpg --verify "$detached_sig" "$file" 2>&1)
    status=$?
  else
    # Mode: Inline (gpg --verify FILE)
    output=$(gpg --verify "$file" 2>&1)
    status=$?
  fi

  # 3. Status Analysis Logic
  if [[ "$status" -eq 0 ]]; then
    return "$EX_SUCCESS"
  fi

  # 4. Error Parsing
  local output_lower="${output,,}"

  if [[ "$output_lower" =~ "bad signature" ]]; then
    echo "$output"
    return "$EX_SECURITY_FAIL"
  fi

  if [[ "$output_lower" =~ "no public key" || "$output_lower" =~ "public key not found" ]]; then
    echo "$output"
    return "$EX_OPERATIONAL_ERROR"
  fi

  # Generic error fallback
  echo "$output"
  return "$EX_OPERATIONAL_ERROR"
}

# Public: Verifies a detached signature for a TARGET file (e.g. image.iso).
#
# $1 - file - The path to the data file.
#
# Returns:
#   EX_SUCCESS (0)          - Signature Good
#   EX_SECURITY_FAIL (3)    - Signature BAD (Tampered)
#   EX_OPERATIONAL_ERROR (2)- Missing Key / No Sig / GPG Error
gpg::verify_detached() {
  local file="$1"
  local sig_file

  sig_file=$(gpg::find_detached_sig "$file")

  if [[ -z "$sig_file" ]]; then
    return "$EX_OPERATIONAL_ERROR" # No signature found
  fi

  local output
  output=$(gpg --verify "$sig_file" "$file" 2>&1)
  local status=$?

  if [[ "$status" -eq 0 ]]; then
    return "$EX_SUCCESS"
  else
    local output_lower="${output,,}"

    # 1. Detect Explicit Bad Signature
    if [[ "$output_lower" =~ "bad signature" ]]; then
      echo "$output"
      return "$EX_SECURITY_FAIL"
    fi

    # 2. Detect Missing Key (Common operational error)
    if [[ "$output_lower" =~ "no public key" || "$output_lower" =~ "public key not found" ]]; then
      echo "$output"
      return "$EX_OPERATIONAL_ERROR"
    fi

    # 3. Detect Corrupted Packets / Other Errors
    echo "$output"
    return "$EX_OPERATIONAL_ERROR"
  fi
}

# Public: Signs data passed via stdin.
#
# $1 - content - The string content to sign.
# $2 - mode    - Signing mode: "detach", "standard", or default (clearsign).
# $3 - armor   - Boolean string ("true"/"false") to enable ASCII armor.
#
# Returns the signed content to stdout.
gpg::sign_data() {
  local content="$1"
  local mode="$2"
  local armor="$3"
  local args=()

  # 1. Determine Mode
  case "$mode" in
  detach)
    args+=("--detach-sign")
    ;;
  standard)
    args+=("--sign")
    ;;
  *)
    # Default: Clearsign
    args+=("--clearsign")
    ;;
  esac

  # 2. Apply Armor
  if [[ "$armor" == "true" ]]; then
    args+=("--armor")
  fi

  echo "$content" | gpg "${args[@]}" -
  return $?
}

# Public: Creates a detached signature for a file on disk.
#
# $1 - file  - The path to the file to sign.
# $2 - armor - Boolean string ("true"/"false") to enable ASCII armor.
#
# Returns EX_SUCCESS on success, EX_OPERATIONAL_ERROR on failure.
gpg::sign_file() {
  local file="$1"
  local armor="$2"

  local args=("--detach-sign")

  if [[ "$armor" == "true" ]]; then
    args+=("--armor")
  fi

  if gpg "${args[@]}" "$file"; then
    return "$EX_SUCCESS"
  else
    return "$EX_OPERATIONAL_ERROR"
  fi
}
