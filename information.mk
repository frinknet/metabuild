# information.mk - (c) 2025 FRINKnet & Friends - 0BSD

# CLI heading
respond:
	@echo
	@cat /metabuild/VERSION | sed 's|^|  |'
	@echo "  The Zero-Conf Build System"
	@echo "  0BSD LICENSE - just works!"
	@echo

# Self-documenting help
usage:
	@echo "  USAGE:"
	@echo
	@echo "    metabuild [comp-arch] <target>"
	@echo
	@echo "  EXAMPLES:"
	@echo
	@echo "    metabuild build"
	@echo "    metabuild clang-x64 build"
	@echo
	@echo "  Auto detects C binaries and libraries"
	@echo "  Can run with multiple compilers and"
	@echo "  architectures. Otherwise leave off."
	@echo
	@echo "    src/         put source files here."
	@echo "    lib/         external dependencies here."
	@echo "    include/     of course headers go here."
	@echo
	@echo "  Organize tests by type in single files."
	@echo
	@echo "    tests/unit/  unit tests"
	@echo "    tests/load/  load tests"
	@echo "    tests/case/  usecase tests"
	@echo
	@echo "  Extend the system easily..."
	@echo
	@echo "    .metabuild/     your *.mk go here"
	@echo "    src/templates/  add template examples"
	@echo "    syslib/         use a different syslib"
	@echo
	@echo "  BUILDING:"
	@echo
	@echo "    info         Show auto-detected build system"
	@echo "    build        Build project static by default"
	@echo "    clean        Remove all build artifacts"
	@echo "    shared       Build shared objects"
	@echo "    rebuild      Clean and rebuild"
	@echo "    reshared     Clean and rebuild shared"
	@echo
	@$(foreach mk,$(shell grep -h "^[a-zA-Z0-9_-]*-usage:" $(MKLOCAL) $(MKCORE) 2>/dev/null | sed 's/:$$//'),$(MAKE) -s $(mk);)
	@echo "  HACKING & EXTEND:"
	@echo
	@echo "    init         Add minimum build scripts"
	@echo "    shell        Open shell in build container"
	@echo "    extend       Add makefiles maximum hackery"
	@echo
	@echo "    SEE:" $(subst ghcr.io,https://github.com,$(REPO))
	@echo

# show nice failure
failed: respond
	@echo -e "  UNTIL YOU GO AND BREAK IT!\n  Oops... What did you do???\n"

# show nice missing
missing: respond
	@echo -e "  WHEN YOUR COMMAND EXISTS!!!\n  That command doesn't exist.\n\n"

# Diagnostic info
info: respond
	@echo "  PROJECT: $(PRJ)"
	@echo "  PLATFORM: $(PLATFORM)"
	@echo "  TARGET: $(TARGET)"
	@echo
	@echo "  CC: $(CC)"
	@echo "  CXX: $(CXX)"
	@echo "  CFLAGS: $(CFLAGS)"
	@echo "  CXXFLAGS: $(CXXFLAGS)"
	@echo "  LDFLAGS: $(LDFLAGS)"
	@echo
	@$(if $(strip $(SRCDIRS)),echo "  SRCDIRS: $(SRCDIRS)";)
	@$(if $(strip $(BINDIRS)),echo "  BINDIRS: $(BINDIRS)";)
	@$(if $(strip $(LIBDIRS)),echo "  LIBDIRS: $(LIBDIRS)";)
	@echo
	@$(if $(strip $(BINS)),echo "  BINARIES: $(BINS)";)
	@$(if $(strip $(LIBS)),echo "  LIBRARIES: $(LIBS)";)
	@$(if $(strip $(OBJS)),echo "  OBJECTS: $(OBJS)";)
	@$(if $(strip $(SRCS)),echo "  SOURCES: $(SRCS)";)
	@$(if $(strip $(BINDIRS)),echo -e "\n=== BINARY DEPENDENCIES ===\n";)
	@$(foreach bin,$(BINDIRS),echo "$(call CLEAN_BINNAME,$(bin))  →$(call DEPENDENT_OBJS,$(bin)) $(call RELATED_LIBS,$(bin))";)
	@$(if $(strip $(LIBDIRS)),echo -e "\n=== LIBRARY DEPENDENCIES ===\n";)
	@$(foreach lib,$(LIBDIRS),echo "$(call CLEAN_LIBNAME,$(lib))  →$(call DEPENDENT_OBJS,$(lib)) $(call RELATED_LIBS,$(lib))";)
	@$(if $(COMPS),echo -e "\n=== AVAILABLE COMPILERS ===\n";)
	@$(foreach C,$(COMPS),echo "$(C): $(foreach A,$(ARCHES),$(if $($(C).$(A)),$(C)-$(A)))";)
	@$(foreach mk,$(shell grep -h "^[a-zA-Z0-9_-]*-info:" $(MKLOCAL) $(MKCORE) 2>/dev/null | sed 's/:$$//'),$(MAKE) -s $(mk);)

# Help dispatcher
help-command:
	@$(eval T := $(word 2, $(MKCOMMAND)))
	@$(if $(T),$(MAKE) respond $(T)-usage 2>/dev/null || $(MAKE) respond missing,$(MAKE) respond usage)
	@exit 0

.PHONY: respond usage failed missing info help-command
