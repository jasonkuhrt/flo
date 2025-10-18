# Makefile for flo

.PHONY: install uninstall test help

# Install flo functions to Fish config
install:
	@echo "Installing flo..."
	@mkdir -p ~/.config/fish/functions
	@mkdir -p ~/.config/fish/lib
	@cp functions/*.fish ~/.config/fish/functions/
	@cp functions/*.md ~/.config/fish/functions/
	@cp -r lib/cli ~/.config/fish/lib/
	@echo "✓ Installed flo and commands to ~/.config/fish/functions/"
	@echo "✓ Installed CLI framework to ~/.config/fish/lib/cli/"
	@echo "✓ Installed documentation to ~/.config/fish/functions/"
	@echo ""
	@echo "Run 'flo --help' to get started (or just 'flo 123' for an issue)"

# Uninstall flo functions from Fish config
uninstall:
	@echo "Uninstalling flo..."
	@rm -f ~/.config/fish/functions/flo.fish
	@rm -f ~/.config/fish/functions/flo_*.fish
	@rm -f ~/.config/fish/functions/list.fish
	@rm -f ~/.config/fish/functions/rm.fish
	@rm -f ~/.config/fish/functions/prune.fish
	@rm -f ~/.config/fish/functions/flo-*.fish
	@rm -f ~/.config/fish/functions/*.md
	@rm -f ~/.config/fish/functions/gwt.fish
	@rm -f ~/.config/fish/functions/gwt-*.fish
	@rm -rf ~/.config/fish/lib/cli
	@rm -rf ~/.config/fish/flo-docs
	@echo "✓ Uninstalled flo from ~/.config/fish/functions/"
	@echo "✓ Removed CLI framework from ~/.config/fish/lib/cli/"
	@echo "✓ Removed old flo-* and gwt files"
	@echo "✓ Removed documentation"

# Run tests
test:
	@lib/test/cli $(ARGS)

# Allow passing arguments like: make test ARGS="--update"
.PHONY: $(MAKECMDGOALS)
%:
	@:

# Show help
help:
	@echo "flo installation tasks:"
	@echo ""
	@echo "  make install     Install flo functions to ~/.config/fish/functions/"
	@echo "  make uninstall   Remove flo functions from ~/.config/fish/functions/"
	@echo "  make test        Run tests"
	@echo "  make help        Show this help message"
	@echo ""
	@echo "Recommended: Use Fisher instead"
	@echo "  fisher install jasonkuhrt/flo"
