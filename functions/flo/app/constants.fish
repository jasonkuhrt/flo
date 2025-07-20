# Flo Constants
# Define reusable constants used throughout the flo application

# =============================================================================
# Workflow Constants
# =============================================================================

# Special issue identifier for workflows without a GitHub issue
set -g FLO_NO_ISSUE no-issue

# Worktree prefixes
set -g FLO_ISSUE_PREFIX issue/
set -g FLO_NO_ISSUE_PREFIX no-issue/

# =============================================================================
# Git/Branch Constants
# =============================================================================

# Default branch names
set -g FLO_MAIN_BRANCH main
set -g FLO_FALLBACK_BRANCH master
set -g FLO_DEFAULT_REMOTE origin

# =============================================================================
# File and Path Constants
# =============================================================================

# File extensions
set -g FLO_FISH_EXTENSION ".fish"
set -g FLO_MARKDOWN_EXTENSION ".md"

# Claude-related file patterns
set -g FLO_CLAUDE_FILE_PATTERN "CLAUDE_*.md"
set -g FLO_CLAUDE_CONTEXT_PATTERN "*-claude-context.md"
set -g FLO_CLAUDE_LOCAL_FILE "CLAUDE.local.md"

# =============================================================================
# Command Arguments and Flags
# =============================================================================

# GitHub CLI arguments
set -g FLO_GH_STATE_OPEN "--state open"
set -g FLO_GH_DEFAULT_LIMIT "-L 200"

# Common command flags
set -g FLO_HELP_FLAG --help
set -g FLO_HELP_SHORT -h

# =============================================================================
# Output Redirection
# =============================================================================

set -g FLO_STDERR_NULL "2>/dev/null"
set -g FLO_ALL_NULL ">/dev/null 2>&1"
set -g FLO_TO_STDERR ">&2"

# =============================================================================
# Format Strings
# =============================================================================

# Date/time formats
set -g FLO_TIMESTAMP_FORMAT "+%Y%m%d-%H%M%S"

# Regex patterns
set -g FLO_UUID_PATTERN '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'

# =============================================================================
# UI Strings
# =============================================================================

# Choice options
set -g FLO_CHOICE_CONTINUE_WITHOUT_ISSUE "Continue without issue"
set -g FLO_CHOICE_CANCEL Cancel

# Input prompts
set -g FLO_PROMPT_BRANCH_SUFFIX "Enter custom suffix for no-issue/ branch (leave empty for timestamp)"
set -g FLO_PREVIEW_PREFIX "Preview: "
set -g FLO_PLACEHOLDER_SUFFIX my-feature

# Headers
set -g FLO_HEADER_NO_ISSUES "No open issues found"

# Dimensions
set -g FLO_INPUT_WIDTH 50

# =============================================================================
# Error and Exit Codes
# =============================================================================

set -g FLO_CTRL_C_EXIT_CODE 130
