# testing.mk - (c) 2025 FRINKnet & Friends - 0BSD

# Portability detection
TEST_PARALLEL := $(shell nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4)
TEST_TIMER := $(shell which gtime 2>/dev/null || which time 2>/dev/null || echo time)
TEST_PERF := $(shell which perf 2>/dev/null || echo)
TEST_SOURCES := $(shell find $(CHKDIR) -maxdepth 1 -type f -name "*.c" 2>/dev/null)
TEST_OBJECTS := $(TEST_SOURCES:$(CHKDIR)/%.c=$(OUTDIR)/test/%.o)

$(OUTDIR)/test/%.o: $(CHKDIR)/%.c | $(OUTDIR)/test/
	@echo "Building test infrastructure: $*"
	@$(CC) $(CFLAGS) -I$(CHKDIR) -c $< -o $@

# Testing info
test-info:
	@$(if $(TEST_TYPES),echo -e "\n=== AVAILABLE TESTS ===";)
	@$(foreach type,$(TEST_TYPES),\
		$(eval TESTS := $(shell find $(CHKDIR)/$(type) -maxdepth 1 -name "*.c" -exec basename {} .c \; | sort | awk '{print (NR==1?"":"• ")"$(type)-test-"$$0}'))\
		$(if $(TESTS),echo -e "\n$(type)-tests → $(TESTS)";))

# Testing usage
test-usage:
	@echo "  TESTING:"
	@echo
	@echo "    test             Run all tests"
	#todo show different types of tests
	#echo "    xxxx-test        Run xxx tests"
	#echo "    xxxx-test-[name] Run xxx tests"
	@echo "    tests            Show list of tests"
	@echo

# Testing missing
test-missing:
	@echo "  Template not found."

# List tests
tests: respond test-info

# Test targets with pattern matching
test:
	@echo "Running all tests..."
	@for type in $$(find $(CHKDIR) -maxdepth 1 -type d -not -path $(CHKDIR) -exec basename {} \; 2>/dev/null || true); do \
		$(MAKE) -s test-each TYPE=$$type; \
	done

# Pattern: (TYPE)-test - runs all tests of a specific type
%-test:
	@$(eval TYPE := $*)
	@test -d "$(CHKDIR)/$(TYPE)" || (echo "Test type '$(TYPE)' not found in $(CHKDIR)/"; exit 1)
	@echo "Running $(TYPE) tests..."
	@for test in $$(find "$(CHKDIR)/$(TYPE)" -name "*.c" -exec basename {} .c \;); do \
		$(MAKE) -s test-only TYPE=$(TYPE) TEST=$$test; \
	done

# Dynmic test type discovery
TEST_TYPES := $(shell [ -d "$(CHKDIR)" ] && \
  find "$(CHKDIR)" -maxdepth 1 -type d -not -path "$(CHKDIR)" \
  -exec basename {} \; 2>/dev/null | sort || true)

# Generate ALL pattern rules for each test type
define MAKE_TEST_PATTERNS
$(1)-test-%:
	@$$(MAKE) -s test-only TYPE=$(1) TEST=$$*

$(1)-memory-%:
	@echo "memory profiling $(1)/$$*..."
	@mkdir -p $$(outdir)/test
	@$$(cc) $$(cflags) -fsanitize=address -i$$(testdir) $$(testdir)/$(1)/$$*.c $$(test_objects) $$(filter %.a,$$(libs)) -o $$(outdir)/test/$(1)-$$*-mem $$(ldflags)
	@$$(outdir)/test/$(1)-$$*-mem 2>&1 | grep -e "(error|summary|leaked)" || echo "no memory issues detected"

$(1)-timing-%:
	@printf "Timing $(1)/$$*: "
	@$$(TEST_TIMER) $$(MAKE) -s test-line TYPE=$(1) TEST=$$*  | \
		grep -E "(User time|System time|Elapsed|resident)" || true

$(1)-profile-%:
	@echo "Profiling $(1)/$$*..."
	@$$(TEST_PERF) $$(MAKE) -s test-line TYPE=$(1) TEST=$$*
endef

# Generate all patterns for each discovered test type
$(foreach type,$(TEST_TYPES),$(eval $(call MAKE_TEST_PATTERNS,$(type))))

# Run a single test
test-only: $(LIBDIR)/$(call CLEAN_LIBNAME,$(firstword $(LIBDIRS)))
	@test -n "$(TYPE)" || (echo "TYPE not specified"; exit 1)
	@test -n "$(TEST)" || (echo "TEST not specified"; exit 1)
	@test -f "$(CHKDIR)/$(TYPE)/$(TEST).c" || (echo "Test $(CHKDIR)/$(TYPE)/$(TEST).c not found"; exit 1)
	@mkdir -p $(OUTDIR)/test
	@$(CC) $(CFLAGS) -I$(CHKDIR) $(CHKDIR)/$(TYPE)/$(TEST).c $(TEST_OBJECTS) \
		$(LIBDIR)/$(call CLEAN_LIBNAME,$(firstword $(LIBDIRS))) \
		-o $(OUTDIR)/test/$(TYPE)-$(TEST) $(LDFLAGS)
	@$(OUTDIR)/test/$(TYPE)-$(TEST)


# Single line response with status
test-line:
	@printf "Testing [$(TEST)]..."
	@if $(MAKE) -s test-only TYPE=$(TYPE) TEST=$(TEST) >/dev/null 2>&1; then \
		printf "\r%-30s ✓ passed\n" "$(TEST)"; \
	else \
		printf "\r%-30s ✗ failed\n" "$(TEST)"; \
		exit 1; \
	fi

# Run all tests for type
test-each:
	@test -n "$(TYPE)" || (echo "TYPE not specified"; exit 1)
	@test -d "$(CHKDIR)/$(TYPE)" || (echo "Test type $(TYPE) not found"; exit 1)
	@echo "Running $(TYPE) tests..."
	@for test in $$(find $(CHKDIR)/$(TYPE) -name "*.c" -exec basename {} .c \;); do \
		$(MAKE) -s test-line TYPE=$(TYPE) TEST=$$test; \
	done

# Profile test suite performance
test-timing:
	@echo "Timing test suite..."
	@printf "Timing $(1)/$$*: "
	@$(TEST_TIMER) $(MAKE) -s test 2>&1 | \
		grep -E "(User time|System time|Elapsed.*real|Maximum resident set size)"

# Profile test suite performance
test-profile:
	@echo "Profiling test suite..."
	@$(TEST_PERF) $(MAKE) -s test

# Suppress pattern matching for test targets
ifneq (,$(filter %-test %-test-% %-memory-% %-timing-% %-profile-%, $(MAKECMDGOALS)))
%:
	@:
endif

.PHONY: test test-each test-line test-only test-profile test-timing test-bench test-memory
