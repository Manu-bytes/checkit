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
