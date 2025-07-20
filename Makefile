# Makefile for flo project

.PHONY: docs docs-clean tool-docs install install-dev format check-format pre-commit help

# Generate documentation from help output
docs:
	@./scripts/generate-docs.fish

# Clean generated documentation
docs-clean:
	@echo "Cleaning generated documentation..."
	@rm -rf docs/

# Generate tool documentation for external tools (gitignored)
tool-docs:
	@./scripts/generate-tool-docs.fish

# Install flo using Fisher
install:
	@echo "Installing flo with Fisher..."
	@fisher install jasonkuhrt/flo

# Install flo for development (symlinks)
install-dev:
	@echo "Installing flo for development..."
	@./scripts/install-dev.fish

# Format all files (Fish and Markdown)
format:
	@echo "Formatting all files..."
	@./scripts/format.fish
	@./scripts/format-md.fish

# Check formatting of Fish files
check-format:
	@echo "Checking Fish formatting..."
	@./scripts/check-format.fish

# Install pre-commit hooks
pre-commit:
	@echo "Installing pre-commit hooks..."
	@pre-commit install

# Show help
help:
	@echo "flo project tasks:"
	@echo ""
	@echo "  docs         Generate documentation from --help output"
	@echo "  docs-clean   Remove generated documentation"
	@echo "  tool-docs    Generate tool documentation for external tools (gitignored)"
	@echo "  install      Install flo using Fisher"
	@echo "  install-dev  Install flo for development (symlinks)"
	@echo "  format       Format all files (Fish and Markdown)"
	@echo "  check-format Check if Fish files are properly formatted"
	@echo "  pre-commit   Install pre-commit hooks for formatting"
	@echo "  help         Show this help message"
	@echo ""
	@echo "Generated documentation will be in docs/"