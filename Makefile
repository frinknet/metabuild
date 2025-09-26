# METABUILD - (c) 2025 FRINKnet & Friends - 0BSD

# Check for USER metabuild.mk
MKUSER := $(wildcard $(CURDIR)/.metabuild/metabuild.mk)
MKROOT := $(wildcard /metabuild/metabuild.mk)

ifeq ($(MKUSER),)
  MKBUILD := $(MKROOT)
else
  MKBUILD := $(MKUSER)
endif

include $(MKBUILD)

# Project configuration
PRJ ?= $(shell basename $(CURDIR))
VER := $(shell git describe --tags --abbrev=0 2>/dev/null || git rev-parse --abbrev-ref HEAD 2>/dev/null || echo dev)

# Directory structure
EXTDIR	 := lib
SYSDIR	 := syslib
INCDIR	 := include
SRCDIR	 := src
TPLDIR	 := $(SRCDIR)/templates
DOCDIR	 := docs
WEBDIR	 := web

# Output Directories
OUTDIR	 := out$(if $(TARGET),/$(TARGET))
OBJDIR	 := $(OUTDIR)/obj
LIBDIR	 := $(OUTDIR)/lib
BINDIR	 := $(OUTDIR)/bin

# Test directories
TESTDIR	 := tests
UNITDIR	 := $(TESTDIR)/unit
CASEDIR	 := $(TESTDIR)/case
LOADDIR := $(TESTDIR)/load

# Add SYSDIR only if it exists
ifneq ($(wildcard $(SYSDIR)),)
	CFLAGS	 += -isystem $(SYSDIR)
	CXXFLAGS += -isystem $(SYSDIR)
endif

# Compiler flags using the directory structure
CFLAGS	 += -I$(INCDIR) -I$(EXTDIR)
CXXFLAGS += -I$(INCDIR) -I$(EXTDIR)

# Smart detection: add each library subdirectory that contains headers
EXT_HEADER_DIRS = $(shell \
	[ -d "$(EXTDIR)" ] && \
	find "$(EXTDIR)" -mindepth 1 -type d -exec test -e "{}/*.h" \; \
	-print 2>/dev/null)

CFLAGS += $(addprefix -I,$(EXT_HEADER_DIRS))
CXXFLAGS += $(addprefix -I,$(EXT_HEADER_DIRS))

CFLAGS	 += -fPIC -MMD -MP
CXXFLAGS += -fPIC -MMD -MP
LDFLAGS  += -pie
LDLIBS	 ?=

# Function to check if directory contains C++ files
define HAS_CXX
$(shell D="$(if $(filter .,$(1)),$(SRCDIR),$(SRCDIR)/$(1))"; \
	[ -d "$$D" ] && find "$$D" -maxdepth 1 \( -name '*.cpp' -o -name '*.cc' \) 2>/dev/null | wc -l || echo 0)
endef

# Function to check if directory contains main()
define HAS_MAIN
$(shell D="$(if $(filter .,$(1)),.,$(SRCDIR)/$(1))"; \
	[ -d "$$D" ] && find "$$D" -maxdepth 1 \( -name '*.c' -o -name '*.cpp' -o -name '*.cc' \) -exec awk '/int main *\(.*\)/ { if (/\{/ || getline && /^ *\{/) print FILENAME; exit }' {} \; 2>/dev/null | wc -l || echo 0)
endef

# Generate object lists for each directory (preserving structure)
define DEPENDENT_OBJS
  $(shell D="$(if $(filter .,$(1)),.,$(SRCDIR)/$(1))"; \
    [ -d "$$D" ] && find "$$D" -maxdepth 1 -type f \( -name '*.c' -o -name '*.cc' -o -name '*.cpp' \) | \
    sed 's|^$(SRCDIR)/||; s|^\./||; s|^|$(OBJDIR)/|; s|\.c$$|.c.o|; s|\.cc$$|.cc.o|; s|\.cpp$$|.cpp.o|' )
endef

# Function to generate clean target names
define CLEAN_NAME
$(subst /,_,$(1))
endef

# Get all directories containing C files (excluding templates)
SRCDIRS := $(shell \
  if [ -d "$(SRCDIR)" ]; then \
    find "$(SRCDIR)" -type f \( -name '*.c' -o -name '*.cpp' -o -name '*.cc' \) -not -path "$(TPLDIR)/*" -print 2>/dev/null | \
    sed 's|[^/]*$$||; s|/$$||; s|^$(SRCDIR)/\{0,1\}||; s|^$$|.|' | sort -u; \
  else \
    echo .; \
  fi)

# Reassign SRCDIR if sources
ifeq ($(strip $(SRCDIRS)),.)
  SRCDIR := .
  TPLDIR := templates
