; drivers\rtl8139.asm 

rtl8139_iobase   dw 0
rtl8139_status   db 0
rtl8139_mac      db 6 dup(0)

rtl8139_found    db 0x0D, 0x0A,"RTL8139: Found!", 0x0D, 0x0A, 0
rtl8139_notfound db 0x0D, 0x0A,"RTL8139: Not found", 0x0D, 0x0A, 0
rtl8139_mac_msg  db 0x0D, 0x0A,"RTL8139 MAC: ", 0

init_rtl8139:
    pushad
    
    mov esi, .search_msg
    call print_string
    
    mov al, 0        ; bus
    mov bl, 0        ; device
.search_loop:
    mov cl, 0        ; function
    call pci_check_device
    jc .check_vendor
    
.next_device:
    inc bl
    cmp bl, 32
    jb .search_loop
    jmp .not_found

.check_vendor:
    push ax
    push bx
    push cx
    
    ; Read Vendor/Device
    mov dl, 0x00
    call pci_read_config_dword
    
    cmp ax, 0x10EC        ; Realtek Vendor
    jne .next
    shr eax, 16
    cmp ax, 0x8139        ; RTL8139 Device
    jne .next
    
    ; FOUND!
    pop cx
    pop bx
    pop ax
    
    mov esi, rtl8139_found
    call print_string
    
    ; Get BAR0
    mov dl, 0x10
    call pci_read_config_dword
    
    ; Write BAR
    mov esi, .bar_msg
    call print_string
    call print_hex_dword
    call print_newline
    
    test al, 1
    jz .not_io
    
    and eax, 0xFFFC     
    mov [rtl8139_iobase], ax
    
    mov esi, .io_msg
    call print_string
    mov ax, [rtl8139_iobase]
    call print_hex_word
    call print_newline
    
    ; Read MAC
    call read_mac_simple
    
    mov byte [rtl8139_status], 1
    jmp .done

.next:
    pop cx
    pop bx
    pop ax
    jmp .next_device

.not_io:
    mov esi, .not_io_msg
    call print_string
    jmp .next_device

.not_found:
    mov esi, rtl8139_notfound
    call print_string
    mov byte [rtl8139_status], 0

.done:
    popad
    ret

.search_msg db 0x0D, 0x0A,"Searching for RTL8139...", 0x0D, 0x0A, 0
.bar_msg    db 0x0D, 0x0A,"BAR0: 0x", 0
.io_msg     db 0x0D, 0x0A,"IO Base: 0x", 0
.not_io_msg db 0x0D, 0x0A,"Not IO space", 0x0D, 0x0A, 0

; read MAC
read_mac_simple:
    pushad
    
    mov dx, [rtl8139_iobase]
    
    ; read 6 bytes MAC from IDR0
    mov ecx, 6
    mov edi, rtl8139_mac
.mac_loop:
    in al, dx
    mov [edi], al
    inc edi
    inc dx
    loop .mac_loop
    
    ; write MAC
    mov esi, rtl8139_mac_msg
    call print_string
    
    mov ecx, 6
    mov esi, rtl8139_mac
.print_loop:
    lodsb
    call print_hex_byte
    cmp ecx, 1
    je .no_colon
    mov al, ':'
    call print_char
.no_colon:
    loop .print_loop
    
    call print_newline
    popad
    ret

do_netinfo:
    cmp byte [rtl8139_status], 0
    je .not_ready
    
    mov esi, .info_header
    call print_string
    
    mov esi, .io_msg
    call print_string
    mov ax, [rtl8139_iobase]
    call print_hex_word
    call print_newline
    
    mov esi, .mac_msg
    call print_string
    mov ecx, 6
    mov esi, rtl8139_mac
.print_mac:
    lodsb
    call print_hex_byte
    cmp ecx, 1
    je .no_colon
    mov al, ':'
    call print_char
.no_colon:
    loop .print_mac
    call print_newline
    
    ret

.not_ready:
    mov esi, .not_ready_msg
    call print_string
    ret

.info_header   db 0x0D, 0x0A, "RTL8139 Info:", 0x0D, 0x0A, 0
.io_msg        db 0x0D, 0x0A,"IO Base: 0x", 0
.mac_msg       db 0x0D, 0x0A,"MAC Address: ", 0
.not_ready_msg db 0x0D, 0x0A,"RTL8139 not initialized", 0x0D, 0x0A, 0

do_netsend:
    mov esi, .not_impl_msg
    call print_string
    ret

.not_impl_msg db "Send not implemented yet", 0x0D, 0x0A, 0