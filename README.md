# Flo

GitHub issues → Git worktrees → Claude context

Create worktrees from GitHub issues with automatic Claude setup.

**Without Flo:**

```fish
git worktree add ../proj_feat-123-title -b feat/123-title
cd ../proj_feat-123-title
cp -r ../proj/.serena/cache ./serena/cache  # Copy Serena cache (if present)
pnpm install
# Tell Claude about the issue manually upon your next session.
```

**With flo:**

```fish
flo 123
```

## Installation

### Fisher (Recommended)

```fish
fisher install jasonkuhrt/flo
```

<details>
<summary>Local Development</summary>

For development, install from your local clone:

```fish
git clone https://github.com/jasonkuhrt/flo.git ~/projects/flo
cd ~/projects/flo
make install  # Uses Fisher to install from PWD
```

This ensures you test the same installation path as users.

</details>

<details>
<summary>Requirements</summary>

- **Fish shell** (3.0+)
- **git** and **GitHub CLI** (`gh`) - must be authenticated (`gh auth login`)
- **jq** - JSON parser
  - macOS: `brew install jq`
- **pnpm** - for auto-installing dependencies (optional but recommended)

</details>

<!-- REFERENCE_START -->
## Reference

Run any command with \`--help\` for detailed help.

### `flo`

```


flo                                                                             
                                                                                
  Create worktree from branch or GitHub issue (shorthand for  flo start )       
                                                                                
                                                                                
                                                                                
USAGE                                                                           
                                                                                
    flo [<issue-or-branch>]                                                     
                                                                                
                                                                                
                                                                                
COMMANDS                                                                        
                                                                                
 Name      Description                                                          
                                                                                
  end      End your work by removing a worktree and optionally managing the     
           PR (alias: rm)                                                       
                                                                                
  list     List all git worktrees with branches and paths                       
                                                                                
  prune    Clean up Git metadata for manually deleted worktrees                 
                                                                                
  rm       Safely remove a git worktree by branch name or issue number          
                                                                                
  start    Start work by creating a worktree from an issue or branch            
                                                                                
                                                                                
                                                                                
                                                                                
POSITIONAL PARAMETERS                                                           
                                                                                
 Param                 Description                                              
                                                                                
  <issue-or-branch>    GitHub issue number or branch name (optional - shows     
                       interactive picker if omitted)                           
                                                                                
                                                                                
                                                                                
                                                                                
WORKTREE ORGANIZATION                                                           
                                                                                
  Flo creates worktrees as siblings to your main project:                       
  ~/projects/myproject/                      (main repo on main branch)         
  ~/projects/myproject_feat-123-add-auth/    (worktree for feat/123-add-auth)   
  ~/projects/myproject_fix-456-bug-fix/      (worktree for fix/456-bug-fix)     
                                                                                
  Running flo multiple times for the same branch is safe - it updates Claude    
  context without recreating the worktree.                                      
                                                                                
                                                                                
                                                                                
INTERACTIVE SELECTION                                                           
                                                                                
  When you run  flo  with no arguments:                                         
                                                                                
1. Fetches up to 100 open issues from GitHub                                    
2. Shows interactive picker:                                                    
    •  → Custom branch...  option at top for branch mode                        
    • Uses  gum filter  (fuzzy search) for >10 issues                           
    • Uses  gum choose  (simple list) for ≤10 issues                            
3. Creates worktree for selected issue (or custom branch)                       
                                                                                
  Requirements:                                                                 
                                                                                
• gum: https://github.com/charmbracelet/gum (install with:  brew install gum )  
• gh CLI: https://cli.github.com (install with:  brew install gh )              
                                                                                
  Fallback: If gum or gh are not installed, shows error with install            
  instructions.                                                                 
                                                                                
                                                                                
                                                                                
BRANCH MODE                                                                     
                                                                                
  When you run  flo <branch-name> :                                             
                                                                                
