# templates.mk - (c) 2025 FRINKnet & Friends - 0BSD

# Extract positional arguments (new [tpl] [name])
new:
	@$(eval tpl := $(word 2, $(MAKECMDGOALS)))
	@$(eval name := $(word 3, $(MAKECMDGOALS)))
	@test -n "$(tpl)" || (echo "Usage: make new [template] [name]"; exit 1)
	@test -n "$(name)" || (echo "Usage: make new [template] [name]"; exit 1)
	@test -d "$(TPLDIR)/$(tpl)" || (echo "Template $(tpl) not found"; exit 1)
	@mkdir -p "$(SRCDIR)/$(name)"
	@echo "Creating $(SRCDIR)/$(name) from template $(tpl)..."
	@for file in $(TPLDIR)/$(tpl)/*; do \
		base=$$(basename "$$file"); \
		target="$(SRCDIR)/$(name)/$${base//TEMPLATE/$(name)}"; \
		sed 's/{{NAME}}/$(name)/g; s/{{UPPER_NAME}}/$(shell echo $(name) | tr a-z A-Z)/g; s/{{LOWER_NAME}}/$(shell echo $(name) | tr A-Z a-z)/g' \
			"$$file" > "$$target"; \
		echo "	$$target"; \
	done

template-list:
	@echo "Available templates:"
	@find $(TPLDIR) -maxdepth 1 -type d -not -path $(TPLDIR) -printf "	%f\n" 2>/dev/null || true

# Suppress unknown targets when using 'new' command
ifeq ($(word 1, $(MAKECMDGOALS)),new)
%:
	@:
endif

.PHONY: template-list new
