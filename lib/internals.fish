# Internal helper functions for flo
# These are not exposed as commands but used by flo functions
# All functions use __flo_ prefix to avoid namespace pollution

# Get the path to the global tracking file
function __flo_internal_config_file
    echo ~/.flo/worktrees.json
end

# Initialize the config file if it doesn't exist
function __flo_internal_config_init
    set -l config_file (__flo_internal_config_file)
    mkdir -p (dirname $config_file)
    if not test -f $config_file
        echo '{}' >$config_file
    end
end

# Get issue number for a worktree path
# Usage: __flo_internal_config_get_issue /path/to/worktree
function __flo_internal_config_get_issue
    set -l worktree_path $argv[1]
    set -l config_file (__flo_internal_config_file)

    if not test -f $config_file
        echo -
        return
    end

    jq -r --arg path "$worktree_path" '.[$path].issue // "-"' $config_file
end

# Store worktree metadata (issue number and branch)
# Usage: __flo_internal_config_set /path/to/worktree 1320 "feat/1320-title"
function __flo_internal_config_set
    set -l worktree_path $argv[1]
    set -l issue_number $argv[2]
    set -l branch_name $argv[3]

    __flo_internal_config_init
    set -l config_file (__flo_internal_config_file)

    # Add/update entry: { "/full/path": { "issue": 1320, "branch": "feat/1320-..." } }
    jq --arg path "$worktree_path" \
        --arg issue "$issue_number" \
        --arg branch "$branch_name" \
        '.[$path] = {"issue": ($issue | tonumber), "branch": $branch}' \
        $config_file >$config_file.tmp && mv $config_file.tmp $config_file
end

# Load all config data
# Usage: set data (__flo_internal_config_load)
function __flo_internal_config_load
    set -l config_file (__flo_internal_config_file)

    if test -f $config_file
        cat $config_file
    else
        echo '{}'
    end
end
