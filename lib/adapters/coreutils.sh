#!/usr/bin/env bash

# coreutils::verify
#
# Verifies the integrity of a file using standard GNU Coreutils tools (md5sum, sha1sum, etc.).
#
# Arguments:
#   $1 - Algorithm (e.g., sha256, md5)
#   $2 - Path to the file
#   $3 - Expected hash
#
# Returns:
#   EX_SUCCESS (0) - Verification successful
#   EX_INTEGRITY_FAIL (1) - Hash does not match
#   EX_OPERATIONAL_ERROR (2) - File not found or system error

coreutils::verify() {
  local algo="$1"
  local file="$2"
  local expected_hash="$3"

  #1. Prior validation of the file
  if [[ ! -f "$file" ]]; then
    return "$EX_OPERATIONAL_ERROR"
  fi

  # 2. Build command name (e.g., sha256sum)
  local cmd="${algo}sum"

  # 3. Run verification
  # Standard format: “HASH  FILE_NAME”
  # -c : Check
  # -  : Read from STDIN
  # We redirect output to null to keep the tool silent except for errors
  if echo "${expected_hash}  ${file}" | "$cmd" -c - >/dev/null 2>&1; then
    return "$EX_SUCCESS"
  else
    return "$EX_INTEGRITY_FAIL"
  fi
}

# coreutils::check_list
# Checks a list of checksums from an existing file.
#
# Arguments:
#   $1 - Algorithm (sha256, md5, etc.)
#   $2 - Path to the checksum file (.txt, .md5, etc.)
coreutils::check_list() {
  local algo="$1"
  local sumfile="$2"
  local cmd="${algo}sum"

  if [[ ! -f "$sumfile" ]]; then
    return "$EX_OPERATIONAL_ERROR"
  fi

  # Run: sha256sum -c sumfile.txt
  # We redirect stderr and stdout to null so we can handle the output ourselves,
  # unless we want to see the native output.
  # For consistency with verify_string, we silence it and use the exit code.
  if "$cmd" -c "$sumfile" >/dev/null 2>&1; then
    return "$EX_SUCCESS"
  else
    return "$EX_INTEGRITY_FAIL"
  fi
}

# coreutils::calculate
# Calculates the hash of a file.
#
# Arguments:
#   $1 - Algorithm (sha256, md5, etc.)
#   $2 - Path to the file
#
# Returns:
#   Output: “HASH FILENAME” (GNU standard)
#   Exit Code: EX_SUCCESS or error.
coreutils::calculate() {
  local algo="$1"
  local file="$2"
  local cmd="${algo}sum"

  if [[ ! -f "$file" ]]; then
    return "$EX_OPERATIONAL_ERROR"
  fi

  # We execute the command.
  # We do not silence stdout because we want the user to see the hash.
  if "$cmd" "$file"; then
    return "$EX_SUCCESS"
  else
    return "$EX_OPERATIONAL_ERROR"
  fi
}
