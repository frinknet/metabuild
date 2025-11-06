# metabuild.mk - (c) 2025 FRINKnet & Friends - 0BSD
METABUILDENV := $(shell test -f /.metabuildenv && echo 1)

# Makefile extensions
MKLOCAL := $(filter-out $(MKUSER),$(wildcard $(CURDIR)/.metabuild/*.mk))
MKCORE := $(filter-out $(MKROOT) $(addprefix /metabuild/,$(notdir $(MKLOCAL))),$(wildcard /metabuild/*.mk))


# Default vars
CC		 := clang
CXX		 := clang++
LDFLAGS  ?=

# Variables that change
REPO   ?= ghcr.io/frinknet/metabuild
IMAGE  ?= metabuild
ARCHES ?= x86 x64 arm arm64 wasm wasi
COMPS  ?= clang gcc tcc xcc osx win

# Force Docker (fixed escaping)
ifeq ($(METABUILDENV),)
.DEFAULT_GOAL := .metabuild
.metabuild:
	@docker image inspect $(IMAGE) >/dev/null 2>&1 || \
	  (docker pull "$(REPO):latest" || docker build -t "$(IMAGE)" .)
	@echo "⇢ jumping into $(IMAGE)…"
	@exec docker run --rm -it \
		-v "$(CURDIR):/work" \
		$(IMAGE) make -f $(firstword $(MAKEFILE_LIST)) $(if $(MAKECMDGOALS),$(MAKECMDGOALS),build)

%: .metabuild;
endif

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
$(shell D="$(if $(filter .,$(1)),$(SRCDIR),$(SRCDIR)/$(1))"; \
	[ -d "$$D" ] && find "$$D" -maxdepth 1 \( -name '*.c' -o -name '*.cpp' -o -name '*.cc' \) -exec awk '/int main *\(.*\)/ { if (/\{/ || getline && /^ *\{/) print FILENAME; exit }' {} \; 2>/dev/null | wc -l || echo 0)
endef

# Generate object lists for each directory (preserving structure)
define DEPENDENT_OBJS
  $(shell D="$(if $(filter .,$(1)),$(SRCDIR),$(SRCDIR)/$(patsubst $(SRCDIR)/%,%,$(1)))"; \
    [ -d "$$D" ] && find "$$D" -maxdepth 1 -type f \( -name '*.c' -o -name '*.cc' -o -name '*.cpp' \) | \
    sed 's|^$(SRCDIR)/||; s|^\./||; s|^|$(OBJDIR)/|; s|\.c$$|.c.o|; s|\.cc$$|.c.o|; s|\.cpp$$|.cpp.o|' )
endef

# Function to generate clean target names
define CLEAN_LIBNAME
$(strip \
  $(eval stripped := $(patsubst src/%,%,$(patsubst src,.,$(1))))\
  $(eval subdir := $(if $(filter .,$(stripped)),,$(subst /,-,$(stripped))))\
  $(if $(filter .,$(stripped)),$(PRJ),$(PRJ)$(if $(subdir),-$(subdir))))
endef

# Function to find related libraries for an executable
define FIND_RELATED_LIBS
$(foreach lib,$(LIBDIRS),$(if $(filter $(word 1,$(subst /,,$(1))),$(word 1,$(subst /,,$(lib)))),$(if $(filter .,$(lib)),$(LIBDIR)/$(PRJ).a,$(LIBDIR)/$(call CLEAN_LIBNAME,$(lib)).a)))
endef

# pattern-generate executable rules (link with related libs)
define MAKE_BIN
$(if $(filter . src,$(1)),$(BINDIR)/$(PRJ)$(EXESUFFIX),$(BINDIR)/$(call CLEAN_BINNAME,$(1))$(EXESUFFIX)): $(call DEPENDENT_OBJS,$(1)) $(call FIND_RELATED_LIBS,$(1)) | $(BINDIR)
	@echo GEN $$@
	$(if $(filter-out 0,$(call HAS_CXX,$(1))),$$(CXX),$$(CC)) $$(LDFLAGS) -fPIE $(call DEPENDENT_OBJS,$(1)) $(call FIND_RELATED_LIBS,$(1)) -o $$@ $$(LDLIBS)
endef

# pattern-generate static library rules (default)
define MAKE_LIB
$(if $(filter . src,$(1)),$(LIBDIR)/$(PRJ).a,$(LIBDIR)/$(call CLEAN_LIBNAME,$(1)).a): $(call DEPENDENT_OBJS,$(1)) | $(LIBDIR)
	@echo GEN $$@
	@$$(AR) rcs $$@ $$^
endef

# pattern-generate shared library rules (from static library)
define MAKE_SHARED_LIB
$(if $(filter . src,$(1)),$(LIBDIR)/$(PRJ)$(LIBSUFFIX),$(LIBDIR)/$(call CLEAN_LIBNAME,$(1))$(LIBSUFFIX)): $(if $(filter . src,$(1)),$(LIBDIR)/$(PRJ).a,$(LIBDIR)/$(call CLEAN_LIBNAME,$(1)).a) | $(LIBDIR)
	@echo GEN $$@
	@$$(CC) -shared -nostartfiles -Wl,--whole-archive $$< -Wl,--no-whole-archive -o $$@
endef

#### begin METABUILD wizardtry

# Get all directories containing C files (excluding templates)
SRCDIRS := $(shell \
  if [ -d "$(SRCDIR)" ]; then \
    find "$(SRCDIR)" -type f \( -name '*.c' -o -name '*.cpp' -o -name '*.cc' \) -not -path "$(TPLDIR)/*" -print 2>/dev/null | \
    sed 's|/[^/]*$$||' | sort -u; \
  else \
    echo .; \
  fi)
# Get all directories containing C files
SRCS := $(foreach dir,$(SRCDIRS),$(shell \
	find "$(dir)" -maxdepth 1 -type f \( -name '*.c' -o -name '*.cpp' -o -name '*.cc' \) 2>/dev/null))
OBJS := $(SRCS:$(SRCDIR)/%=$(OBJDIR)/%.o)
DEPS := $(OBJS:.o=.d)

# Library sources (separate from main sources)
EXTSRCS := $(shell [ -d "$(EXTDIR)" ] && find "$(EXTDIR)" -type f \( -name '*.c' -o -name '*.cpp' -o -name '*.cc' \) 2>/dev/null)
EXTOBJS := $(EXTSRCS:$(EXTDIR)/%=$(OBJDIR)/lib/%.o)

-include $(MKLOCAL)
-include $(MKCORE)

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
BINS := $(foreach dir,$(BINDIRS),$(if $(filter . src,$(dir)),$(BINDIR)/$(PRJ)$(EXESUFFIX),$(BINDIR)/$(call CLEAN_BINNAME,$(dir))$(EXESUFFIX)))
LIBS := $(foreach dir,$(LIBDIRS),$(if $(filter . src,$(dir)),$(LIBDIR)/$(PRJ).a,$(LIBDIR)/lib$(call CLEAN_LIBNAME,$(dir)).a))
SHARED_LIBS := $(foreach dir,$(LIBDIRS),$(if $(filter . src,$(dir)),$(LIBDIR)/$(PRJ)$(LIBSUFFIX),$(LIBDIR)/lib$(call CLEAN_LIBNAME,$(dir))$(LIBSUFFIX)))

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

# Default build (static only)
build: $(EXT_STATIC_LIBS) $(BINS) $(LIBS)

# Optional shared libraries
shared: $(SHARED_LIBS) $(EXT_SHARED_LIBS)

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

rebuild: clean build
reshared: clean shared

# cleanup scripts
clean:
	@find $(OUTDIR) -type f -not -name *.d -exec echo DEL {} \; 2>/dev/null || true
	@rm -rf $(OUTDIR)

# Include dependency files
-include $(DEPS)

# Catch undefined targets
%:
	@$(MAKE) missing

.PHONY: build clean shared submodules rebuild reshared compilers
