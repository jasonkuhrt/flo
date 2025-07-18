# Fish CLI Framework
# Main entry point for the CLI framework

# Source all framework modules
set -l cli_framework_dir (dirname (status --current-filename))

source $cli_framework_dir/core.fish
source $cli_framework_dir/dispatcher.fish
source $cli_framework_dir/discovery.fish
source $cli_framework_dir/loader.fish
source $cli_framework_dir/help.fish
source $cli_framework_dir/deps.fish

# Main initialization function
function __cli_init --description "Initialize a CLI application with the framework"
    argparse --name="__cli_init" \
        'name=' \
        'prefix=' \
        'dir=' \
        'description=' \
        'version=' \
        'exclude=+' \
        -- $argv; or return

    # Validate required parameters
    if not set -q _flag_name
        echo "Error: --name is required" >&2
        return 1
    end

    if not set -q _flag_dir
        echo "Error: --dir is required" >&2
        return 1
    end

    # Set defaults
    if not set -q _flag_prefix
        set _flag_prefix $_flag_name
    end

    if not set -q _flag_exclude
        set _flag_exclude $_flag_name helpers completions
    end

    # Store CLI configuration
    set -g __cli_name $_flag_name
    set -g __cli_prefix $_flag_prefix
    set -g __cli_dir $_flag_dir
    set -g __cli_description $_flag_description
    set -g __cli_version $_flag_version

    # Load all command modules
    __cli_load_commands $_flag_dir $_flag_exclude

    # Create the main dispatcher
    __cli_create_dispatcher $_flag_name $_flag_prefix

    # Set up help system
    __cli_setup_help $_flag_name $_flag_prefix
end
