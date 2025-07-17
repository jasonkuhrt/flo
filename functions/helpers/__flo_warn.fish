function __flo_warn --description "Display warning message" --argument-names message
    set_color yellow
    echo "flo: $message" >&2
    set_color normal
end
