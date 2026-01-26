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
	find lib -name "*.bash" -exec shellcheck {} +

# Run Tests
test:
	@echo "Running test suite..."
	@$(BATS_BIN) --recursive tests/unit tests/integration

