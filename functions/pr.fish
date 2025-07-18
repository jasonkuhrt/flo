# Pull request management - simplified to just create PR

function pr --description "Create a pull request for current branch"
    argparse --name="flo pr" h/help d/draft t/title= b/body= base= -- $argv; or return

    if set -q _flag_help
        __flo_show_help \
            --usage "flo pr [options]" \
            --description "Create a pull request for the current branch." \
            --options "-t, --title TEXT   PR title (default: generated from branch)
-b, --body TEXT    PR body/description
-d, --draft        Create as draft PR
--base BRANCH      Base branch (default: main)
-h, --help         Show this help" \
            --examples "flo pr
flo pr --title \"Fix navigation bug\" --draft"
        return 0
    end

    if not __flo_check_gh_auth
        return 1
    end

    # Get current branch
    set -l current_branch (git branch --show-current)
    if test -z "$current_branch"
        echo "Not on a branch"
        return 1
    end

    if test "$current_branch" = main -o "$current_branch" = master
        echo "Cannot create PR from main/master branch"
        return 1
    end

    # Check if branch exists on remote
    if not git ls-remote --heads origin $current_branch >/dev/null 2>&1
        echo "Pushing branch to origin..."
        git push -u origin $current_branch; or return 1
    end

    # Build gh pr create command
    set -l gh_cmd gh pr create --head $current_branch

    if set -q _flag_title
        set gh_cmd $gh_cmd --title "$_flag_title"
    end

    if set -q _flag_body
        set gh_cmd $gh_cmd --body "$_flag_body"
    end

    if set -q _flag_draft
        set gh_cmd $gh_cmd --draft
    end

    if set -q _flag_base
        set gh_cmd $gh_cmd --base $_flag_base
    end

    # Create PR
    echo "Creating pull request..."
    eval $gh_cmd
end
