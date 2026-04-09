format binary as 'bin'
use16
org 0x7C00

start:
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00
    mov [boot_drive], dl

    call set_80x50_mode

    mov si, boot_menu
    call print_string

    ; wait key 1 or 2
    mov ah, 0x00
    int 0x16

    cmp al, '1'
    je .load_text
    cmp al, '2'
    je .do_reboot
    jmp start

.load_text:
    mov byte [selected_mode], 1
    mov si, msg_text
    call print_string
    mov ax, 0x1000
    mov es, ax
    mov dword [lba_packet + 8], 1
    jmp .load_kernel

.do_reboot:
    mov si, msg_reboot
    call print_string
    call reboot_system
    jmp $  ; should never reach here

.load_kernel:
    xor bx, bx
    mov ah, 0x42
    mov dl, [boot_drive]
    mov si, lba_packet
    int 0x13
    jc error

    cli
    lgdt [gdt_descriptor]
    call enable_a20

    mov eax, cr0
    or eax, 1
    mov cr0, eax
    jmp 0x08:protected_mode

error:
    mov si, msg_error
    call print_string
    jmp $

reboot_system:
    ; Method 1: Keyboard controller reset
    mov al, 0xFE
    out 0x64, al
    
    ; Method 2: Triple fault (jump to 0xFFFF:0x0000)
    push word 0xFFFF
    push word 0x0000
    retf
    
    ; Method 3: BIOS warm boot via interrupt
    int 0x19
    
    ret

set_80x50_mode:
    mov ax, 0x0003
    int 0x10
    mov ax, 0x1112
    mov bl, 0x00
    int 0x10
    ret

use32
protected_mode:
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    mov esp, 0x90000

    ; Jump to selected kernel
    cmp byte [selected_mode], 2
    je .jump_graphics
    jmp 0x10000  ; text mode

.jump_graphics:
    jmp 0x15000  ; graphics mode 800x600

use16
enable_a20:
    in al, 0x92
    or al, 2
    out 0x92, al
    ret

print_string:
    mov ah, 0x0E
.loop:
    lodsb
    test al, al
    jz .done
    int 0x10
    jmp .loop
.done:
    ret

; Data
selected_mode db 1  ; 1=text, 2=graphics

boot_menu:
    db " ",0x0D,0x0A
    db " ",0x0D,0x0A
    db " ",0x0D,0x0A
    db " ",0x0D,0x0A
    db " ",0x0D,0x0A
    db " ",0x0D,0x0A
    db " ",0x0D,0x0A
    db " ",0x0D,0x0A
    db " ",0x0D,0x0A
    db " ",0x0D,0x0A
    db " ",0x0D,0x0A
    db " ",0x0D,0x0A
    db " ",0x0D,0x0A
    db " ",0x0D,0x0A
    db " ",0x0D,0x0A
    db " ",0x0D,0x0A
    db " ",0x0D,0x0A
    db " ",0x0D,0x0A
    db " ",0x0D,0x0A
    db " ",0x0D,0x0A
    db " ",0x0D,0x0A
    db " ",0x0D,0x0A
    db "                               1 - 80x50 Text Mode",0x0D,0x0A
    db "                               2 - Reboot System",0x0D,0x0A,0

msg_text db "Loading text mode kernel...",0x0D,0x0A,0
msg_reboot db "Rebooting system...",0x0D,0x0A,0
msg_error db "Disk error! Kernel not found.",0x0D,0x0A,0

boot_drive db 0

lba_packet:
    db 0x10,0
    dw 128,0
    dw 0x1000
    dd 1,0

gdt_start:
    dq 0
gdt_code:
    dw 0xFFFF,0,0x9A00,0x00CF
gdt_data:
    dw 0xFFFF,0,0x9200,0x00CF
gdt_end:

gdt_descriptor:
    dw gdt_end - gdt_start - 1
    dd gdt_start

times 510-($-$$) db 0
dw 0xAA55