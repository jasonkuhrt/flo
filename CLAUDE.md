# Project CLAUDE.md

## CRITICAL: Local Context Files

If `.claude/CLAUDE.local.md` exists, read it immediately. It contains work-specific context (GitHub issues, PRs, etc.) and takes precedence over this file.

## Project Conventions

### Logging

**CRITICAL: Always use the logging library for user-facing output**

- **NEVER use raw `echo` with emojis/colors** - Use the logging functions instead
- **Import the logging library** in all command files:
  ```fish
  set -l flo_dir (dirname (status --current-filename))
  source "$flo_dir/__flo_lib_log.fish"
  ```

**Available logging functions:**

- `__flo_log_info "message"` - Blue • for progress/informational messages (→ stderr)
- `__flo_log_info_dim "message"` - Dim • for subtle/secondary info (→ stderr)
- `__flo_log_success "message"` - Green ✓ for successful operations (→ stdout)
- `__flo_log_warn "message"` - Yellow ⚠ for warnings (→ stderr)
- `__flo_log_error "message"` - Red ✗ Error: for errors (→ stderr)

All functions support optional tip as 2nd argument:
```fish
__flo_log_error "Operation failed" "Try using --force flag"
```

**Inline color formatting:**
You can use global color variables in messages:
```fish
__flo_log_info "Creating branch: $__flo_c_cyan$branch_name$__flo_c_reset"
```

**Available color variables:**
- `$__flo_c_blue`, `$__flo_c_green`, `$__flo_c_yellow`, `$__flo_c_red`
- `$__flo_c_cyan`, `$__flo_c_dim`, `$__flo_c_reset`

**Output streams:**
- Info/warn/error → stderr (diagnostic logging)
- Success → stdout (user-facing results)
