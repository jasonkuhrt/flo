function __flo_select_project --description "Let user select from available projects"
    # Get list of projects from GitHub
    if not __flo_check_gh_auth
        return 1
    end

    set -l org_repo (__flo_get_org_repo)
    if test $status -ne 0
        return 1
    end

    # Get projects list
    set -l projects (gh project list --owner (string split / $org_repo)[1] --limit 30 --format json 2>/dev/null | jq -r '.projects[].title')

    if test -z "$projects"
        echo "No projects found" >&2
        return 1
    end

    # Count projects to decide between choose and filter
    set -l project_count (count $projects)

    # Use filter for more than 5 projects, choose for smaller lists
    if test $project_count -gt 5
        # Use gum filter for fuzzy search
        set -l selected (echo $projects | tr ' ' '\n' | gum filter \
            --placeholder "Type to filter $project_count projects..." \
            --header "Search projects:" \
            --height 12)
    else
        # Use gum choose for small lists
        set -l selected (echo $projects | tr ' ' '\n' | gum choose --header "Select project:" --show-help)
    end

    if test -z "$selected"
        return 1
    end

    echo $selected
end