1. Creates worktree with the exact branch name you provide                      
2. No GitHub integration (no issue fetching, no auto-assign)                    
3. No Claude context files generated                                            
4. Perfect for: experiments, quick fixes, non-issue work                        
                                                                                
  Examples:                                                                     
  flo feat/experiment        # Creates feat/experiment branch                   
  flo fix/quick-bug          # Creates fix/quick-bug branch                     
  flo spike/new-tech         # Creates spike/new-tech branch                    
                                                                                
                                                                                
                                                                                
ISSUE MODE                                                                      
                                                                                
  When you run  flo 123 :                                                       
                                                                                
1. Fetches issue #123 from GitHub                                               
2. Auto-assigns issue to you                                                    
3. Creates branch with smart prefix:                                            
feat/123- for features                                                          
fix/123- for bugs                                                               
docs/123- for documentation                                                     
refactor/123- for refactoring                                                   
chore/123- for chores                                                           
4. Creates worktree: ../_/                                                      
5. Copies Serena MCP cache if present (speeds up symbol indexing)               
6. Generates .claude/issue.md with issue context                                
7. Runs pnpm install                                                            
8. Ready to code!                                                               
                                                                                
                                                                                
                                                                                
CLAUDE INTEGRATION                                                              
                                                                                
  When you create a worktree from an issue, flo:                                
                                                                                
1. Generates  .claude/issue.md  with issue context                              
2. Adds  .claude/issue.md  to  .gitignore                                       
3. Auto-adds  @.claude/issue.md  import to project's CLAUDE.md (if exists)      
                                                                                
  The @-import is added automatically:                                          
                                                                                
• Root  CLAUDE.md  → adds  @.claude/issue.md                                    
•  .claude/CLAUDE.md  → adds  @issue.md  (relative path)                        
• No CLAUDE.md → silently skips                                                 
• Already has import → idempotent, skips                                        
                                                                                
  .claude/issue.md (per-issue):                                                 
                                                                                
• Contains GitHub issue context (title, description, comments)                  
• Overwritten each run with fresh issue data                                    
• Gitignored - never committed                                                  
• Worktree-specific                                                             
                                                                                
                                                                                
                                                                                
SERENA MCP INTEGRATION                                                          
                                                                                
  If you're using Serena MCP (github.com/oraios/serena) for semantic code       
  analysis:                                                                     
                                                                                
• Flo automatically copies .serena/cache/ to new worktrees                      
• Avoids re-indexing symbols (can save minutes on large projects)               
• Only happens when creating new worktrees (not when reusing)                   
• Requires .serena/cache/ to exist in your main project                         
• Pre-index once: uvx --from git+https://github.com/oraios/serena serena project
index                                                                           
                                                                                
                                                                                
                                                                                
