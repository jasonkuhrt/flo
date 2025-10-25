# Logging functions for flo
# Provides consistent, colorful output across all commands
# All functions use __flo_log_ prefix to avoid namespace pollution
#
# Output streams:
#   - Info/warn/error → stderr (diagnostic logging)
#   - Success → stdout (user-facing results)
#
# All functions support optional tip as 2nd argument

# Info - Blue bullet for progress/informational messages
function __flo_log_info --description "Print info message with optional tip"
    set -l message $argv[1]
    set -l tip $argv[2] # optional

    echo "  $__flo_c_blue•$__flo_c_reset $message" >&2
    if test -n "$tip"
        echo "    $tip" >&2
    end
end

# Info (dim) - Dimmed bullet for subtle/secondary information
function __flo_log_info_dim --description "Print dimmed info message with optional tip"
    set -l message $argv[1]
    set -l tip $argv[2] # optional

    echo "  $__flo_c_dim•$__flo_c_reset $message" >&2
    if test -n "$tip"
        echo "    $tip" >&2
    end
end

# Success - Green checkmark for successful operations
function __flo_log_success --description "Print success message with optional tip"
    set -l message $argv[1]
    set -l tip $argv[2] # optional

    echo "  $__flo_c_green✓$__flo_c_reset $message"
    if test -n "$tip"
        echo "    $tip"
    end
end

# Warning - Yellow warning symbol for non-fatal issues
function __flo_log_warn --description "Print warning message with optional tip"
    set -l message $argv[1]
    set -l tip $argv[2] # optional

    echo "  $__flo_c_yellow⚠$__flo_c_reset $message" >&2
    if test -n "$tip"
        echo "    $tip" >&2
    end
end

# Error - Red X for errors
function __flo_log_error --description "Print error message with optional tip"
    set -l message $argv[1]
    set -l tip $argv[2] # optional

    echo "  $__flo_c_red✗ Error:$__flo_c_reset $message" >&2
    if test -n "$tip"
        echo "    $tip" >&2
    end
end
