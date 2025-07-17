function __flo_spinner --description "Display a spinner animation"
    set -l pid $argv[1]
    set -l message $argv[2]
    set -l spinners '⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏'
    set -l i 1

    while kill -0 $pid 2>/dev/null
        printf "\r%s %s" $spinners[$i] $message
        set i (math "($i % 10) + 1")
        sleep 0.1
    end

    printf "\r%s\n" (string repeat -n (string length "$spinners[1] $message") " ")
end
