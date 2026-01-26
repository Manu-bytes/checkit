#!/usr/bin/env bats

load '../test_helper'

# Carga (mock) del módulo bajo prueba
# Nota: Como estamos en TDD, el archivo lib/core/algorithm_chooser.bash
# aún no existe o está vacío, por lo que sourcearlo ahora fallará o no hará nada
# hasta que lo creemos. Para este test inicial, definiremos el path.
setup() {
  # Path to the unit under test
  source "$PROJECT_ROOT/lib/constants.sh"
  source "$PROJECT_ROOT/lib/core/algorithm_chooser.sh"
}

@test "Core: identify_algorithm detects SHA-256 by length (64 chars)" {
  # Simulación de un hash SHA-256 válido
  local input_hash="e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"

  run core::identify_algorithm "$input_hash"

  assert_success
  assert_output "sha256"
}

@test "Core: identify_algorithm detects MD5 by length (32 chars)" {
  local input_hash="d41d8cd98f00b204e9800998ecf8427e"

  run core::identify_algorithm "$input_hash"

  assert_success
  assert_output "md5"
}

@test "Core: identify_algorithm returns error on invalid length" {
  local input_hash="12345" # Too short

  run core::identify_algorithm "$input_hash"

  assert_failure "$EX_OPERATIONAL_ERROR"
}
