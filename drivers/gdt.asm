gdt_start:
    ; NULL
    dd 0, 0

gdt_code:
    dw 0xFFFF        ;  (0-15)
    dw 0             ;  (0-15)
    db 0             ;  (16-23)
    db 10011010b     
    db 11001111b     
    db 0             ; (24-31)

gdt_data:
    dw 0xFFFF        ; limit
    dw 0             ; base
    db 0
    db 10010010b     
    db 11001111b     
    db 0

gdt_end:

gdt_descriptor:
    dw gdt_end - gdt_start - 1  ; size GDT - 1
    dd gdt_start                 ; adress GDT


CODE_SEG equ gdt_code - gdt_start
DATA_SEG equ gdt_data - gdt_start

; ===== IDT (Interrupt Descriptor Table) =====

IDT_SIZE equ 256

idt_start:
    times IDT_SIZE db 0  

idt_descriptor:
    dw IDT_SIZE*8 - 1    ; size IDT(in bytes) - 1
    dd idt_start         ; adress IDT

set_idt_gate:
    pusha
    push es
    
    ; adress in IDT
    movzx ebx, al
    shl ebx, 3          ; *8
    add ebx, idt_start
    
    ;  (0-15)
    mov word [ebx], dx
    mov word [ebx+2], CODE_SEG
    ; DPL=0
    mov byte [ebx+4], 0
    mov byte [ebx+5], 10001110b  ; DPL=0
    ; (16-31)
    shr edx, 16
    mov word [ebx+6], dx
    
    pop es
    popa
    ret

enter_protected_mode:
    cli
    
    ; load GDT
    lgdt [gdt_descriptor]
    
    mov eax, cr0
    or eax, 1
    mov cr0, eax
    
    ; jump
    jmp CODE_SEG:protected_mode_entry

protected_mode_entry:
    mov ax, DATA_SEG
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    
    mov esp, 0x90000
    
    lidt [idt_descriptor]
    
    mov al, 0x80
    mov edx, syscall_handler
    call set_idt_gate
    
    sti
    
    jmp main_kernel

syscall_handler:
    pusha
    push ds
    push es
    
    cmp eax, MAX_SYSCALL
    jae .bad
    
    mov ebx, eax
    shl ebx, 2
    call [syscall_table + ebx]
    
    jmp .done
.bad:
    stc
.done:
    pop es
    pop ds
    popa
    iretd

syscall_table:
    dd sys_write
    dd sys_read
    dd sys_clear
    dd sys_time
    dd sys_exit

main_kernel:
    ;  sys_write
    mov eax, SYS_WRITE
    mov esi, hello_msg
    int 0x80
    
    ;  sys_read
    mov eax, SYS_READ
    int 0x80
    
    ;  sys_clear
    mov eax, SYS_CLEAR
    int 0x80
    
    jmp $

hello_msg db "32-bit  work!", 0x0D, 0x0A, 0