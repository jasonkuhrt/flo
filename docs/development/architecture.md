# Flo Architecture

Internal documentation for flo's code structure and organization.

## Functions Directory Structure

```
functions/
├── flo.fish    # Main entry point
└── flo/        # Private implementation directory
    ├── app/    # Application-specific code
    │   ├── commands/   # Command implementations
    │   ├── helpers/    # Helper functions
    │   └── constants.fish  # Shared constants
    └── lib/    # Domain-agnostic libraries
        └── cli/  # CLI framework
```

## Architecture Principles

- **`flo.fish`**: Main entry point that sets up the environment and sources all necessary files
- **`flo/app/`**: Contains all application-specific code including commands and helpers
- **`flo/lib/`**: Contains reusable libraries like the CLI framework

## Installation Methods

### Production Installation (Fisher)

Fisher always copies files to `~/.config/fish/functions/`, even for local paths. This provides:

- Clean, isolated installations
- Stable snapshots of code
- Standard Fish plugin behavior

### Development Installation (Custom Symlinks)

Our custom `scripts/install-dev.fish` creates symlinks for instant feedback:

- Changes to source files are immediately reflected
- No need to run update commands
- Essential for active development

The function uses Fisher's portable path resolution to find its private directory regardless of installation method.

## CLI Framework

The CLI framework in `flo/lib/cli/` provides:

- Command discovery and dispatch
- Help system generation
- Dependency checking
- Consistent error handling

This allows commands to focus purely on their functionality while the framework handles the boilerplate.
