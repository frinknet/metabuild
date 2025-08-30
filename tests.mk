# Test targets with pattern matching
test:
	@echo "Running all tests..."
	@for type in $$(find $(TESTDIR) -maxdepth 1 -type d -not -path $(TESTDIR) -printf "%f\n" 2>/dev/null || true); do \
		$(MAKE) test-each TYPE=$$type; \
	done

# Pattern: (TYPE)-test - runs all tests of a specific type
%-test:
	@$(eval TYPE := $*)
	@test -d "$(TESTDIR)/$(TYPE)" || (echo "Test type '$(TYPE)' not found in $(TESTDIR)/"; exit 1)
	@echo "Running $(TYPE) tests..."
	@for test in $$(find $(TESTDIR)/$(TYPE) -name "*.c" -printf "%f\n" 2>/dev/null | sed 's/\.c$$//'); do \
		$(MAKE) test-only TYPE=$(TYPE) TEST=$$test; \
	done

# Pattern: (TYPE)-test-(TEST) - runs specific test
%-test-%:
	@$(eval PARTS := $(subst -, ,$*))
	@$(eval TYPE := $(word 1, $(PARTS)))
	@$(eval TEST := $(word 3, $(PARTS)))
	@$(MAKE) test-only TYPE=$(TYPE) TEST=$(TEST)

# Run all test for type
test-each:
	@test -n "$(TYPE)" || (echo "TYPE not specified"; exit 1)
	@test -d "$(TESTDIR)/$(TYPE)" || (echo "Test type $(TYPE) not found"; exit 1)
	@echo "Running $(TYPE) tests..."
	@for test in $$(find $(TESTDIR)/$(TYPE) -name "*.c" -printf "%f\n" 2>/dev/null | sed 's/\.c$$//'); do \
		$(MAKE) test-line TYPE=$(TYPE) TEST=$$test; \
	done

# Run a single test
test-only:
	@test -n "$(TYPE)" || (echo "TYPE not specified"; exit 1)
	@test -n "$(TEST)" || (echo "TEST not specified"; exit 1)
	@test -f "$(TESTDIR)/$(TYPE)/$(TEST).c" || (echo "Test $(TESTDIR)/$(TYPE)/$(TEST).c not found"; exit 1)
	@echo "→ Running $(TYPE)/$(TEST)"
	@mkdir -p $(OUTDIR)/test
	@$(CC) $(CFLAGS) -I$(TESTDIR) $(TESTDIR)/$(TYPE)/$(TEST).c -o $(OUTDIR)/test/$(TYPE)-$(TEST) $(LDFLAGS)
	@$(OUTDIR)/test/$(TYPE)-$(TEST)

# Single line response
test-line:
	@printf "Testing [$(TEST)]..."
	@if $(MAKE) test-only TYPE=$(TYPE) TEST=$(TEST) 2>&1 >/dev/null; then \
		printf "\r%-30s ✓ passed\n" "$(TEST)"; \
	else \
		printf "\r%-30s ✗ failed\n" "$(TEST)"; \
		exit 1; \
	fi

# Suppress pattern matching for test targets  
ifneq (,$(filter %-test %-test-%, $(MAKECMDGOALS)))
%:
	@:
endif

.PHONY: test test-each test-line test-only
