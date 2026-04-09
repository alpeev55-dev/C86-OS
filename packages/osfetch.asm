; ----- C86/OS FETCH -----

do_fetch:
    ; System info
    mov esi, os_fetch_info
    call print_string
    call do_cpuinfo
    call print_newline

    ; Rainbow line
    mov edi, rainbow_colors
    mov ecx, 36
.next:
    push ecx
    mov al, [edi]
    mov ah, al
    mov al, 0xDB
    call print_char
    inc edi
    cmp edi, rainbow_colors + 6
    jl .skip
    mov edi, rainbow_colors
.skip:
    pop ecx
    loop .next

    call print_newline
    ret

rainbow_colors db 0x04, 0x0C, 0x0E, 0x0A, 0x09, 0x0D

os_fetch_info:
    db 0x0D, 0x0A, "", 0x0D, 0x0A
    db "\|||||||/ OS: C86/OS", 0x0D, 0x0A
    db "=|X86  |= Kernel base: 0x10000", 0x0D, 0x0A
    db "=|     |= Text mode: 80x50", 0x0D, 0x0A
    db "=|     |= Arch: x86 (BIOS)", 0x0D, 0x0A
    db "=|_____|= Shell ver: 1.0", 0x0D, 0x0A
    db "/||||||\  ", 0x0D, 0x0A, 0