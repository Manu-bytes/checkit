# Makefile
.PHONY: test

# Path to the BATS executable (adjust if it is in another submodule folder)
BATS_BIN := bats

# Linting with Shellcheck
lint:
	@echo "Running Shellcheck..."
	# Check the main binary
	shellcheck -x bin/checkit
	# Check all library files in src
	find lib -name "*.sh" -exec shellcheck {} +

# Run Tests
unit-test:
	@echo "Running Unit Tests..."
	@$(BATS_BIN) --recursive tests/unit

integration-test:
	@echo "Running Integration Tests..."
	@$(BATS_BIN) --recursive tests/integration

test: unit-test integration-test
	@echo "Test suite completed"

