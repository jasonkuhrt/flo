# Help documentation functions for flo

function __flo_help --description "Show help for flo command"
    echo "flo - GitHub Issue Flow Tool"
    echo ""
    echo "Usage: flo <command> [arguments]"
    echo "       flo <issue-number> [--zed] [--claude]"
    echo ""
    echo "Core Commands:"
    echo "  <number>                     Work on GitHub issue (create/navigate to worktree)"
    echo "  create, c <name> [<branch>]  Create a new worktree"
    echo "  rm, remove, r <name>         Remove a worktree"
    echo "  cd <name>                    Change to worktree directory"
    echo "  cd <project>/<name>          Change to worktree in another project"
    echo ""
    echo "Workflow Commands:"
    echo "  next, n [<number>]           Transition to next issue (context-aware)"
    echo "  pr [create|open|status]      Manage pull requests"
    echo "  issues, i                    List repository issues with worktree status"
    echo "  sync                         Update caches and clean merged PRs"
    echo "  claude <name>                Start Claude in worktree with context"
    echo "  zed, z [<name>]              Open worktree in Zed editor"
    echo ""
    echo "Browse Commands:"
    echo "  list, ls, l [--all]          List worktrees (contextual defaults)"
    echo "  status, s [--project <name>] Show detailed status (contextual)"
    echo "  projects, p                  List all projects with worktrees"
    echo ""
    echo "Options:"
    echo "  --help, help, h              Show this help"
    echo "  --all                        Show all projects (for list/status)"
    echo "  --project <name>             Filter by project (all = all projects)"
    echo "  --zed                        Open in Zed editor"
    echo "  --claude                     Start Claude with context"
    echo ""
    echo "Environment Variables:"
    echo "  FLO_BASE_DIR      Root directory for all projects (default: ~/worktrees)"
    echo "  FLO_PROJECT_NAME  Override auto-detected project name"
    echo "  FLO_BRANCH_PREFIX Branch prefix for new worktrees (default: claude/)"
    echo "  FLO_ISSUE_PREFIX  Issue branch prefix (default: issue/)"
    echo "  FLO_CACHE_TTL     Cache lifetime in minutes (default: 30)"
    echo "  FLO_AUTO_CLOSE_PR Auto-close PR on worktree removal (default: true)"
    echo "  FLO_CLAUDE_PROMPT Custom Claude prompt template"
    echo ""
    echo "Examples:"
    echo "  flo 123                      Work on issue #123"
    echo "  flo 123 --zed --claude       Work on issue #123, open Zed and Claude"
    echo "  flo create feature-x         Create worktree (uses existing branch or creates new)"
    echo "  flo create feature-x main    Create worktree with new branch from 'main'"
    echo "  flo cd project/feature       Navigate to worktree in another project"
    echo "  flo list                     List worktrees (current project or all)"
    echo "  flo status --project all     Show status across all projects"
    echo "  flo pr create                Create PR for current worktree"
    echo ""
    echo "For help on specific commands, use: flo <command> --help"
end

function __flo_help_claude --description "Show help for claude command"
    echo "flo claude - Start Claude Code with worktree context"
    echo ""
    echo "Usage: flo claude [<worktree-name>]"
    echo "       flo claude <project>/<worktree-name>"
    echo ""
    echo "Description:"
    echo "  Opens Claude Code in the specified worktree with context about the current"
    echo "  issue, PR status, and project information. For issue worktrees, it includes"
    echo "  the issue details and generates an optimized prompt."
    echo ""
    echo "  When run without arguments inside a flo worktree, it uses the current worktree."
    echo ""
    echo "Arguments:"
    echo "  <worktree-name>          Name of the worktree in current project (optional)"
    echo "  <project>/<name>         Worktree in a specific project"
    echo ""
    echo "Context Files:"
    echo "  CLAUDE.local.md          Human-readable context for Claude"
    echo "  .flo/cache/issue.json    Full issue data (for issue worktrees)"
    echo "  .flo/cache/comments.json Issue comments (for issue worktrees)"
    echo ""
    echo "Examples:"
    echo "  flo claude               Start Claude in current worktree"
    echo "  flo claude issue/123     Start Claude for issue #123"
    echo "  flo claude feature-x     Start Claude for feature worktree"
    echo "  flo claude proj/feat     Start Claude for worktree in another project"
    echo ""
    echo "Environment:"
    echo "  FLO_CLAUDE_PROMPT        Custom prompt template with {{issue_number}} and {{issue_title}}"
