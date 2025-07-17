function __flo_extract_branch_name --description "Extract a clean branch name from issue title"
    set -l input $argv[1]
    # Remove leading numbers and hyphens, convert to lowercase kebab-case
    # Use echo to prevent input being interpreted as flags
    # Remove invalid characters for git branch names
    echo $input | string replace -r '^[0-9]+-' '' | string replace -a ' ' - | string replace -a "'" '' | string replace -a '?' '' | string replace -a '!' '' | string replace -a '(' '' | string replace -a ')' '' | string replace -a '[' '' | string replace -a ']' '' | string replace -a '{' '' | string replace -a '}' '' | string replace -a / '' | string replace -a '\\' '' | string replace -a ':' '' | string replace -a '*' '' | string replace -a '^' '' | string replace -a '~' '' | string replace -a '@' '' | string replace -a '#' '' | string replace -a '$' '' | string replace -a '%' '' | string replace -a '&' '' | string replace -a '+' '' | string replace -a '=' '' | string replace -a '|' '' | string replace -a '<' '' | string replace -a '>' '' | string replace -a '"' '' | string replace -a '`' '' | string replace -r -- '\\.+$' '' | string replace -r -- '^-+' '' | string replace -r -- '-+$' '' | string lower
end
