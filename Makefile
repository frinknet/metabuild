# METABUILD - (c) 2025 FRINKnet & Friends - 0BSD
VPATH = $(CURDIR):$(CURDIR)/.metabuild:.

# Project configuration
PRJ ?= $(shell basename $(CURDIR))
VER := $(shell git describe --tags --abbrev=0 2>/dev/null || git rev-parse --abbrev-ref HEAD 2>/dev/null || echo dev)

# Directory structure
LIBDIR	 := lib
SYSDIR	 := sys
INCDIR	 := inc
TPLDIR	 := tpl
SRCDIR	 := src
DOCDIR	 := doc
WEBDIR	 := web
OUTDIR	 := out/$(TARGET)
OBJDIR	 := $(OUTDIR)/obj
LIBOUTDIR := $(OUTDIR)/lib
BINDIR	 := $(OUTDIR)/bin
TESTDIR	 := test
UNITDIR	 := $(TESTDIR)/unit
CASEDIR	 := $(TESTDIR)/case
LOADDIR := $(TESTDIR)/load

# Compiler flags using the directory structure
CFLAGS	 += -isystem $(SYSDIR) -I$(INCDIR) -I$(LIBDIR)
CXXFLAGS += -isystem $(SYSDIR) -I$(INCDIR) -I$(LIBDIR)

# Find all source files (recursively in src/)
SRCS := $(shell find $(SRCDIR) -name '*.c' -o -name '*.cpp' -o -name '*.cc')
OBJS := $(SRCS:$(SRCDIR)/%=$(OBJDIR)/%.o)
DEPS := $(OBJS:.o=.d)

# Makefile extensions
MKEX := $(CURDIR)/.metabuild/metabuild.mk
MKFS := $(filter-out $(MKEX),$(wildcard $(CURDIR)/.metabuild/*.mk))

# Library sources (separate from main sources)
LIBSRCS  := $(shell find $(LIBDIR) -name '*.c' -o -name '*.cpp' -o -name '*.cc')
LIBOBJS  := $(LIBSRCS:$(LIBDIR)/%=$(OBJDIR)/lib/%.o)

include metabuild.mk

# Default target
.DEFAULT_GOAL := all

include $(MKFS)

# Initialize submodules
submodules:
	@git submodule update --init --depth=1

# Extract positional arguments (new [tpl] [name])
new:
	@$(eval tpl := $(word 2, $(MAKECMDGOALS)))
	@$(eval name := $(word 3, $(MAKECMDGOALS)))
	@test -n "$(tpl)" || (echo "Usage: make new [template] [name]"; exit 1)
	@test -n "$(name)" || (echo "Usage: make new [template] [name]"; exit 1)  
	@test -d "$(TPLDIR)/$(tpl)" || (echo "Template $(tpl) not found"; exit 1)
	@mkdir -p "$(SRCDIR)/$(name)"
	@cp -r "$(TPLDIR)/$(tpl)"/* "$(SRCDIR)/$(name)/"
	@echo "Created $(SRCDIR)/$(name) from template $(tpl)"

# Suppress unknown targets when using 'new' command
ifeq ($(word 1, $(MAKECMDGOALS)),new)
%:
	@:
endif

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

# discover “apps” (src/foo/, src/bar/, …)
APPS := $(shell find $(SRCDIR) -mindepth 1 -maxdepth 1 -type d -printf '%f ')

# every binary lives in out/<target>/bin/<app>
BINS := $(addprefix $(BINDIR)/,$(APPS))
all: $(BINS)

# pattern-generate compile & link rules per app
define MAKE_APP
# objects for $$1
$$(OBJDIR)/$$1/%.o: $(SRCDIR)/$$1/%.c | $$(OBJDIR)/$$1
	@echo GEN $@
	$$(CC) $$(CFLAGS) -MMD -MP -c $$< -o $$@

# link $$1 → bin
$(BINDIR)/$$1: $$(patsubst $(SRCDIR)/$$1/%.c,$$(OBJDIR)/$$1/%.o,$$(wildcard $(SRCDIR)/$$1/*.c)) | $(BINDIR)
	@echo GEN $@
	$$(CC) $$^ -o $$@ $$(LDFLAGS)
endef
$(foreach a,$(APPS),$(eval $(call MAKE_APP,$a)))

# Create output directories
$(OBJDIR) $(LIBOUTDIR) $(BINDIR): $(SRCDIR)
	@mkdir -p $@

# Compile source files to objects  
$(OBJDIR)/%.c.o: $(SRCDIR)/%.c | $(OBJDIR)
	@mkdir -p $(dir $@)
	@echo GEN $@
	@$(CC) $(CFLAGS) -MMD -MP -c $< -o $@

$(OBJDIR)/%.cpp.o: $(SRCDIR)/%.cpp | $(OBJDIR)	
	@mkdir -p $(dir $@)
	@echo GEN $@
	@$(CXX) $(CXXFLAGS) -MMD -MP -c $< -o $@

$(OBJDIR)/%.cc.o: $(SRCDIR)/%.cc | $(OBJDIR)
	@mkdir -p $(dir $@)
	@echo GEN $@
	@$(CXX) $(CXXFLAGS) -MMD -MP -c $< -o $@

# Compile library files
$(OBJDIR)/lib/%.c.o: $(LIBDIR)/%.c | $(OBJDIR)
	@mkdir -p $(dir $@)  
	@echo GEN $@
	@$(CC) $(CFLAGS) -MMD -MP -c $< -o $@

$(OBJDIR)/lib/%.cpp.o: $(LIBDIR)/%.cpp | $(OBJDIR)
	@mkdir -p $(dir $@)
	@echo GEN $@
	@$(CXX) $(CXXFLAGS) -MMD -MP -c $< -o $@

# Create static library
$(LIBOUTDIR)/lib$(PRJ).a: $(LIBOBJS) | $(LIBOUTDIR)
	@echo GEN $@
	@$(AR) rcs $@ $^

template-list:
	@find $(TPLDIR) -maxdepth 1 -type d -not -path $(TPLDIR) -printf "	%f\n" 2>/dev/null || true

clean:
	@rm -rf $(OUTDIR)

.PHONY: all lib clean new submodule template-list
.PHONY: test test-each test-line test-only

# Include dependency files
-include $(DEPS)