EXAMPLES                                                                        
                                                                                
  Interactive issue selection (requires gum):                                   
                                                                                
    flo                                                                         
                                                                                
  Create from GitHub issue:                                                     
                                                                                
    flo 123                                                                     
                                                                                
  Create from GitHub issue (# is optional):                                     
                                                                                
    flo #123                                                                    
                                                                                
  Create from branch name:                                                      
                                                                                
    flo feat/new-feature                                                        
                                                                                
                                                                                
                                                                                
EXIT CODES                                                                      
                                                                                
 #     Description                                                              
                                                                                
  0    Success                                                                  
  1    Error - GitHub API failure, worktree creation failed, or missing         
       dependencies                                                             

```

### `flo list`

```


flo list                                                                        
                                                                                
  List all git worktrees with branches and paths                                
                                                                                
                                                                                
                                                                                
USAGE                                                                           
                                                                                
    flo list [OPTIONS]                                                          
                                                                                
                                                                                
                                                                                
NAMED PARAMETERS                                                                
                                                                                
 Param         Description                                                      
                                                                                
  --project    Project to list worktrees for (name or path). Names resolved     
               via ~/.config/flo/settings.json                                  
                                                                                
                                                                                
  Shows all worktrees with their paths, branches, and commits.                  
                                                                                
                                                                                
                                                                                
EXAMPLES                                                                        
                                                                                
  Show all worktrees for current project:                                       
                                                                                
    flo list                                                                    
                                                                                
  List worktrees for different project (by name):                               
                                                                                
    flo list --project backend                                                  
                                                                                
  List worktrees for project by path:                                           
                                                                                
    flo list --project ~/projects/api                                           
                                                                                
                                                                                
                                                                                
EXIT CODES                                                                      
                                                                                
 #                                       Description                            
                                                                                
  0                                      Success                                

```

### `flo rm`

```


flo end                                                                         
                                                                                
  End your work by removing a worktree and optionally managing the PR           
                                                                                
                                                                                
                                                                                
USAGE                                                                           
                                                                                
    flo end [OPTIONS] [<branch-name-or-issue>]                                  
                                                                                
                                                                                
                                                                                
POSITIONAL PARAMETERS                                                           
                                                                                
 Param                      Description                                         
                                                                                
  <branch-name-or-issue>    Branch name, issue number, or worktree directory    
                            name to remove (optional - defaults to current      
                            worktree)                                           
                                                                                
                                                                                
                                                                                
                                                                                
NAMED PARAMETERS                                                                
                                                                                
 Param            Description                                                   
                                                                                
  --resolve       Resolution mode: 'success' (merge PR, default) or 'abort'     
                  (close PR without merging)                                    
                                                                                
  --force   -f    Skip all validations (PR checks, clean worktree, synced       
                  branch)                                                       
                                                                                
  --ignore        Ignore specific operations: 'pr' (skip PR operations) or      
                  'worktree' (skip worktree/branch cleanup)                     
                                                                                
  --yes   -y      Skip confirmation prompt (non-interactive mode)               
                                                                                
  --dry           Show what would be done without making any changes            
                                                                                
  --project       Project to operate on (name or path). Names resolved via      
                  ~/.config/flo/settings.json                                   
                                                                                
                                                                                
                                                                                
                                                                                
ABOUT                                                                           
                                                                                
  Safely ends your work on a branch by managing the full cleanup lifecycle: PR  
  resolution, worktree removal, branch deletion, and main branch                
  synchronization.                                                              
                                                                                
  The command follows a task-based model where operations can be selectively    
  included or excluded via flags.                                               
                                                                                
                                                                                
                                                                                
CORE CONCEPT: TASK-BASED CLEANUP                                                
                                                                                
   flo end  executes a series of tasks to cleanly finish your work. The exact   
  tasks depend on the resolution mode and can be modified with flags.           
                                                                                
### Success Path ( --resolve success , default)                                 
                                                                                
  Tasks executed:                                                               
                                                                                
1. Validate: PR checks passing (if PR exists)                                   
2. Validate: Worktree clean (no uncommitted changes)                            
3. Validate: Branch synced (no unpushed commits)                                
4. Merge PR (via  gh pr merge --squash , then  git push origin --delete <branch>
)                                                                               
5. Delete worktree                                                              
6. Delete local branch                                                          
7. Sync main branch ( git pull origin main  in main repo)                       
8. Navigate to main repo                                                        
                                                                                
  Modifiers:                                                                    
                                                                                
•  --force : Skip tasks 1-3 (all validations)                                   
•  --ignore pr : Skip tasks 1, 4, 7                                             
•  --ignore worktree : Skip tasks 2-3, 5-6                                      
• If no PR exists: Skip tasks 1, 4, 7 automatically                             
• If PR already merged: Skip tasks 4, 7 automatically (idempotent)              
                                                                                
### Abort Path ( --resolve abort )                                              
                                                                                
  Tasks executed:                                                               
                                                                                
1. Close PR without merging (via  gh pr close )                                 
2. Delete worktree                                                              
3. Delete local branch                                                          
4. Navigate to main repo                                                        
                                                                                
  Modifiers:                                                                    
                                                                                
•  --ignore pr : Skip task 1                                                    
•  --ignore worktree : Skip tasks 2-3                                           
• No validations (you're abandoning work, dirty state is acceptable)            
                                                                                
                                                                                
                                                                                
VALIDATIONS (SUCCESS PATH ONLY)                                                 
                                                                                
  The following validations prevent accidental data loss and ensure clean       
  merges. All can be bypassed with  --force :                                   
                                                                                
1. PR checks passing: If a PR exists for the branch, all GitHub status checks   
must be in SUCCESS state                                                        
2. Worktree clean:  git status --porcelain  must return empty (no uncommitted   
changes)                                                                        
3. Branch synced: No unpushed commits (checked via  git rev-list @{u}..HEAD )   
                                                                                
                                                                                
                                                                                
EDGE CASES                                                                      
                                                                                
• No PR exists: PR-related tasks are skipped gracefully (no error)              
• PR already merged: Merge task skipped gracefully (idempotent operation)       
• PR already closed: Close task skipped gracefully (idempotent operation)       
•  --ignore pr --ignore worktree : Does nothing, exits successfully (all tasks  
subtracted)                                                                     
• Remote vs local:  --ignore worktree  only affects LOCAL state (worktree +     
local branch). Remote branch is still deleted via PR merge/close.               
                                                                                
                                                                                
                                                                                
EXAMPLES                                                                        
                                                                                
  Interactive cleanup: merge PR (if checks pass), delete worktree/branch, sync  
  main:                                                                         
                                                                                
    flo end                                                                     
                                                                                
  Explicit success resolution (default behavior):                               
                                                                                
    flo end --resolve success                                                   
                                                                                
  Abandon work: close PR without merging, delete worktree/branch:               
                                                                                
    flo end --resolve abort                                                     
                                                                                
  End work on issue #1320:                                                      
                                                                                
    flo end 1320                                                                
                                                                                
  End work by branch name:                                                      
                                                                                
    flo end feat/123-add-auth                                                   
                                                                                
  Skip validations (dirty worktree, failing PR checks, unpushed commits):       
                                                                                
    flo end --force                                                             
                                                                                
  Clean up locally without touching the PR:                                     
                                                                                
    flo end --ignore pr                                                         
                                                                                
  Merge/close PR but keep local worktree and branch:                            
                                                                                
    flo end --ignore worktree                                                   
                                                                                
  Delete worktree/branch locally but don't close the PR:                        
                                                                                
    flo end --resolve abort --ignore pr                                         
                                                                                
  Non-interactive mode (for automation):                                        
                                                                                
    flo end --yes                                                               
                                                                                
  Preview what would be done without executing:                                 
                                                                                
    flo end --dry                                                               
                                                                                
  Force cleanup without confirmation:                                           
                                                                                
    flo end --force --yes                                                       
                                                                                
  End work in a different project:                                              
                                                                                
    flo end --project backend                                                   
                                                                                
                                                                                
                                                                                
EXIT CODES                                                                      
                                                                                
 #                               Description                                    
                                                                                
  0                              Success                                        
  1                              Error - worktree not found or removal failed   

```

### `flo prune`

```


flo prune                                                                       
                                                                                
  Clean up Git metadata for manually deleted worktrees                          
                                                                                
                                                                                
                                                                                
USAGE                                                                           
                                                                                
    flo prune [OPTIONS]                                                         
                                                                                
                                                                                
                                                                                
NAMED PARAMETERS                                                                
                                                                                
 Param         Description                                                      
                                                                                
  --project    Project to prune worktrees for (name or path). Names resolved    
               via ~/.config/flo/settings.json                                  
                                                                                
                                                                                
                                                                                
                                                                                
ABOUT                                                                           
                                                                                
  Use this if you deleted with  rm -rf  instead of  flo rm .                    
                                                                                
                                                                                
                                                                                
EXAMPLES                                                                        
                                                                                
  Clean up metadata for current project:                                        
                                                                                
    flo prune                                                                   
                                                                                
  Prune worktrees for different project (by name):                              
                                                                                
    flo prune --project backend                                                 
                                                                                
                                                                                
                                                                                
EXIT CODES                                                                      
                                                                                
 #                                       Description                            
                                                                                
  0                                      Success                                

```
<!-- REFERENCE_END -->
## Development

See [DEVELOPMENT.md](DEVELOPMENT.md) for development instructions.
