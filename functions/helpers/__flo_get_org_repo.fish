function __flo_get_org_repo --description "Get the GitHub org/repo from git remote"
    set -l remote_url (git config --get remote.origin.url)

    if test -z "$remote_url"
        echo "No origin remote found" >&2
        return 1
    end

    # Extract org/repo from various Git URL formats
    set -l org_repo (string replace -r '.*[:/]([^/]+/[^/]+)(\.git)?$' '$1' $remote_url)

    if test -z "$org_repo"
        echo "Could not parse org/repo from remote URL" >&2
        return 1
    end

    echo $org_repo
end
