# Makefile for flo

.PHONY: install uninstall test help docs demos

# Install flo using Fisher (recommended - same as users)
install:
	@echo "Installing flo via Fisher..."
	@fish -c "if not type -q fisher; \
		echo 'Error: Fisher not found. Install it first:'; \
		echo '  curl -sL https://git.io/fisher | source && fisher install jorgebucaran/fisher'; \
		exit 1; \
	end; \
	fisher install $(PWD)"
	@echo ""
	@echo "✓ Installed flo via Fisher"
	@echo ""
	@echo "Run 'flo --help' to get started (or just 'flo 123' for an issue)"

# Uninstall flo using Fisher
uninstall:
	@echo "Uninstalling flo via Fisher..."
	@fish -c "if type -q fisher; \
		fisher remove jasonkuhrt/flo; \
	else; \
		echo 'Fisher not found - cannot uninstall'; \
		exit 1; \
	end"
	@echo "✓ Uninstalled flo via Fisher"

# Run tests
test:
	@lib/test/cli $(ARGS)

# Generate README reference section from markdown files
docs:
	@./scripts/generate-readme-reference.fish

# Generate demo screenshots and animations
demos:
	@cd demos && ./generate.sh

# Allow passing arguments like: make test ARGS="--update"
.PHONY: $(MAKECMDGOALS)
%:
	@:

# Show help
help:
	@echo "flo development tasks:"
	@echo ""
	@echo "  make install     Install flo via Fisher from local directory"
	@echo "  make uninstall   Uninstall flo via Fisher"
	@echo "  make test        Run tests"
	@echo "  make docs        Generate README reference section"
	@echo "  make demos       Generate demo screenshots (requires: brew install vhs)"
	@echo "  make help        Show this help message"
	@echo ""
	@echo "Note: 'make install' uses Fisher to ensure we test the same installation"
	@echo "      path as users. Requires Fisher to be installed first."
