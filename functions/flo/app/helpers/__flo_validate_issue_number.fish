function __flo_validate_issue_number --description "Validate that a string is a valid issue number"
    set -l value $argv[1]

    if test -z "$value"
        return 1
    end

    # Check if it's a positive integer
    if string match -qr '^[0-9]+$' $value
        # Also check it's not just zeros
        if test $value -gt 0
            return 0
        end
    end

    return 1
end
