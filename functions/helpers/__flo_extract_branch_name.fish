function __flo_extract_branch_name --description "Extract a clean branch name from issue title"
    set -l input $argv[1]
    # Remove leading numbers, convert to lowercase kebab-case, remove invalid git branch chars
    echo $input | sed 's/^[0-9]*-//' | tr -cs '[:alnum:]-' - | tr '[:upper:]' '[:lower:]' | sed 's/^-\|-$//g'
end
