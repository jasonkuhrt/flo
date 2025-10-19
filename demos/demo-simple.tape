# Simple demo showing flo creating a worktree from GitHub issue
# Uses issue #17 from jasonkuhrt/flo (test fixture)

Output build/flo-simple.png

# All Set directives must come first
Set Shell fish
Set FontSize 18
Set Width 1000
Set Height 600
Set Theme "TokyoNight"
Set Padding 20
Set BorderRadius 10
Set WindowBar Rings
Set WindowBarSize 40
Set Margin 40
Set MarginFill "#2A2E3A"

# Environment variables
Env VHS_DEMO "1"

# Wait for shell to load
Sleep 500ms
Hide

# Navigate to flo directory
Type "cd /Users/jasonkuhrt/projects/jasonkuhrt/flo"
Enter

# Source flo (already installed in system)
Type "source ~/.config/fish/functions/flo.fish"
Enter

# Clear screen to start fresh
Type "clear"
Enter
Sleep 500ms

# Show the terminal again
Show

# Run flo command
Type "flo 17"
Enter
Sleep 5s

# Hide the trailing prompt and take screenshot
Hide
Screenshot build/flo-simple.png
