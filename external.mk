# (c) 2025 FRINKnet & Friends - 0BSD

# Discover all external libraries
EXTERNAL_LIBS := $(notdir $(wildcard $(LIBDIR)/*))

# Detection function for each library type
define DETECT_LIB_TYPE
$(shell \
if [ -f $(LIBDIR)/$(1)/metabuild.mk ]; then \
	echo "metabuild"; \
elif [ -f $(LIBDIR)/$(1)/CMakeLists.txt ]; then \
	echo "cmake"; \
elif [ -f $(LIBDIR)/$(1)/configure ] || [ -f $(LIBDIR)/$(1)/Makefile ]; then \
	echo "autotools"; \
elif [ -d $(LIBDIR)/$(1)/.git ]; then \
	echo "submodule"; \
elif ls $(LIBDIR)/$(1)/lib*.a $(LIBDIR)/$(1)/lib*.so 2>/dev/null | head -1; then \
	echo "prebuilt"; \
else \
	echo "header-only"; \
fi)
endef

# Generate build rules for each external library
$(foreach lib,$(EXTERNAL_LIBS),$(eval \
$(lib)_TYPE := $(call DETECT_LIB_TYPE,$(lib)) \
\
$(if $(filter metabuild,$($(lib)_TYPE)), \
	$(lib)/build: \
		@echo "Building METABUILD library: $(lib)" \
		@cd $(LIBDIR)/$(lib) && $$(MAKE) \
		@cp $(LIBDIR)/$(lib)/out/*/lib/*.a $(LNKDIR)/ 2>/dev/null || true \
	CFLAGS += -I$(LIBDIR)/$(lib)/include \
	LDFLAGS += -L$(LNKDIR) -l$(lib), \
\
$(if $(filter cmake,$($(lib)_TYPE)), \
	$(lib)/build: \
		@echo "Building CMake library: $(lib)" \
		@mkdir -p $(LIBDIR)/$(lib)/build \
		@cd $(LIBDIR)/$(lib)/build && cmake -DCMAKE_BUILD_TYPE=Release .. && make \
		@find $(LIBDIR)/$(lib)/build -name "lib*.a" -exec cp {} $(LNKDIR)/ \; \
	CFLAGS += -I$(LIBDIR)/$(lib)/include -I$(LIBDIR)/$(lib) \
	LDFLAGS += -L$(LNKDIR) -l$(lib), \
\
$(if $(filter autotools,$($(lib)_TYPE)), \
	$(lib)/build: \
		@echo "Building Autotools library: $(lib)" \
		@cd $(LIBDIR)/$(lib) && (test -f configure || autoreconf -i) && ./configure --prefix=$(CURDIR)/$(LIBDIR)/$(lib)/install && make && make install \
		@cp $(LIBDIR)/$(lib)/install/lib/lib*.a $(LNKDIR)/ 2>/dev/null || true \
	CFLAGS += -I$(LIBDIR)/$(lib)/install/include -I$(LIBDIR)/$(lib) \
	LDFLAGS += -L$(LNKDIR) -l$(lib), \
\
$(if $(filter submodule,$($(lib)_TYPE)), \
	$(lib)/build: \
		@echo "Initializing submodule: $(lib)" \
		@git submodule update --init --recursive $(LIBDIR)/$(lib) \
		@if [ -f $(LIBDIR)/$(lib)/metabuild.mk ]; then \
			cd $(LIBDIR)/$(lib) && $$(MAKE); \
		elif [ -f $(LIBDIR)/$(lib)/CMakeLists.txt ]; then \
			mkdir -p $(LIBDIR)/$(lib)/build && cd $(LIBDIR)/$(lib)/build && cmake .. && make; \
		elif [ -f $(LIBDIR)/$(lib)/Makefile ]; then \
			cd $(LIBDIR)/$(lib) && make; \
		fi \
		@find $(LIBDIR)/$(lib) -name "lib*.a" -exec cp {} $(LNKDIR)/ \; 2>/dev/null || true \
	CFLAGS += -I$(LIBDIR)/$(lib)/include -I$(LIBDIR)/$(lib) \
	LDFLAGS += -L$(LNKDIR) -l$(lib), \
\
$(if $(filter prebuilt,$($(lib)_TYPE)), \
	$(lib)/build: \
		@echo "Using prebuilt library: $(lib)" \
		@cp $(LIBDIR)/$(lib)/lib*.a $(LNKDIR)/ 2>/dev/null || true \
	$(if $(wildcard $(LIBDIR)/$(lib)/include), \
		CFLAGS += -I$(LIBDIR)/$(lib)/include, \
		CFLAGS += -I$(LIBDIR)/$(lib)) \
	LDFLAGS += -L$(LNKDIR) $(addprefix -l,$(basename $(notdir $(wildcard $(LIBDIR)/$(lib)/lib*.a)))), \
\
	$(lib)/build: \
		@echo "Header-only library: $(lib)" \
	$(if $(wildcard $(LIBDIR)/$(lib)/include), \
		CFLAGS += -I$(LIBDIR)/$(lib)/include, \
		$(if $(wildcard $(LIBDIR)/$(lib)/single_include), \
			CFLAGS += -I$(LIBDIR)/$(lib)/single_include, \
			CFLAGS += -I$(LIBDIR)/$(lib))) \
))))) \
\
all: $(lib)/build \
))

# Meta-target to build all external libraries
.PHONY: external-libs $(foreach lib,$(EXTERNAL_LIBS),$(lib)/build)
external-libs: $(foreach lib,$(EXTERNAL_LIBS),$(lib)/build)

# Debug target to show detection results
debug-external-libs:
	@echo "External libraries detected:"
	@$(foreach lib,$(EXTERNAL_LIBS),echo "	$(lib): $(call DETECT_LIB_TYPE,$(lib))";)
