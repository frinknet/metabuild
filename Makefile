# METABUILD - (c) 2025 FRINKnet & Friends - 0BSDA/all
VPATH = $(CURDIR):$(CURDIR)/.metabuild:.

# Project configuration
PRJ ?= $(shell basename $(CURDIR))
VER := $(shell git describe --tags --abbrev=0 2>/dev/null || git rev-parse --abbrev-ref HEAD 2>/dev/null || echo dev)

# Directory structure
LIBDIR	 := lib
SYSDIR	 := syslib
INCDIR	 := include
TPLDIR	 := src/templates
SRCDIR	 := src
DOCDIR	 := docs
WEBDIR	 := web
OUTDIR	 := out/$(TARGET)
OBJDIR	 := $(OUTDIR)/obj
LNKDIR	 := $(OUTDIR)/lib
BINDIR	 := $(OUTDIR)/bin
TESTDIR	 := tests
UNITDIR	 := $(TESTDIR)/unit
CASEDIR	 := $(TESTDIR)/case
LOADDIR := $(TESTDIR)/load

# Platform detection for file extensions
ifeq ($(OS),Windows_NT)
	EXESUFFIX := .exe
	LIBSUFFIX := .dll
else
	EXESUFFIX :=
	LIBSUFFIX := .so
endif

# Add SYSDIR only if it exists
ifneq ($(wildcard $(SYSDIR)),)
	CFLAGS	 += -isystem $(SYSDIR)
	CXXFLAGS += -isystem $(SYSDIR)
endif

# Compiler flags using the directory structure
CFLAGS	 += -I$(INCDIR) -I$(LIBDIR)
CXXFLAGS += -I$(INCDIR) -I$(LIBDIR)

# Smart detection: add each library subdirectory that contains headers
LIB_HEADER_DIRS := $(shell find $(LIBDIR) -mindepth 1 -type d -exec test -e "{}/*.h" \; -print 2>/dev/null)
CFLAGS += $(addprefix -I,$(LIB_HEADER_DIRS))
CXXFLAGS += $(addprefix -I,$(LIB_HEADER_DIRS))


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


# Discover all directories containing C files (including root and nested)
SRCDIRS := $(shell find $(SRCDIR) -path "$(TPLDIR)" -prune -o -type f -name '*.c' -print | xargs -r dirname | sort -u | sed 's|^$(SRCDIR)||' | sed 's|^/||' | sed 's|^$$|.|')


# Function to check if directory contains main()
define HAS_MAIN
$(shell find $(if $(filter .,$(1)),$(SRCDIR),$(SRCDIR)/$(1)) -maxdepth 1 -name '*.c' -exec grep -l "int main\|void main" {} \; 2>/dev/null | wc -l)
endef

# Separate executables from libraries based on main() presence
BINDIRS := $(foreach dir,$(SRCDIRS),$(if $(filter-out 0,$(call HAS_MAIN,$(dir))),$(dir)))
LIBDIRS := $(filter-out $(BINDIRS),$(SRCDIRS))

# Generate object lists for each directory (preserving structure)
define SUBDIR_OBJS
$(shell find $(if $(filter .,$(1)),$(SRCDIR),$(SRCDIR)/$(1)) -maxdepth 1 -name '*.c' | sed 's|$(SRCDIR)/||; s|^|$(OBJDIR)/|' | sed 's|\.c$$|.c.o|')
endef

# Function to generate clean target names
define CLEAN_NAME
$(subst /,_,$(1))
endef

# Generate targets with special root handling
BINS := $(foreach dir,$(BINDIRS),$(if $(filter .,$(dir)),$(BINDIR)/$(PRJ)$(EXESUFFIX),$(BINDIR)/$(call CLEAN_NAME,$(dir))$(EXESUFFIX)))
LIBS := $(foreach dir,$(LIBDIRS),$(if $(filter .,$(dir)),$(LNKDIR)/$(PRJ).a,$(LNKDIR)/lib$(call CLEAN_NAME,$(dir)).a))
SHARED_LIBS := $(foreach dir,$(LIBDIRS),$(if $(filter .,$(dir)),$(LNKDIR)/$(PRJ)$(LIBSUFFIX),$(LNKDIR)/lib$(call CLEAN_NAME,$(dir))$(LIBSUFFIX)))

# Default build (static only)
all: $(BINS) $(LIBS)

# Optional shared libraries
shared: $(SHARED_LIBS) $(LNKDIR)/$(PRJ)$(LIBSUFFIX)

# Function to find related libraries for an executable
define FIND_RELATED_LIBS
$(foreach lib,$(LIBDIRS),$(if $(filter $(word 1,$(subst /, ,$(1))),$(word 1,$(subst /, ,$(lib)))),$(if $(filter .,$(lib)),$(LNKDIR)/$(PRJ).a,$(LNKDIR)/lib$(call CLEAN_NAME,$(lib)).a)))
endef

