# metabuild.mk - (c) 2025 FRINKnet & Friends - 0BSD
METABUILD := $(shell test -f /.dockerenv && echo 1)

# Default vars
CC		 ?= clang
CXX		 ?= clang++
LDFLAGS  ?=

# Variables that change
REPO   ?= ghcr.io/frinknet/metabuild
IMAGE  ?= metabuild
ARCHES ?= x86 x64 arm arm64 wasm wasi
COMPS  ?= clang gcc tcc xcc osx win

# Force Docker (fixed escaping)
ifeq ($(METABUILD),)
.DEFAULT_GOAL := $(MAKECMDGOALS)
$(.DEFAULT_GOAL):
	@docker image inspect $(IMAGE) >/dev/null 2>&1 || \
	  (docker pull "$(REPO):latest" || docker build -t "$(IMAGE)" .)
	@echo "⇢ jumping into $(IMAGE)…"
	@exec docker run --rm -it \
		-v "$(CURDIR):/work" \
		$(IMAGE) make -f $(firstword $(MAKEFILE_LIST)) $(MAKECMDGOALS)
endif

# Toolchain matrix (completed with real cross-compile paths)
clang.cc		:= clang
clang.cxx		:= clang++
clang.x86		:= -m32
clang.x64		:= -m64
clang.arm		:= --target=arm-linux-gnueabihf
clang.arm64		:= --target=aarch64-linux-gnu
clang.wasm		:= --target=wasm32-unknown-unknown
clang.wasm.ld	:= --no-entry --export-dynamic
clang.wasi		:= --target=wasm32-wasi --sysroot=$(WASI_SYSROOT)

gcc.cc			:= gcc
gcc.cxx			:= g++
gcc.x86			:= -m32
gcc.x64			:= -m64
gcc.arm			:= # requires cross-gcc
gcc.arm64		:= # requires cross-gcc

tcc.cc			:= tcc
tcc.cxx			:= clang++
tcc.x86			:= -m32
tcc.x64			:= -m64

xcc.cc			:= xcc
xcc.cxx			:= xcc
xcc.x86			:= -m32
xcc.x64			:= -m64

osx.cc			:= o64-clang
osx.cxx			:= o64-clang++
osx.x64			:= -mmacosx-version-min=10.13
osx.arm64		:= -target arm64-apple-macos11

win.cc			:= x86_64-w64-mingw32-gcc
win.cxx			:= x86_64-w64-mingw32-g++
win.x86			:= -m32
win.x64			:= -m64

# Runtime assignment (only when COMP/ARCH are set)
ifdef COMP
ifdef ARCH
CC		 := $($(COMP).cc)
CXX		 := $($(COMP).cxx)
CFLAGS	 += $($(COMP).$(ARCH)) $($(COMP).$(ARCH).c)
CXXFLAGS += $($(COMP).$(ARCH)) $($(COMP).$(ARCH).cxx)
LDFLAGS  += $($(COMP).$(ARCH).ld)
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
