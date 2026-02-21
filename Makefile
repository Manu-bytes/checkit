# Makefile
.PHONY: test unit-test integration-test lint clean build install test-perl test-dist test-all

# Configurations
BATS_BIN := bats
BATS_FLAGS := --recursive
HAS_COREUTILS := $(shell command -v sha256sum 2> /dev/null)
HAS_PERL_SHA  := $(shell command -v shasum 2> /dev/null)
TYPE_TEST ?= navite

ifeq ($(TYPE_TEST),perl)
	TEST_MSG := "✅ shasum (Perl) Test Suite completed."
else ifeq ($(TYPE_TEST),dist-auto)
	TEST_MSG := "✅ Standalone Binary (Auto-Detect) Test Suite completed."
else ifeq ($(TYPE_TEST),dist-perl)
	TEST_MSG := "✅ Standalone Binary (Forced Perl) Test Suite completed."
else
	TEST_MSG := "✅ Native Test Suite completed."
endif

# Linting with Shellcheck
lint:
	@echo "🔍 Running Shellcheck..."
	# Check the main binary
	shellcheck -x bin/checkit
	# Check all library files in src
	find lib -name "*.sh" -exec shellcheck {} +

# Run Tests
unit-test:
	@echo "🧪 Running Unit Tests..."
	@CHECKIT_MODE=ascii $(BATS_BIN) $(BATS_FLAGS) tests/unit

integration-test:
	@echo "🔗 Running Integration Tests..."
	@CHECKIT_MODE=ascii $(BATS_BIN) $(BATS_FLAGS) tests/integration

test: unit-test integration-test
	@echo $(TEST_MSG)

test-perl:
ifneq ($(HAS_PERL_SHA),)
	@echo "--------------------------------------------------"
	@echo "🐫 Running Tests in Forced Perl Mode (shasum)..."
	@echo "--------------------------------------------------"
	@CHECKIT_FORCE_PERL=true $(MAKE) --no-print-directory test TYPE_TEST=perl
else
	@echo "⚠️  Skipping Perl Test: 'shasum' not found on this system."
endif

test-dist: build
	@echo "--------------------------------------------------"
	@echo "📦 [1/2] Testing Binary in (Auto-Detect Mode)..."
	@echo "--------------------------------------------------"
	@USE_DIST=true $(MAKE) --no-print-directory test TYPE_TEST=dist-auto
	@echo ""
ifneq ($(HAS_PERL_SHA),)
	@echo "--------------------------------------------------"
	@echo "📦 [2/2] Testing Binary in PERL mode..."
	@echo "--------------------------------------------------"
	@USE_DIST=true CHECKIT_FORCE_PERL=true $(MAKE) --no-print-directory test TYPE_TEST=dist-perl
else
	@echo "⚠️  Skipping Forced Perl Test: 'shasum' not found on this system."
endif
	@echo ""
	@echo "🏆 DISTRIBUTABLE BINARY PASSED ALL CHECKS."

# Run All Test
test-all:
	@$(MAKE) --no-print-directory test
	@$(MAKE) --no-print-directory test-perl
	@echo ""
	@echo "🏅 ALL TEST SUITES PASSED (Native & Perl) 🏅"

# Clean build artifacts
clean:
	@echo "🧹 Cleaning up..."
	@rm -f dist/checkit > /dev/null 2>&1

# Build standalone binary
build: clean
	@./build.sh

# Install to system
install:
	@if [ ! -f dist/checkit ]; then \
		echo -e "❌ \033[1;31mError: Compiled binary 'dist/checkit' not found.\033[0m"; \
		echo "⚠️ Not compiled automatically during install for security reasons."; \
		echo ""; \
		echo "💡 Run one of the following steps first:"; \
		echo -e "   \033[1;33mmake build\033[0m      -> Build only."; \
		echo -e "   \033[1;33mmake test-dist\033[0m  -> Build and verify (recommended)."; \
		echo ""; \
		exit 1; \
	fi
	@echo "📦 # Installing checkit into /usr/local/bin..."
	@sudo install -m 755 dist/checkit /usr/local/bin/checkit
	@echo "✅ Installation completed successfully."
