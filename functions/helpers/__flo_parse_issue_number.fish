function __flo_parse_issue_number --description "Parse issue number from various formats"
    set -l input $argv[1]

    # Try to extract from various formats
    if string match -qr '^[0-9]+$' -- $input
        echo $input
    else if string match -qr '^#[0-9]+$' -- $input
        echo $input | string sub -s 2
    else if string match -qr '^[0-9]+-' -- $input
        echo $input | cut -d- -f1
    else
        echo ""
    end
end
