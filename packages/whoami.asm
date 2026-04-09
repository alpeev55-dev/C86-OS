; whoami command

do_whoami:
    call print_newline
    mov esi, user_name
    call print_string
    call print_newline
    ret