end

function __flo_help_create --description "Show help for create command"
    echo "flo create - Create a new worktree"
    echo ""
    echo "Usage: flo create <name> [<source-branch>]"
    echo ""
    echo "Description:"
    echo "  Creates a new Git worktree with smart branch detection. If a branch exists"
    echo "  locally or remotely, it will be used. Otherwise, a new branch is created."
    echo ""
    echo "Arguments:"
    echo "  <name>              Worktree name (also used as branch name with prefix)"
    echo "  <source-branch>     Optional: Create new branch from this source"
    echo ""
    echo "Branch Naming:"
    echo "  - Regular worktrees: \$FLO_BRANCH_PREFIX<name> (default: claude/<name>)"
    echo "  - Issue worktrees: issue/<number> (when name matches issue pattern)"
    echo ""
    echo "Examples:"
    echo "  flo create feature-x        Use existing branch or create from HEAD"
    echo "  flo create feature-x main   Create new branch from main"
    echo "  flo create issue/123        Create issue worktree (special naming)"
end

function __flo_help_list --description "Show help for list command"
    echo "flo list - List worktrees"
    echo ""
    echo "Usage: flo list [--all]"
    echo ""
    echo "Description:"
    echo "  Lists worktrees with contextual defaults:"
    echo "  - In a git repo: Shows current project only"
    echo "  - Outside git repo: Shows all projects"
    echo ""
    echo "Options:"
    echo "  --all    Show worktrees across all projects"
    echo ""
    echo "Output:"
    echo "  → marker indicates current worktree"
    echo "  Shows branch name for each worktree"
    echo "  Groups by project when showing all"
end

function __flo_help_status --description "Show help for status command"
    echo "flo status - Show detailed status information"
    echo ""
    echo "Usage: flo status [--project <name>]"
    echo ""
    echo "Description:"
    echo "  Shows contextual status information:"
    echo "  - In a worktree: Detailed worktree status"
    echo "  - In main repo: All project worktrees"
    echo "  - Outside git: Must specify --project"
    echo ""
    echo "Options:"
    echo "  --project <name>    Show status for specific project"
    echo "  --project all       Show status across all projects"
    echo ""
    echo "Worktree Status Includes:"
    echo "  - Branch information and sync status"
    echo "  - Issue details (for issue worktrees)"
    echo "  - PR status and review state"
    echo "  - Git status summary"
end

function __flo_help_pr --description "Show help for pr command"
    echo "flo pr - Manage pull requests"
    echo ""
    echo "Usage: flo pr [subcommand]"
    echo ""
    echo "Subcommands:"
    echo "  create, c    Create a new pull request"
    echo "  open, o      Open PR in browser (creates if needed)"
    echo "  status, s    Show PR status for current branch"
    echo "  list, l      List all open PRs in repository"
    echo ""
    echo "Default: Shows status if no subcommand given"
    echo ""
    echo "Examples:"
    echo "  flo pr              Show current branch PR status"
    echo "  flo pr create       Create PR with smart defaults"
    echo "  flo pr open         Open PR in browser"
end

function __flo_help_remove --description "Show help for remove command"
    echo "flo remove - Remove a worktree"
    echo ""
    echo "Usage: flo rm <name>"
    echo "       flo remove <name>"
    echo ""
    echo "Description:"
    echo "  Removes a Git worktree with PR awareness. If the worktree has an open PR,"
    echo "  you'll be prompted to close it (configurable via FLO_AUTO_CLOSE_PR)."
    echo ""
    echo "Arguments:"
    echo "  <name>              Worktree name in current project"
    echo "  <project>/<name>    Worktree in specific project"
    echo ""
    echo "Options:"
    echo "  Multiple worktrees can be specified"
    echo ""
    echo "Environment:"
    echo "  FLO_AUTO_CLOSE_PR   Prompt to close associated PRs (default: true)"
end