# pattern-generate executable rules (link with related libs)
define MAKE_BIN
$(if $(filter .,$(1)),$(BINDIR)/$(PRJ)$(EXESUFFIX),$(BINDIR)/$(call CLEAN_NAME,$(1))$(EXESUFFIX)): $(call SUBDIR_OBJS,$(1)) $(call FIND_RELATED_LIBS,$(1)) | $(BINDIR)
	@echo GEN $$@
	$$(CC) $(call SUBDIR_OBJS,$(1)) $(call FIND_RELATED_LIBS,$(1)) -o $$@ $$(LDFLAGS)
endef

# pattern-generate static library rules (default)
define MAKE_LIB
$(if $(filter .,$(1)),$(LNKDIR)/$(PRJ).a,$(LNKDIR)/lib$(call CLEAN_NAME,$(1)).a): $(call SUBDIR_OBJS,$(1)) | $(LNKDIR)
	@echo GEN $$@
	$$(AR) rcs $$@ $$^
endef

# pattern-generate shared library rules (optional)
define MAKE_SHARED_LIB
$(if $(filter .,$(1)),$(LNKDIR)/$(PRJ)$(LIBSUFFIX),$(LNKDIR)/lib$(call CLEAN_NAME,$(1))$(LIBSUFFIX)): $(call SUBDIR_OBJS,$(1)) | $(LNKDIR)
	@echo GEN $$@
ifeq ($(LIBSUFFIX),.dll)
	$$(CC) -shared $$^ -o $$@ $$(LDFLAGS)
else
	$$(CC) -shared $$^ -o $$@ $$(LDFLAGS)
endif
endef

$(foreach bin,$(BINDIRS),$(eval $(call MAKE_BIN,$(bin))))
$(foreach lib,$(LIBDIRS),$(eval $(call MAKE_LIB,$(lib))))

# Create subdirectories in object tree
$(foreach dir,$(filter-out .,$(SRCDIRS)),$(eval $$(OBJDIR)/$(dir): ; @mkdir -p $$@))

# Create output directories
$(OBJDIR) $(LNKDIR) $(BINDIR): $(SRCDIR)
	@mkdir -p $@

# Compile source files to objects (with PIC for shared lib support)
$(OBJDIR)/%.c.o: $(SRCDIR)/%.c | $(OBJDIR)
	@mkdir -p $(dir $@)
	@echo GEN $@
	@$(CC) $(CFLAGS) -fPIC -MMD -MP -c $< -o $@

$(OBJDIR)/%.cpp.o: $(SRCDIR)/%.cpp | $(OBJDIR)
	@mkdir -p $(dir $@)
	@echo GEN $@
	@$(CXX) $(CXXFLAGS) -fPIC -MMD -MP -c $< -o $@

$(OBJDIR)/%.cc.o: $(SRCDIR)/%.cc | $(OBJDIR)
	@mkdir -p $(dir $@)
	@echo GEN $@
	@$(CXX) $(CXXFLAGS) -fPIC -MMD -MP -c $< -o $@

# Compile library files
$(OBJDIR)/lib/%.c.o: $(LIBDIR)/%.c | $(OBJDIR)
	@mkdir -p $(dir $@)  
	@echo GEN $@
	@$(CC) $(CFLAGS) -MMD -MP -c $< -o $@

$(OBJDIR)/lib/%.cpp.o: $(LIBDIR)/%.cpp | $(OBJDIR)
	@mkdir -p $(dir $@)
	@echo GEN $@
	@$(CXX) $(CXXFLAGS) -MMD -MP -c $< -o $@

$(OBJDIR)/lib/%.cc.o: $(LIBDIR)/%.cc | $(OBJDIR)
	@mkdir -p $(dir $@)
	@echo GEN $@
	@$(CXX) $(CXXFLAGS) -MMD -MP -c $< -o $@

# Create static library
$(LNKDIR)/$(PRJ).a: $(LIBOBJS) | $(LNKDIR)
	@echo GEN $@
	@$(AR) rcs $@ $^

# Generate shared library rules (but don't build by default)
$(foreach lib,$(LIBDIRS),$(eval $(call MAKE_SHARED_LIB,$(lib))))

# Shared version of external lib
$(LNKDIR)/$(PRJ)$(LIBSUFFIX): $(LIBOBJS) | $(LNKDIR)
	@echo GEN $@
ifeq ($(LIBSUFFIX),.dll)
	$(CC) -shared $^ -o $@ $(LDFLAGS)
else
	$(CC) -shared $^ -o $@ $(LDFLAGS)
endif

clean:
	@rm -rf $(OUTDIR)

.PHONY: all lib clean new submodule template-list shared

# Include dependency files
-include $(DEPS)

.PHONY: all clean shared submodules
