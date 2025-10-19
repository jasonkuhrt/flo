# Flo Demo Screenshot

Generated terminal screenshot using [VHS](https://github.com/charmbracelet/vhs).

## Installation

```bash
brew install vhs
```

## Generate Screenshot

```bash
# From project root
make demos

# Or from this directory
./generate.sh

# Or manually
vhs demo-simple.tape
```

## Generated Files

Screenshot is saved to `build/flo-simple.png` showing `flo 17` creating a worktree from GitHub issue #17.

## Customization

Edit `demo-simple.tape` to customize:
- Font size: `Set FontSize 18`
- Dimensions: `Set Width 1400` / `Set Height 900`
- Theme: `Set Theme "Catppuccin Mocha"` (or "Dracula", "Nord", etc.)
- Padding: `Set Padding 20`

See [VHS documentation](https://github.com/charmbracelet/vhs#vhs-command-reference) for all options.
