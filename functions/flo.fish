# Flo - Git workflow automation tool
# This file initializes flo using the CLI framework

set -l flo_dir (dirname (status -f))

# Source the CLI framework
source $flo_dir/../lib/cli/$.fish

# Source helpers first (they're needed by commands)
source $flo_dir/helpers.fish

# Initialize flo with the CLI framework
__cli_init \
    --name flo \
    --prefix flo \
    --dir $flo_dir \
    --description "Git workflow automation tool" \
    --version "1.0.0" \
    --exclude flo helpers completions

# Register command dependencies
__cli_register_deps issue git gh gum jq
__cli_register_deps pr git gh gum
__cli_register_deps next git gh gum
__cli_register_deps rm git gh gum
__cli_register_deps claude git gh

# The framework automatically creates the 'flo' function with:
# - Dynamic command dispatch
# - Auto-generated help
# - Version display
# - Command discovery

# Source completions if available
if test -f $flo_dir/completions.fish
    source $flo_dir/completions.fish
end
