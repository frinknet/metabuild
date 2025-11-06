# METABUILD - (c) 2025 FRINKnet & Friends - 0BSD

# Project configuration
PRJ ?= $(shell basename $(CURDIR))
VER := $(shell git describe --tags --abbrev=0 2>/dev/null || git rev-parse --abbrev-ref HEAD 2>/dev/null || echo dev)

# Directory structure
EXTDIR  := lib
SYSDIR  := syslib
INCDIR  := include
SRCDIR  := src
TPLDIR  := $(SRCDIR)/templates
DOCDIR  := docs
WEBDIR  := web

# Output Directories
OUTDIR  := out$(if $(TARGET),/$(TARGET))
OBJDIR  := $(OUTDIR)/obj
LIBDIR  := $(OUTDIR)/lib
BINDIR  := $(OUTDIR)/bin

# Test directories
TESTDIR	 := tests
UNITDIR	 := $(TESTDIR)/unit
CASEDIR	 := $(TESTDIR)/case
LOADDIR  := $(TESTDIR)/load

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
CFLAGS += $(addprefix -I,$(EXT_HEADER_DIRS)) -fPIC -MMD -MP
CXXFLAGS += $(addprefix -I,$(EXT_HEADER_DIRS)) -fPIC -MMD -MP
LDFLAGS  +=
LDLIBS	 ?=

# Reassign SRCDIR if sources are in root
ifeq ($(strip $(SRCDIRS)),.)
  SRCDIR := .
  TPLDIR := templates
endif

# Default target
.DEFAULT_GOAL := help

# Check for USER metabuild.mk
MKUSER := $(wildcard $(CURDIR)/.metabuild/metabuild.mk)
MKROOT := $(wildcard /metabuild/metabuild.mk)

# Set to USER if it exists
ifeq ($(MKUSER),)
  MKBUILD := $(MKROOT)
else
  MKBUILD := $(MKUSER)
endif

# Let the magic begin
include $(MKBUILD)
