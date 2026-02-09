# testing.mk - (c) 2025 FRINKnet & Friends - 0BSD

# Color definitions
COLOR_HEAD  := \x1b[39m
COLOR_TEST  := \x1b[93m
COLOR_PASS  := \x1b[92m
COLOR_COMP  := \x1b[90m
COLOR_FAIL  := \x1b[31m
COLOR_NORM  := \x1b[0m

# Portability detection
TEST_PARALLEL  := $(shell nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4)
TEST_TIMER     := $(shell which gtime 2>/dev/null || which time 2>/dev/null || echo time)
TEST_PERF      := $(shell which perf 2>/dev/null || echo)
TEST_SOURCES   := $(shell find $(CHKDIR) -maxdepth 1 -type f -name "*.c" 2>/dev/null)
TEST_OBJECTS   := $(TEST_SOURCES:$(CHKDIR)/%.c=$(OUTDIR)/test/%.o)
TEST_FLAGS     := $(foreach w,$(wordlist 2,$(words $(MAKECMDGOALS)),$(MAKECMDGOALS)),--$(w))

# Build a test
define TEST_BUILD
mkdir -p $(OUTDIR)/test; \
if ! $(CC) $(CFLAGS) -I$(CHKDIR) $(CHKDIR)/$(1)/$(2).c $(TEST_OBJECTS) $(firstword $(LIBS)) \
	-o $(OUTDIR)/test/$(1)-$(2) $(LDFLAGS) > /dev/null 2>&1; then \
	status=77; \
else \
	status=0; \
fi
endef

# Run a test
define TEST_RUN
$(call TEST_BUILD,$(1),$(2)); \
if [ $$status -eq 0 ]; then \
	$(OUTDIR)/test/$(1)-$(2) $(TEST_FLAGS) > /dev/null 2>&1; \
	status=$$?; \
fi
endef

# Run a test
define TEST_SHOW
mkdir -p $(OUTDIR)/test && \
$(CC) $(CFLAGS) -I$(CHKDIR) $(CHKDIR)/$(1)/$(2).c $(TEST_OBJECTS) $(firstword $(LIBS)) \
	-o $(OUTDIR)/test/$(1)-$(2) $(LDFLAGS) && \
$(OUTDIR)/test/$(1)-$(2) $(TEST_FLAGS) || true
endef

# Display one test result
define TEST_LINE
$(call TEST_RUN,$(1),$(2)); \
if [ $$status -eq 0 ]; then \
	printf "$(COLOR_PASS)[PASS]$(COLOR_NORM)\n"; \
elif [ $$status -eq 77 ]; then \
	printf "$(COLOR_COMP) ---- $(COLOR_NORM)\n"; \
else \
	printf "$(COLOR_FAIL)[FAIL]$(COLOR_NORM)\n"; \
fi
endef

# Run all tests for a type
define TEST_EACH
printf "\n  $(COLOR_TEST)Running $(1) tests…$(COLOR_NORM)\n\n"; \
printf "  $(COLOR_HEAD)$(1)-test suite - $(1) tests$(COLOR_NORM)\n\n"; \
passed=0; failed=0; errored=0; \
for test in $$(find "$(CHKDIR)/$(1)" -name "*.c" -exec basename {} .c \; | sort); do \
	printf "  $(COLOR_TEST)%-60s$(COLOR_NORM)" "$(1)-test-$$test"; \
	$(call TEST_LINE,$(1),$$test); \
	if [ $$status -eq 0 ]; then \
		passed=`expr $$passed + 1`; \
	elif [ $$status -eq 77 ]; then \
		errored=`expr $$errored + 1`; \
	else \
		failed=`expr $$failed + 1`; \
	fi; \
done; \
total=`expr $$passed + $$failed + $$errored`; \
if [ $$errored -eq 0 ]; then \
	printf "\n$(COLOR_PASS)  🎉 ALL CHECKS PASSED 🎉$(COLOR_NORM)\n"; \
elif [ $$failed -eq 0 ]; then \
	printf "\n$(COLOR_FAIL)  ❌ SOME CHECKS FAILED ❌$(COLOR_NORM)\n"; \
else \
	printf "\n$(COLOR_COMP)  🚨 COMPILER ISSUES!!! 🚨$(COLOR_NORM)\n"; \
fi; \
printf "\n  $(COLOR_TEST)%d total   $(COLOR_PASS)%d passed   $(COLOR_FAIL)%d failed   $(COLOR_COMP)%d errors$(COLOR_NORM)\n\n" \
	$$total $$passed $$failed $$errored
endef

# Generate ALL pattern rules for each test type
define TEST_DEFINE
$(1)-test-%:
	@$$(MAKE) -s test-only TYPE=$(1) TEST=$$* TEST_FLAGS="$(TEST_FLAGS)"

$(1)-memory-%:
	@echo "memory profiling $(1)/$$*..."
	@mkdir -p $$(outdir)/test
	@$$(cc) $$(cflags) -fsanitize=address -i$$(testdir) $$(testdir)/$(1)/$$*.c $$(test_objects) $$(filter %.a,$$(libs)) -o $$(outdir)/test/$(1)-$$*-mem $$(ldflags)
	@$$(outdir)/test/$(1)-$$*-mem 2>&1 | grep -e "(error|summary|leaked)" || echo "no memory issues detected"

$(1)-timing-%:
	@printf "Timing $(1)/$$*: "
	@$$(TEST_TIMER) $$(MAKE) -s test-only TYPE=$(1) TEST=$$*  | \
		grep -E "(User time|System time|Elapsed|resident)" || true

$(1)-profile-%:
	@echo "Profiling $(1)/$$*..."
	@$$(TEST_PERF) $$(MAKE) -s test-only TYPE=$(1) TEST=$$*
endef

# Dynmic test type discovery
TEST_TYPES := $(shell [ -d "$(CHKDIR)" ] && \
  find "$(CHKDIR)" -maxdepth 1 -type d -not -path "$(CHKDIR)" \
  -exec basename {} \; 2>/dev/null | sort || true)

# Recognize test objects
$(OUTDIR)/test/%.o: $(CHKDIR)/%.c | $(OUTDIR)/test/
	@echo "Building test infrastructure: $*"
	@$(CC) $(CFLAGS) -I$(CHKDIR) -c $< -o $@

# Testing info
test-info:
	@$(if $(strip $(CHKDIR)),echo -e "\n=== AVALIABLE TESTS ===\n";)
	@$(if $(strip $(CHKDIR)),echo INCLUDE: $(LIBDIR)/$(call CLEAN_LIBNAME,$(firstword $(LIBDIRS))))
	@$(foreach type,$(TEST_TYPES),\
		$(eval TESTS := $(shell find $(CHKDIR)/$(type) -maxdepth 1 -name "*.c" -exec basename {} .c \; | sort | awk '{print (NR==1?"":"• ")"$(type)-test-"$$0}'))\
		$(if $(TESTS),echo -e "\n$(type)-tests → $(TESTS)";))

# Testing usage
test-usage:
	@echo "  TESTING:"
	@echo
	@echo "    tests            Show list of tests"
	@echo
	@echo "    test             Run all tests"
	@echo "    test-timing      Time all tests"
	@echo "    test-profile     Profile tests"
	@echo
	#todo show different types of tests
	#echo "    xxxx-test        Run xxx tests"
	#echo "    xxxx-test-[name] Run xxx tests"
	@echo

# Testing missing
test-missing: respond
	@echo -e "  WHEN THE TEST IS FOUND!!!\n  That test is missing...\n\n"

# List tests
tests: respond test-info

# Pattern: (TYPE)-test
%-test:
	@if [ -d "$(CHKDIR)/$*" ]; then \
		$(MAKE) -s test-each TYPE=$*; \
	else \
		$(MAKE) -s test-missing; \
	fi

# Generate all patterns for each discovered test type
$(foreach type,$(TEST_TYPES),$(eval $(call TEST_DEFINE,$(type))))

ifeq (%-test-%,$(word 1, $(MAKECMDGOALS)))
%:
	@:
endif

# Test targets with pattern matching
test:
	@echo "Running all tests..."
	@for type in $$(find $(CHKDIR) -maxdepth 1 -type d -not -path $(CHKDIR) -exec basename {} \; 2>/dev/null || true); do \
		$(call TEST_EACH,$$type); \
	done

# Run a single test
test-only: $(firstword $(LIBS))
	@test -n "$(TYPE)" || { echo "TYPE not specified"; exit 1; }
	@test -n "$(TEST)" || { echo "TEST not specified"; exit 1; }
	@if ! test -f "$(CHKDIR)/$(TYPE)/$(TEST).c"; then \
		$(MAKE) -s test-missing; \
		exit 0; \
	fi
	@$(call TEST_SHOW,$(TYPE),$(TEST))

# Run all tests for type
test-each:
	@test -n "$(TYPE)" || { echo "TYPE not specified"; exit 1; }
	@test -d "$(CHKDIR)/$(TYPE)" || { echo "Test type '$(TYPE)' not found"; exit 1; }
	@$(call TEST_EACH,$(TYPE))

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

.PHONY: test test-each test-only test-profile test-timing test-bench test-memory
