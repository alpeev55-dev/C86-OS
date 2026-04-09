;video.asm

cursor_pos dd 0
scroll_offset dd 0

init_video:
    call clear_screen
    mov dword [cursor_pos], 0
    mov dword [scroll_offset], 0
    call update_cursor
    call redraw_screen
    ret

clear_screen:
    mov edi, VIDEO_MEMORY
    mov ecx, SCREEN_WIDTH * SCREEN_HEIGHT
    mov ah, 0x07
    mov al, ' '
.clear_loop:
    mov [edi], ax
    add edi, 2
    loop .clear_loop
    
    mov edi, screen_buffer
    mov ecx, SCREEN_WIDTH * SCREEN_HEIGHT * 4
    mov ax, 0x0720
    rep stosw
    
    mov dword [cursor_pos], 0
    mov dword [scroll_offset], 0
    call update_cursor
    ret

redraw_screen:
    pushad
    
    mov eax, [scroll_offset]
    cmp eax, SCREEN_WIDTH * SCREEN_HEIGHT * 3
    jbe .offset_ok
    mov dword [scroll_offset], SCREEN_WIDTH * SCREEN_HEIGHT * 3
    mov eax, [scroll_offset]
.offset_ok:
    
    ; ESI = screen_buffer + scroll_offset * 2 (bytes)
    mov esi, screen_buffer
    shl eax, 1
    add esi, eax
    
    ; EDI = VIDEO_MEMORY
    mov edi, VIDEO_MEMORY

    mov ecx, SCREEN_WIDTH * SCREEN_HEIGHT
.copy_loop:
    movsw
    loop .copy_loop
    
    popad
    ret

save_to_buffer:
    push eax
    push ebx
    push edi
    
    mov ebx, [cursor_pos]
    mov edi, screen_buffer
    shl ebx, 1
    add edi, ebx
    mov ah, 0x07
    mov [edi], ax
    
    pop edi
    pop ebx
    pop eax
    ret
print_char:
    pushad
    
    cmp al, 0x0A
    je .handle_newline
    cmp al, 0x0D
    je .handle_carriage
    cmp al, 0x08
    je .handle_backspace

    call save_to_buffer
    call redraw_screen
    
    inc dword [cursor_pos]
    
    mov eax, [cursor_pos]
    cmp eax, SCREEN_WIDTH * SCREEN_HEIGHT * 4
    jb .char_update
    
    mov dword [cursor_pos], SCREEN_WIDTH * SCREEN_HEIGHT * 4 - SCREEN_WIDTH
    mov eax, [scroll_offset]
    add eax, SCREEN_WIDTH
    mov [scroll_offset], eax
    call redraw_screen
    
.char_update:
    call update_cursor
    popad
    ret

.handle_newline:
    mov eax, [cursor_pos]
    add eax, SCREEN_WIDTH
    mov [cursor_pos], eax

    mov eax, [cursor_pos]
    cmp eax, SCREEN_WIDTH * SCREEN_HEIGHT * 4
    jb .newline_update
    
    mov dword [cursor_pos], SCREEN_WIDTH * SCREEN_HEIGHT * 4 - SCREEN_WIDTH
    mov eax, [scroll_offset]
    add eax, SCREEN_WIDTH
    mov [scroll_offset], eax
    call redraw_screen
    
.newline_update:
    call update_cursor
    popad
    ret

.handle_carriage:
    mov eax, [cursor_pos]
    mov ebx, SCREEN_WIDTH
    xor edx, edx
    div ebx
    mul ebx
    mov [cursor_pos], eax
    call redraw_screen
    call update_cursor
    popad
    ret

.handle_backspace:
    mov eax, [cursor_pos]
    test eax, eax
    jz .backspace_update
    
    mov ebx, SCREEN_WIDTH
    xor edx, edx
    div ebx
    test edx, edx
    jz .backspace_update
    
    dec dword [cursor_pos]
    mov ebx, [cursor_pos]
    mov edi, screen_buffer
    shl ebx, 1
    add edi, ebx
    mov ax, 0x0720
    mov [edi], ax
    call redraw_screen

.backspace_update:
    call update_cursor
    popad
    ret

scroll_up:
    push eax
    mov eax, [scroll_offset]
    cmp eax, 0
    je .up_done
    sub eax, SCREEN_WIDTH
    mov [scroll_offset], eax
    call redraw_screen
.up_done:
    pop eax
    ret

scroll_down:
    push eax
    mov eax, [scroll_offset]
    add eax, SCREEN_WIDTH
    cmp eax, SCREEN_WIDTH * SCREEN_HEIGHT * 3
    ja .down_done
    mov [scroll_offset], eax
    call redraw_screen
.down_done:
    pop eax
    ret

print_string:
    push eax
    push esi
.string_loop:
    lodsb
    test al, al
    jz .string_done
    call print_char
    jmp .string_loop
.string_done:
    pop esi
    pop eax
    ret

print_newline:
    push eax
    mov al, 0x0A
    call print_char
    pop eax
    ret

update_cursor:
    mov eax, [cursor_pos]
    sub eax, [scroll_offset]
    
    cmp eax, 0
    jl .hide_cursor
    cmp eax, SCREEN_WIDTH * SCREEN_HEIGHT
    jge .hide_cursor

    mov ebx, eax
    mov dx, 0x3D4
    mov al, 0x0F
    out dx, al
    inc dx
    mov al, bl
    out dx, al
    dec dx
    mov al, 0x0E
    out dx, al
    inc dx
    mov al, bh
    out dx, al
    ret
    
.hide_cursor:
    mov dx, 0x3D4
    mov al, 0x0F
    out dx, al
    inc dx
    mov al, 0xFF
    out dx, al
    dec dx
    mov al, 0x0E
    out dx, al
    inc dx
    mov al, 0xFF
    out dx, al
    ret

print_hex_dword:
    push eax
    push ebx
    push ecx
    
    mov ebx, eax
    mov ecx, 8
    
.hex_loop:
    rol ebx, 4
    mov al, bl
    and al, 0x0F
    
    cmp al, 10
    jl .decimal
    add al, 'A' - 10
    jmp .print
.decimal:
    add al, '0'
.print:
    call print_char
    loop .hex_loop
    
    pop ecx
    pop ebx
    pop eax
    ret