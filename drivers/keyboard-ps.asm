;keyboard.asm

key_flags db 0 

read_line:
    push edi
    push ecx
    push eax
    push ebx
    mov byte [edi], 0
    mov ebx, edi
.read_char:
    in al, 0x64
    test al, 1
    jz .read_char
    in al, 0x60
    
    cmp al, 0x2A   
    je .shift_press
    cmp al, 0x36   
    je .shift_press
    cmp al, 0xAA  
    je .shift_release
    cmp al, 0xB6    
    je .shift_release
    cmp al, 0x3A   
    je .caps_lock
    
    cmp al, 0x48
    je .scroll_up
    cmp al, 0x50
    je .scroll_down
    
    cmp al, 0x1C
    je .done_read
    cmp al, 0x0E
    je .backspace
    cmp al, 0x80
    jae .read_char
    
    call key_to_ascii
    test al, al
    jz .read_char
    mov edx, edi
    sub edx, ebx
    cmp edx, 63
    jge .read_char
    
    mov [edi], al
    inc edi
    mov byte [edi], 0
    call print_char
    jmp .read_char

.shift_press:
    or byte [key_flags], 1
    jmp .read_char

.shift_release:
    and byte [key_flags], 0xFE
    jmp .read_char

.caps_lock:
    xor byte [key_flags], 2
    jmp .read_char

.scroll_up:
    call scroll_up
    jmp .read_char

.scroll_down:
    call scroll_down  
    jmp .read_char

.backspace:
    cmp edi, ebx
    je .read_char
    dec edi
    mov byte [edi], 0
    mov al, 0x08
    call print_char
    jmp .read_char

.done_read:
    mov al, 0x0D
    call print_char
    mov al, 0x0A
    call print_char
    pop ebx
    pop eax
    pop ecx
    pop edi
    ret

key_to_ascii:
    push ebx
    push ecx
    
    cmp al, 0x39
    ja .no_char
    
    test byte [key_flags], 1
    jnz .shift_layout
    
    test byte [key_flags], 2
    jz .normal_layout
    
    cmp al, 0x10  ; q
    jb .check_second_row
    cmp al, 0x1C  ; ]
    jbe .caps_letter
    
.check_second_row:
    cmp al, 0x1E  ; a
    jb .normal_layout
    cmp al, 0x28  ; '
    jbe .caps_letter
    
.check_third_row:
    cmp al, 0x2B  ; \
    je .caps_letter
    cmp al, 0x2C  ; z
    jb .normal_layout
    cmp al, 0x32  ; m
    jbe .caps_letter
    jmp .normal_layout

.caps_letter:
    mov ebx, keymap_shift
    jmp .get_char

.shift_layout:
    mov ebx, keymap_shift
    jmp .get_char

.normal_layout:
    mov ebx, keymap_normal

.get_char:
    xlatb
    pop ecx
    pop ebx
    ret

.no_char:
    xor al, al
    pop ecx
    pop ebx
    ret
print_hex_byte:
    push eax
    push ebx
    mov bl, al
    
    shr al, 4
    call .print_digit
    
    mov al, bl
    and al, 0x0F
    call .print_digit
    
    pop ebx
    pop eax
    ret
.print_digit:
    cmp al, 10
    jl .decimal
    add al, 'A' - 10
    jmp .print
.decimal:
    add al, '0'
.print:
    call print_char
    ret

show_caps_status:
    push eax
    push esi
    
    test byte [key_flags], 2
    jz .caps_off
    
    mov esi, caps_on_msg
    jmp .show_status
    
.caps_off:
    mov esi, caps_off_msg
    
.show_status:
    call print_string
    pop esi
    pop eax
    ret

caps_on_msg  db "[CAPS]", 0
caps_off_msg db "      ", 0