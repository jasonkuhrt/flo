function __flo_success --description "Display success message" --argument-names message
    set_color green
    echo "$message"
    set_color normal
end
