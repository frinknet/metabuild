# tests.mk - (c) 2025 FRINKnet & Friends - 0BSD

# Portability detection
TEST_PARALLEL := $(shell nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4)
TEST_TIMER := $(shell which gtime 2>/dev/null || which time 2>/dev/null || echo time)
TEST_SOURCES := $(shell find $(TESTDIR) -maxdepth 1 -type f -name "*.c" 2>/dev/null)
TEST_OBJECTS := $(TEST_SOURCES:$(TESTDIR)/%.c=$(OUTDIR)/test/%.o)

$(OUTDIR)/test/%.o: $(TESTDIR)/%.c | $(OUTDIR)/test/
	@echo "Building test infrastructure: $*"
	@$(CC) $(CFLAGS) -I$(TESTDIR) -c $< -o $@

# Test targets with pattern matching
test:
	@echo "Running all tests..."
	@for type in $$(find $(TESTDIR) -maxdepth 1 -type d -not -path $(TESTDIR) -exec basename {} \; 2>/dev/null || true); do \
		$(MAKE) test-each TYPE=$$type; \
	done

# Pattern: (TYPE)-test - runs all tests of a specific type
%-test:
	@$(eval TYPE := $*)
	@test -d "$(TESTDIR)/$(TYPE)" || (echo "Test type '$(TYPE)' not found in $(TESTDIR)/"; exit 1)
	@echo "Running $(TYPE) tests..."
	@for test in $$(find $(TESTDIR)/$(TYPE) -name "*.c" -exec basename {} .c \;); do \
		$(MAKE) test-only TYPE=$(TYPE) TEST=$$test; \
	done

# Pattern: (TYPE)-test-(TEST) - runs specific test
%-test-%:
	@$(eval PARTS := $*)
	@$(eval TYPE := $(word 1,$(subst -, ,$(PARTS))))
	@$(eval TEST := $(subst $(TYPE)-test-,,$(PARTS)))
	@$(MAKE) test-only TYPE=$(TYPE) TEST=$(TEST)

# Pattern: (TYPE)-memory-(TEST) - memory profile specific test
%-memory-%:
	@$(eval PARTS := $(subst -, ,$*))
	@$(eval TYPE := $(word 1,$(subst -, ,$(PARTS))))
	@$(eval TEST := $(subst $(TYPE)-memory-,,$(PARTS)))
	@echo "Memory profiling $(TYPE)/$(TEST)..."
	@mkdir -p $(OUTDIR)/test
	@$(CC) $(CFLAGS) -fsanitize=address -I$(TESTDIR) $(TESTDIR)/$(TYPE)/$(TEST).c $(TEST_OBJECTS) $(filter %.a,$(LIBS)) -o $(OUTDIR)/test/$(TYPE)-$(TEST)-mem $(LDFLAGS)
	@$(OUTDIR)/test/$(TYPE)-$(TEST)-mem 2>&1 | grep -E "(ERROR|SUMMARY|leaked)" || echo "No memory issues detected"

# Pattern: (TYPE)-timing-(TEST) - time specific test
%-timing-%:
	@$(eval PARTS := $(subst -, ,$*))
	@$(eval TYPE := $(word 1,$(subst -, ,$(PARTS))))
	@$(eval TEST := $(subst $(TYPE)-timing-,,$(PARTS)))
	@printf "Timing $(TYPE)/$(TEST): "
	@$(TEST_TIMER) $(MAKE) test-only TYPE=$(TYPE) TEST=$(TEST) 2>&1 | tail -1

# Pattern: (TYPE)-profile-(TEST) - full profile specific test
%-profile-%:
	@$(eval PARTS := $(subst -, ,$*))
	@$(eval TYPE := $(word 1,$(subst -, ,$(PARTS))))
	@$(eval TEST := $(subst $(TYPE)-profile-,,$(PARTS)))
	@echo "Profiling $(TYPE)/$(TEST)..."
	@$(TEST_TIMER) $(MAKE) test-only TYPE=$(TYPE) TEST=$(TEST) 2>&1 | \
		grep -E "(User time|System time|Elapsed.*real|Maximum resident set size)"

# Run all tests for type
test-each:
	@test -n "$(TYPE)" || (echo "TYPE not specified"; exit 1)
	@test -d "$(TESTDIR)/$(TYPE)" || (echo "Test type $(TYPE) not found"; exit 1)
	@echo "Running $(TYPE) tests..."
	@for test in $$(find $(TESTDIR)/$(TYPE) -name "*.c" -exec basename {} .c \;); do \
		$(MAKE) test-line TYPE=$(TYPE) TEST=$$test; \
	done

# Run a single test
test-only:
	@test -n "$(TYPE)" || (echo "TYPE not specified"; exit 1)
	@test -n "$(TEST)" || (echo "TEST not specified"; exit 1)
	@test -f "$(TESTDIR)/$(TYPE)/$(TEST).c" || (echo "Test $(TESTDIR)/$(TYPE)/$(TEST).c not found"; exit 1)
	@echo "→ Running $(TYPE)/$(TEST)"
	@mkdir -p $(OUTDIR)/test
	@$(CC) $(CFLAGS) -I$(TESTDIR) $(TESTDIR)/$(TYPE)/$(TEST).c $(TEST_OBJECTS) $(filter %.a,$(LIBS)) -o $(OUTDIR)/test/$(TYPE)-$(TEST) $(LDFLAGS)
	@$(OUTDIR)/test/$(TYPE)-$(TEST)

# Single line response with status
test-line:
	@printf "Testing [$(TEST)]..."
	@if $(MAKE) test-only TYPE=$(TYPE) TEST=$(TEST) 2>&1 >/dev/null; then \
		printf "\r%-30s ✓ passed\n" "$(TEST)"; \
	else \
		printf "\r%-30s ✗ failed\n" "$(TEST)"; \
		exit 1; \
	fi

# Helper target for parallel execution
test-single:
	@$(eval TYPE := $(if $(TEST_PATH),$(patsubst %/,%,$(dir $(TEST_PATH))),.))
	@$(eval TEST := $(if $(TEST_PATH),$(notdir $(TEST_PATH)),))
	@$(MAKE) test-line TYPE=$(TYPE) TEST=$(TEST)

# Parallel test execution
test-parallel:
	@echo "Running tests in parallel ($(TEST_PARALLEL) cores)..."

	@find $(TESTDIR) -name "*.c" -exec sh -c 'echo "$${1%/*}/$$(basename $$1 .c)"' _ {} \; | \
		sed 's|$(TESTDIR)/||' | sed 's|/|-|' | sed 's|^|test-|' | \
		xargs -P$(TEST_PARALLEL) -I{} $(MAKE) {} 2>/dev/null || true

# List available tests
test-list:
	@echo "Available tests:"
	@find $(TESTDIR) -name "*.c" | sed 's|$(TESTDIR)/||; s|\.c$$||' | sort

# Profile test suite performance
test-profile:
	@echo "Profiling test suite..."
	@$(TEST_TIMER) $(MAKE) test 2>&1 | \
		grep -E "(User time|System time|Elapsed.*real|Maximum resident set size)"

# Suppress pattern matching for test targets
ifneq (,$(filter %-test %-test-% %-memory-% %-timing-% %-profile-%, $(MAKECMDGOALS)))
%:
	@:
endif

.PHONY: test test-each test-line test-only test-single test-parallel test-profile test-timing test-bench test-memory
