# metabuild.mk - (c) 2025 FRINKnet & Friends - 0BSD
METABUILD := $(shell test -d /metabuild || echo local)

# Project configuration
PRJ ?= $(shell basename $(CURDIR))
VER ?= $(shell git describe --tags --abbrev=0 2>/dev/null || git rev-parse --abbrev-ref HEAD 2>/dev/null || echo dev)

# Makefile extensions
MKGOAL  ?= help
MKUSER  := $(CURDIR)/.metabuild/metabuild.mk
MKROOT  := /metabuild/metabuild.mk
MKLOCAL := $(filter-out $(MKUSER),$(wildcard $(CURDIR)/.metabuild/*.mk))
MKCORE := $(filter-out $(MKROOT) $(addprefix /metabuild/,$(notdir $(MKUSER) $(MKLOCAL))),$(wildcard /metabuild/*.mk))

# Variables that change
REPO   ?= ghcr.io/frinknet/metabuild
IMAGE  ?= metabuild
ARCHES ?= x86 x64 arm arm64 wasm wasi
COMPS  ?= clang gcc tcc xcc osx win

# Force Docker (fixed escaping)
ifeq ($(METABUILD),local)
.DEFAULT_GOAL := metabuild.docker
metabuild.docker:
	@docker image inspect $(IMAGE) >/dev/null 2>&1 || (docker pull "$(REPO):latest" || docker build -t "$(IMAGE)" .)
	@echo "Jumping into ⇢  $(IMAGE)…"
	@exec docker run --rm -it \
		-u "$(shell id -u):$(shell id -g)" \
		-v "$(CURDIR):/build" \
		-e PRJ="$(PRJ)" \
		$(IMAGE) $(firstword $(MAKEFILE_LIST)) $(MAKEOVERRIDES) $(if $(MAKECMDGOALS),$(MAKECMDGOALS),$(MKGOAL))

%: metabuild.docker
	@:

.PHONY: metabuild.docker
else

# Setup directory structure
getdir = $(firstword $(foreach d,$(1),$(if $(wildcard $(d)),$(d))))
EXTDIR  := $(call getdir,$(EXTDIR))
SYSDIR  := $(call getdir,$(SYSDIR))
INCDIR  := $(call getdir,$(INCDIR))
SRCDIR  := $(call getdir,$(SRCDIR))
TPLDIR  := $(call getdir,$(TPLDIR))
SPLDIR  := $(call getdir,$(SPLDIR))
DOCDIR  := $(call getdir,$(DOCDIR))
WEBDIR  := $(call getdir,$(WEBDIR))
CHKDIR	:= $(call getdir,$(CHKDIR))

# Output Directories
OUTDIR  := $(OUTDIR)$(if $(TARGET),/$(TARGET))
OBJDIR  := $(OUTDIR)/obj
LIBDIR  := $(OUTDIR)/lib
BINDIR  := $(OUTDIR)/bin

# Exclude fron source searches
NOTSRCS := $(foreach var,$(NOTSRC),$(if $($(var)),$($(var)) $(shell find $($(var)) -mindepth 1 -type d 2>/dev/null | sed 's|^\./||')))

# Add SYSDIR only if it exists
ifneq ($(wildcard $(SYSDIR)),)
	CFLAGS	 += -isystem $(SYSDIR)
	CXXFLAGS += -isystem $(SYSDIR)
	LDFLAGS  += -static
endif

# Compiler flags using the directory structure
CFLAGS	 += -I$(INCDIR) -I$(EXTDIR)
CXXFLAGS += -I$(INCDIR) -I$(EXTDIR)

# Smart detection: add each library subdirectory that contains headers
EXT_HEADER_DIRS = $(shell \
	[ -d "$(EXTDIR)" ] && \
	find "$(EXTDIR)" -mindepth 1 -type d -exec test -e "{}/*.h" \; \
	-print 2>/dev/null)

# Set bassic flags for compiler and linker
CFLAGS += $(addprefix -I,$(EXT_HEADER_DIRS)) -fPIC -MD -MP
CXXFLAGS += $(addprefix -I,$(EXT_HEADER_DIRS)) -fPIC -MD -MP
LDFLAGS  +=
LDLIBS	 +=

# Get commands
COMMANDS := $(shell grep -h "^[a-zA-Z0-9_-]*-command:" $(MKLOCAL) $(MKCORE) 2>/dev/null | sed 's/:$$//; s/-command$$//' | sort -u)

# Run command dispatch
define RUN_COMMAND
$(1):
	@$(MAKE) -s $(1)-command MKCOMMAND="$(MAKECMDGOALS)"
	@exit 0

.PHONY: $(1)
endef

# Command loopback
$(foreach cmd,$(COMMANDS),$(eval $(call RUN_COMMAND,$(cmd))))

# Guard everything
ifneq (,$(filter $(COMMANDS),$(word 1, $(MAKECMDGOALS))))
%:
	@:
endif

# Toolchain matrix (completed with real cross-compile paths)
clang.cc      := clang
clang.cxx     := clang++
clang.ld      := -nodefaultlibs
clang.x86     := -m32
clang.x64     := -m64
clang.arm     := --target=arm-linux-gnueabihf
clang.arm64   := --target=aarch64-linux-gnu
clang.wasm    := --target=wasm32-unknown-unknown
clang.wasm.ld := --no-entry --export-dynamic
clang.wasi    := --target=wasm32-wasi --sysroot=$(WASI_SYSROOT)

gcc.cc        := gcc
gcc.cxx       := g++
gcc.x86       := -m32
gcc.x64       := -m64
gcc.arm       := # requires cross-gcc
gcc.arm64     := # requires cross-gcc

tcc.cc        := tcc
tcc.cxx       := clang++
tcc.x86       := -m32
tcc.x64       := -m64

xcc.cc        := xcc
xcc.cxx       := xcc
xcc.x86       := -m32
xcc.x64       := -m64

osx.cc        := o64-clang
osx.cxx       := o64-clang++
osx.x64       := -mmacosx-version-min=10.13
osx.arm64     := -target arm64-apple-macos11

win.cc        := x86_64-w64-mingw32-gcc
win.cxx       := x86_64-w64-mingw32-g++
win.x86       := -m32
win.x64       := -m64

# Runtime assignment (only when COMP/ARCH are set)
ifdef COMP
ifdef ARCH
CC		 := $($(COMP).cc)
CXX		 := $($(COMP).cxx)
CFLAGS	 += $($(COMP).$(ARCH)) $($(COMP).$(ARCH).c)
CXXFLAGS += $($(COMP).$(ARCH)) $($(COMP).$(ARCH).cxx)
LDFLAGS  += $($(COMP).ld) $($(COMP).$(ARCH).ld)
TARGET	 := $(COMP)-$(ARCH)

# Verify toolchain exists
$(if $(CC),,$(error Unknown compiler '$(COMP)'))
$(if $($(COMP).$(ARCH)),,$(error Unknown arch '$(ARCH)' for '$(COMP)'))
endif
endif

# Target platform detection based on cross-compiler
ifeq ($(COMP),win)
	PLATFORM := Windows
	EXESUFFIX := .exe
	LIBSUFFIX := .dll
else ifeq ($(COMP),osx)
	PLATFORM := macOS
	EXESUFFIX :=
	LIBSUFFIX := .dylib
else ifeq ($(ARCH),wasm)
	PLATFORM := WebAssembly
	EXESUFFIX := .wasm
	LIBSUFFIX :=
else ifeq ($(ARCH),wasi)
	PLATFORM := WASI
	EXESUFFIX := .wasm
	LIBSUFFIX :=
else
	PLATFORM := Linux
	EXESUFFIX :=
	LIBSUFFIX := .so
endif

# Matrix target generation
$(foreach A,$(ARCHES),$(foreach C,$(COMPS),$(eval $(C)-$(A): ; @$$(MAKE) all ARCH=$(A) COMP=$(C))))

# Per-target matrix
ifdef T
$(foreach A,$(ARCHES),$(foreach C,$(COMPS),$(eval $(C)-$(A)-$(T): ; @$$(MAKE) $(T) ARCH=$(A) COMP=$(C))))
endif

# Function to check if directory contains C++ files
define HAS_CXX
$(shell D="$(if $(filter .,$(1)),$(SRCDIR),$(SRCDIR)/$(1))"; \
	[ -d "$$D" ] && find "$$D" -maxdepth 1 \( -name '*.cpp' -o -name '*.cc' \) 2>/dev/null | wc -l || echo 0)
endef

# Function to check if directory contains main()
define HAS_MAIN
$(shell D="$(1)"; \
	[ -d "$$D" ] && find "$$D" -maxdepth 1 \( -name '*.c' -o -name '*.cpp' -o -name '*.cc' \) -exec awk '/int main *\(.*\)/ { if (/\{/ || getline && /^ *\{/) print FILENAME; exit }' {} \; 2>/dev/null | wc -l || echo 0)
endef

# Generate object lists for each directory (preserving structure)
define DEPENDENT_OBJS
  $(shell D="$(1)"; \
    [ -d "$$D" ] && find "$$D" -maxdepth 1 -type f \( -name '*.c' -o -name '*.cc' -o -name '*.cpp' \) | \
    sed 's|^$(SRCDIR)/||; s|^\./||; s|^|$(OBJDIR)/|; s|\.c$$|.c.o|; s|\.cc$$|.c.o|; s|\.cpp$$|.cpp.o|' )
endef

# Function to generate clean target names for binaries
define CLEAN_BINNAME
$(strip \
	$(eval stripped := $(patsubst src/%,%,$(patsubst src,.,$(1))))\
	$(eval subdir := $(if $(filter .,$(stripped)),,$(subst /,-,$(stripped))))\
	$(if $(filter .,$(stripped)),$(PRJ),$(PRJ)$(if $(subdir),-$(subdir))))$(EXESUFFIX)
endef

# Function to generate clean target names for libraries
define CLEAN_LIBNAME
$(strip \
  $(eval stripped := $(patsubst $(SRCDIR)/%,%,$(patsubst $(SRCDIR),.,$(1))))\
  $(eval subdir := $(if $(filter .,$(stripped)),,$(subst /,-,$(stripped))))\
  $(if $(filter .,$(1)),$(PRJ),lib$(PRJ)$(if $(subdir),-$(subdir))).a)
endef

# Function to find related libraries for an executable
define RELATED_LIBS
$(foreach child,$(filter $(LIBDIRS),$(shell find $(1) -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sed 's|^\./||')),\
  $(LIBDIR)/$(call CLEAN_LIBNAME,$(child)) )
endef

# Function to get all parent directories up to SRCDIR
define PARENT_LIBS
$(strip \
  $(eval parent := $(patsubst %/,%,$(dir $(patsubst %/,%,$(1)))))\
  $(if $(filter-out . $(1),$(parent)),\
    $(if $(filter-out $(SRCDIR),$(parent)),$(call PARENT_LIBS,$(parent))) \
    $(filter-out $(BINDIRS),$(parent))))
endef

# pattern-generate executable rules (link with related libs)
define MAKE_BIN
$(BINDIR)/$(call CLEAN_BINNAME,$(1)): $(call DEPENDENT_OBJS,$(1)) $(call RELATED_LIBS,$(1)) | $(BINDIR)
	@echo GEN $$@
	$(if $(filter-out 0,$(call HAS_CXX,$(1))),$$(CXX),$$(CC)) $$(LDFLAGS) -fPIE $(call DEPENDENT_OBJS,$(1)) $(call RELATED_LIBS,$(1)) -o $$@ $$(LDLIBS)
endef

# pattern-generate static library rules (default)
define MAKE_LIB
$(LIBDIR)/$(call CLEAN_LIBNAME,$(1)): $(call DEPENDENT_OBJS,$(1)) \
  $$(foreach child,$$(filter $(1)/%,$$(LIBDIRS)),$$(call DEPENDENT_OBJS,$$(child))) | $(LIBDIR)
	@echo GEN $$@
	@$$(AR) rcs $$@ $$^
endef

# pattern-generate shared library rules (from static library)
define MAKE_SHARED_LIB
$(patsubst %.a,%$(LIBSUFFIX),$(LIBDIR)/$(call CLEAN_LIBNAME,$(1))): $(LIBDIR)/$(call CLEAN_LIBNAME,$(1)) | $(LIBDIR)
	@echo GEN $$@
	@$$(CC) -shared -nostartfiles -Wl,--whole-archive $$< -Wl,--no-whole-archive -o $$@
endef

# Build external libraries as separate targets
define MAKE_EXTERNAL_LIB
$(LIBDIR)/lib$(1).a: $(shell find $(EXTDIR)/$(1) \( -name '*.c' -o -name '*.cpp' -o -name '*.cc' \) 2>/dev/null | sed 's|$(EXTDIR)/|$(OBJDIR)/lib/|; s|\.\(c\|cpp\|cc\)$$|.\1.o|') | $(LIBDIR)
	@echo GEN $$@
	@$$(AR) rcs $$@ $$^

$(LIBDIR)/lib$(1)$(LIBSUFFIX): $(LIBDIR)/lib$(1).a | $(LIBDIR)
	@echo GEN $$@
	@$$(CC) -shared -nostartfiles -Wl,--whole-archive $$< -Wl,--no-whole-archive -o $$@
endef

# Get all directories containing C files (excluding NOTSRC)
SRCDIRS := $(filter-out $(NOTSRCS),$(shell \
  { find "$(SRCDIR)" -type f \( -name '*.c' -o -name '*.cpp' -o -name '*.cc' \) -print 2>/dev/null; \
    find "." -maxdepth 1 -type f \( -name '*.c' -o -name '*.cpp' -o -name '*.cc' \) -print 2>/dev/null; \
  } | sed 's|/[^/]*$$||; s|^\./||' | sort -u))

# Get all directories containing C files
SRCS := $(foreach dir,$(SRCDIRS),$(shell \
	find "$(dir)" -maxdepth 1 -type f \( -name '*.c' -o -name '*.cpp' -o -name '*.cc' \) 2>/dev/null | \
	sed 's|^\./||' ))
OBJS := $(addprefix $(OBJDIR)/,$(SRCS:.c=.c.o))
DEPS := $(OBJS:.o=.d)

# Library sources (separate from main sources)
EXTSRCS := $(shell [ -d "$(EXTDIR)" ] && find "$(EXTDIR)" -type f \( -name '*.c' -o -name '*.cpp' -o -name '*.cc' \) 2>/dev/null)
EXTOBJS := $(EXTSRCS:$(EXTDIR)/%=$(OBJDIR)/lib/%.o)

# Initialize submodules
submodules:
	@git submodule update --init --depth=1

version:
	@cat /metabuild/VERSION

# Separate executables from libraries based on main() presence
BINDIRS := $(foreach dir,$(SRCDIRS),$(if $(filter-out 0,$(call HAS_MAIN,$(dir))),$(dir)))
LIBDIRS := $(filter-out $(BINDIRS),$(SRCDIRS))

# Add parent directories to LIBDIRS for aggregation
LIBDIRS := $(sort $(LIBDIRS) $(foreach dir,$(LIBDIRS),$(call PARENT_LIBS,$(dir))))

# Parsing directory structure
BINOBJS := $(strip $(foreach d,$(BINDIRS),$(call DEPENDENT_OBJS,$(d))))
LIBOBJS := $(strip $(foreach d,$(LIBDIRS),$(call DEPENDENT_OBJS,$(d))))

# Generate targets with special root handling
BINS := $(foreach dir,$(BINDIRS),$(BINDIR)/$(call CLEAN_BINNAME,$(dir)))
LIBS := $(foreach dir,$(LIBDIRS),$(LIBDIR)/$(call CLEAN_LIBNAME,$(dir)))
SHARED_LIBS := $(LIBS:%.a=%$(LIBSUFFIX))

# External libraries (separate from internal code)
EXT_LIBDIRS := $(shell [ -d "$(EXTDIR)" ] && find "$(EXTDIR)" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sed 's|$(EXTDIR)/||')
EXT_STATIC_LIBS := $(foreach ext,$(EXT_LIBDIRS),$(LIBDIR)/lib$(ext).a)
EXT_SHARED_LIBS := $(EXT_STATIC_LIBS:%.a=%$(LIBSUFFIX))

debug:
	@echo "=== DEBUG INFO ==="
	@echo "SRCDIR: $(SRCDIR)"
	@echo "SRCDIRS: $(SRCDIRS)"
	@echo "BINDIRS: $(BINDIRS)"
	@echo "LIBDIRS: $(LIBDIRS)"
	@echo ""
	@echo "=== PARENT_LIBS TEST ==="
	@$(foreach dir,$(LIBDIRS),echo "PARENT_LIBS($(dir)): $(call PARENT_LIBS,$(dir))";)
	@echo ""
	@echo "=== LIBRARY GENERATION ==="
	@echo "LIBS: $(LIBS)"
	@echo ""
	@echo "=== LIBOBJS ==="
	@echo "LIBOBJS: $(LIBOBJS)"
	@echo ""
	@echo "=== GENERATED LIB RULES ==="
	@$(foreach lib,$(LIBDIRS),echo "Generated rule for: $(LIBDIR)/$(call CLEAN_LIBNAME,$(lib))";)
	@echo ""
	@echo "=== GENERATED PARENT LIB RULES ==="
	@$(foreach dir,$(LIBDIRS),$(foreach parent,$(call PARENT_LIBS,$(dir)),echo "Generated rule for parent: $(LIBDIR)/$(call CLEAN_LIBNAME,$(parent))";))

.PHONY: debug

# Include paths
include $(MKLOCAL)
include $(MKCORE)

# Build external libraries as separate targets
$(foreach ext,$(EXT_LIBDIRS),$(eval $(call MAKE_EXTERNAL_LIB,$(ext))))

# Default build (static only)
build: $(EXT_STATIC_LIBS) $(BINS) $(LIBS)

# Optional shared libraries
shared: $(SHARED_LIBS) $(EXT_SHARED_LIBS)

# Generate binary output rules
$(foreach bin,$(BINDIRS),$(eval $(call MAKE_BIN,$(bin))))

# Generate static library rules
$(foreach lib,$(LIBDIRS),$(eval $(call MAKE_LIB,$(lib))))

# Generate shared library rules
$(foreach lib,$(LIBDIRS),$(eval $(call MAKE_SHARED_LIB,$(lib))))

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
	@$(CC) $(CFLAGS) -MD -MP -c $< -o $@

$(OBJDIR)/lib/%.cpp.o: $(EXTDIR)/%.cpp | $(OBJDIR)
	@mkdir -p $(dir $@)
	@echo GEN $@
	@$(CXX) $(CXXFLAGS) -MD -MP -c $< -o $@

$(OBJDIR)/lib/%.cc.o: $(EXTDIR)/%.cc | $(OBJDIR)
	@mkdir -p $(dir $@)
	@echo GEN $@
	@$(CXX) $(CXXFLAGS) -MD -MP -c $< -o $@

rebuild: clean build
reshared: clean shared

# cleanup scripts
clean:
	@find $(OUTDIR) -type f -not -name *.d -exec echo DEL {} \; 2>/dev/null || true
	@rm -rf $(OUTDIR)

# Include dependency files
include $(wildcard $(DEPS))

# Catch undefined targets
%:
	@$(MAKE) missing

# Default target is set last
.DEFAULT_GOAL := $(MKGOAL)

.PHONY: build clean shared submodules rebuild reshared compilers
endif
