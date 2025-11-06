# templates.mk - (c) 2025 FRINKnet & Friends - 0BSD

# Template usage
template-usage:
	@echo "  TEMPLATES:"
	@echo
	@echo "    new [template] [name]  Create from template"
	@echo "    templates              List available templates"
	@echo

# Template info
template-info:
	@$(if $(wildcard $(TPLDIR)),echo -e "\n=== AVAILABLE TEMPLATES ===n";)
	@find $(TPLDIR) -maxdepth 1 -type d -not -path $(TPLDIR) -printf "	%f\n" 2>/dev/null || true

# Template missing
template-missing:
	@echo "  Template not found."

#show avialable templates
templates: respond template-info

# New module from template
new-command:
	# Extract positional arguments (new [tpl] [name])
	@$(eval tpl := $(word 2, $(MKCOMMAND)))
	@$(eval name := $(word 3, $(MKCOMMAND)))
	@test -n "$(tpl)" || ($(MAKE) respond template-usage; exit 1)
	@test -n "$(name)" || ($(MAKE) respond template-usage; exit 1)
	@test -d "$(TPLDIR)/$(tpl)" ||($(MAKE) respond template-missing; exit 1)
	@mkdir -p "$(SRCDIR)/$(name)"
	@echo "Creating $(SRCDIR)/$(name) from template $(tpl)..."
	@for file in $(TPLDIR)/$(tpl)/*; do \
		base=$$(basename "$$file"); \
		target="$(SRCDIR)/$(name)/$${base//TEMPLATE/$(name)}"; \
		sed 's/{{NAME}}/$(name)/g; s/{{UPPER_NAME}}/$(shell echo $(name) | tr a-z A-Z)/g; s/{{LOWER_NAME}}/$(shell echo $(name) | tr A-Z a-z)/g' \
			"$$file" > "$$target"; \
		echo "	$$target"; \
	done
	@exit 0

.PHONY: template-info template-usage template-missing templates new-command
