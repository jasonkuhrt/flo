function __flo_generate_branch_name --description "Generate a branch name from issue number and title"
    set -l issue_number $argv[1]
    set -l title $argv[2]

    if not __flo_validate_issue_number $issue_number
        __flo_error "Invalid issue number for branch generation"
        return 1
    end

    if test -z "$title"
        __flo_error "No title provided for branch generation"
        return 1
    end

    # Generate branch name using existing helper
    set -l branch_suffix (__flo_extract_branch_name $title)

    if test -z "$branch_suffix"
        __flo_error "Failed to generate branch name from title"
        return 1
    end

    # Return formatted branch name
    echo "$issue_number-$branch_suffix"
end
