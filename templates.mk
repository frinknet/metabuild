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

template-list:
	@find $(TPLDIR) -maxdepth 1 -type d -not -path $(TPLDIR) -printf "	%f\n" 2>/dev/null || true

# Suppress unknown targets when using 'new' command
ifeq ($(word 1, $(MAKECMDGOALS)),new)
%:
	@:
endif

.PHONY: template-list new
