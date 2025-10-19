# Simple demo showing flo creating a worktree from GitHub issue
# Uses issue #17 from jasonkuhrt/flo (test fixture)

Output build/flo-simple.png

Set Shell fish
Set FontSize 18
Set Width 1400
Set Height 900
Set Theme "Catppuccin Mocha"
Set Padding 20

# Navigate to the flo repo (assuming we're running from demos/)
Type "cd .."
Enter
Sleep 500ms

# Run flo with issue number
Type "flo 17"
Enter
Sleep 4s

# Hide prompt and take screenshot
Hide
Screenshot build/flo-simple.png