endif

# Get all directories containing C files
SRCS := $(foreach dir,$(SRCDIRS),$(shell \
	find "$(if $(filter .,$(dir)),.,$(SRCDIR)/$(dir))" \
	-maxdepth 1 -type f \( -name '*.c' -o -name '*.cpp' -o -name '*.cc' \) 2>/dev/null))
OBJS := $(SRCS:$(SRCDIR)/%=$(OBJDIR)/%.o)
DEPS := $(OBJS:.o=.d)

# Makefile extensions
MKLOCAL := $(filter-out $(MKUSER),$(wildcard $(CURDIR)/.metabuild/*.mk))
MKCORE := $(filter-out $(MKROOT) $(addprefix /metabuild/,$(notdir $(MKLOCAL))),$(wildcard /metabuild/*.mk))

# Library sources (separate from main sources)
EXTSRCS := $(shell [ -d "$(EXTDIR)" ] && find "$(EXTDIR)" -type f \( -name '*.c' -o -name '*.cpp' -o -name '*.cc' \) 2>/dev/null)
EXTOBJS := $(EXTSRCS:$(EXTDIR)/%=$(OBJDIR)/lib/%.o)

# Default target
.DEFAULT_GOAL := all

-include $(MKCORE)
-include $(MKLOCAL)

# Initialize submodules
submodules:
	@git submodule update --init --depth=1

version:
	@cat /metabuild/VERSION

# Separate executables from libraries based on main() presence
BINDIRS := $(foreach dir,$(SRCDIRS),$(if $(filter-out 0,$(call HAS_MAIN,$(dir))),$(dir)))
LIBDIRS := $(filter-out $(BINDIRS),$(SRCDIRS))

# Parsing directory structure
BINOBJS := $(strip $(foreach d,$(BINDIRS),$(call DEPENDENT_OBJS,$(d))))
LIBOBJS := $(strip $(foreach d,$(LIBDIRS),$(call DEPENDENT_OBJS,$(d))))

# Generate targets with special root handling
BINS := $(foreach dir,$(BINDIRS),$(if $(filter .,$(dir)),$(BINDIR)/$(PRJ)$(EXESUFFIX),$(BINDIR)/$(call CLEAN_NAME,$(dir))$(EXESUFFIX)))
LIBS := $(foreach dir,$(LIBDIRS),$(if $(filter .,$(dir)),$(LIBDIR)/$(PRJ).a,$(LIBDIR)/lib$(call CLEAN_NAME,$(dir)).a))
SHARED_LIBS := $(foreach dir,$(LIBDIRS),$(if $(filter .,$(dir)),$(LIBDIR)/$(PRJ)$(LIBSUFFIX),$(LIBDIR)/lib$(call CLEAN_NAME,$(dir))$(LIBSUFFIX)))

# External libraries (separate from internal code)
EXT_LIBDIRS := $(shell [ -d "$(EXTDIR)" ] && find "$(EXTDIR)" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sed 's|$(EXTDIR)/||')
EXT_STATIC_LIBS := $(foreach ext,$(EXT_LIBDIRS),$(LIBDIR)/lib$(ext).a)
EXT_SHARED_LIBS := $(foreach ext,$(EXT_LIBDIRS),$(LIBDIR)/lib$(ext)$(LIBSUFFIX))

# Build external libraries as separate targets
$(foreach ext,$(EXT_LIBDIRS),$(eval $(call MAKE_EXTERNAL_LIB,$(ext))))

# Build external libraries as separate targets
define MAKE_EXTERNAL_LIB
$(LIBDIR)/lib$(1).a: $(shell find $(EXTDIR)/$(1) \( -name '*.c' -o -name '*.cpp' -o -name '*.cc' \) 2>/dev/null | sed 's|$(EXTDIR)/|$(OBJDIR)/lib/|; s|\.\(c\|cpp\|cc\)$$|.\1.o|') | $(LIBDIR)
	@echo GEN $$@
	@$$(AR) rcs $$@ $$^

$(LIBDIR)/lib$(1)$(LIBSUFFIX): $(LIBDIR)/lib$(1).a | $(LIBDIR)
	@echo GEN $$@
	@$$(CC) -shared -nostartfiles -Wl,--whole-archive $$< -Wl,--no-whole-archive -o $$@
endef

# If root is a library, include both variants
ROOT_SHARED := $(if $(filter .,$(LIBDIRS)),$(LIBDIR)/$(PRJ)$(LIBSUFFIX))

# Default build (static only)
all: $(BINS) $(LIBS) $(EXT_STATIC_LIBS) $(ROOT_SHARED)

# Optional shared libraries
shared: $(SHARED_LIBS) $(EXT_SHARED_LIBS)

# Function to find related libraries for an executable
define FIND_RELATED_LIBS
$(foreach lib,$(LIBDIRS),$(if $(filter $(word 1,$(subst /, ,$(1))),$(word 1,$(subst /, ,$(lib)))),$(if $(filter .,$(lib)),$(LIBDIR)/$(PRJ).a,$(LIBDIR)/lib$(call CLEAN_NAME,$(lib)).a)))
endef

# pattern-generate executable rules (link with related libs)
define MAKE_BIN
$(if $(filter .,$(1)),$(BINDIR)/$(PRJ)$(EXESUFFIX),$(BINDIR)/$(call CLEAN_NAME,$(1))$(EXESUFFIX)): $(call DEPENDENT_OBJS,$(1)) $(call FIND_RELATED_LIBS,$(1)) | $(BINDIR)
	@echo GEN $$@
	$(if $(filter-out 0,$(call HAS_CXX,$(1))),$$(CXX),$$(CC)) $$(LDFLAGS) -fPIE $(call DEPENDENT_OBJS,$(1)) $(call FIND_RELATED_LIBS,$(1)) -o $$@ $$(LDLIBS)
endef

# pattern-generate static library rules (default)
define MAKE_LIB
$(if $(filter .,$(1)),$(LIBDIR)/$(PRJ).a,$(LIBDIR)/lib$(call CLEAN_NAME,$(1)).a): $(call DEPENDENT_OBJS,$(1)) | $(LIBDIR)
	@echo GEN $$@
	@$$(AR) rcs $$@ $$^
endef

# pattern-generate shared library rules (from static library)
define MAKE_SHARED_LIB
$(if $(filter .,$(1)),$(LIBDIR)/$(PRJ)$(LIBSUFFIX),$(LIBDIR)/lib$(call CLEAN_NAME,$(1))$(LIBSUFFIX)): $(if $(filter .,$(1)),$(LIBDIR)/$(PRJ).a,$(LIBDIR)/lib$(call CLEAN_NAME,$(1)).a) | $(LIBDIR)
	@echo GEN $$@
	@$$(CC) -shared -nostartfiles -Wl,--whole-archive $$< -Wl,--no-whole-archive -o $$@
endef


$(foreach bin,$(BINDIRS),$(eval $(call MAKE_BIN,$(bin))))

# Create subdirectories in object tree
$(foreach dir,$(filter-out .,$(SRCDIRS)),$(eval $$(OBJDIR)/$(dir): ; @mkdir -p $$@))

# Create output directories
$(OBJDIR) $(LIBDIR) $(BINDIR):
	@mkdir -p $@

# Compile source files to objects
$(OBJDIR)/%.c.o: $(SRCDIR)/%.c | $(OBJDIR)
	@mkdir -p $(dir $@)
	@echo GEN $@
	@$(CC) $(CFLAGS) -c $< -o $@

$(OBJDIR)/%.cpp.o: $(SRCDIR)/%.cpp | $(OBJDIR)
	@mkdir -p $(dir $@)
	@echo GEN $@
	@$(CXX) $(CXXFLAGS) -c $< -o $@

$(OBJDIR)/%.cc.o: $(SRCDIR)/%.cc | $(OBJDIR)
	@mkdir -p $(dir $@)
	@echo GEN $@
	@$(CXX) $(CXXFLAGS) -c $< -o $@

# Compile library files
$(OBJDIR)/lib/%.c.o: $(EXTDIR)/%.c | $(OBJDIR)
	@mkdir -p $(dir $@)
	@echo GEN $@
	@$(CC) $(CFLAGS) -MMD -MP -c $< -o $@

$(OBJDIR)/lib/%.cpp.o: $(EXTDIR)/%.cpp | $(OBJDIR)
	@mkdir -p $(dir $@)
	@echo GEN $@
	@$(CXX) $(CXXFLAGS) -MMD -MP -c $< -o $@

$(OBJDIR)/lib/%.cc.o: $(EXTDIR)/%.cc | $(OBJDIR)
	@mkdir -p $(dir $@)
	@echo GEN $@
	@$(CXX) $(CXXFLAGS) -MMD -MP -c $< -o $@

# Generate static library rules
$(foreach lib,$(LIBDIRS),$(eval $(call MAKE_LIB,$(lib))))

# Generate shared library rules
$(foreach lib,$(LIBDIRS),$(eval $(call MAKE_SHARED_LIB,$(lib))))

rebuild: clean all
reshared: clean shared

clean:
	@find $(OUTDIR) -type f -exec echo DEL {} \; 2>/dev/null || true
	@rm -rf $(OUTDIR)

# Include dependency files
-include $(DEPS)

.PHONY: all clean shared submodules rebuild reshared
