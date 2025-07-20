function __flo_slugify --description "Convert text to URL-friendly slug"
    argparse --name="__flo_slugify" -- $argv; or return

    set -l input "$argv[1]"

    if test -z "$input"
        return 1
    end

    # Convert to lowercase, replace spaces and special chars with hyphens, remove consecutive hyphens
    echo "$input" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/-\+/-/g' | sed 's/^-\|-$//g'
end
