# Makefile for flo project

.PHONY: docs docs-clean install install-dev uninstall help

# Generate documentation from help output
docs:
	@echo "📝 Generating documentation..."
	@./scripts/generate-docs.fish

# Clean generated documentation
docs-clean:
	@echo "🧹 Cleaning generated documentation..."
	@rm -rf docs/

# Install flo (copies files)
install:
	@echo "📦 Installing flo..."
	@./install.fish

# Install flo for development (symlinks)
install-dev:
	@echo "🔧 Installing flo for development..."
	@./install-dev.fish

# Uninstall flo
uninstall:
	@echo "🗑️  Uninstalling flo..."
	@./uninstall.fish

# Show help
help:
	@echo "flo project tasks:"
	@echo ""
	@echo "  docs        Generate documentation from --help output"
	@echo "  docs-clean  Remove generated documentation"
	@echo "  install     Install flo (copies files)"
	@echo "  install-dev Install flo for development (symlinks)"
	@echo "  uninstall   Remove flo from system"
	@echo "  help        Show this help message"
	@echo ""
	@echo "Generated documentation will be in docs/"