# Shared utility functions for flo
# This file sources all individual helper functions

set -l helpers_dir (dirname (status --current-filename))/helpers

# Source all helper functions
for helper_file in $helpers_dir/*.fish
    source $helper_file
end
