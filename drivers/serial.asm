;serial.asm
use32

COM1_BASE equ 0x3F8
COM1_DATA equ COM1_BASE + 0
COM1_INT  equ COM1_BASE + 1  
COM1_LCR  equ COM1_BASE + 3
COM1_LSR  equ COM1_BASE + 5

; Init COM1 (9600 8N1)
serial_init:
    push eax
    push edx
    
    mov dx, COM1_INT
    mov al, 0x00
    out dx, al
    
    ; Enable DLAB (speed)
    mov dx, COM1_LCR
    mov al, 0x80
    out dx, al
    
    ; Speed = 9600 (115200 / 9600 = 12)
    mov dx, COM1_BASE
    mov al, 12      ; Low byte
    out dx, al
    inc dx
    mov al, 0x00    ; High byte
    out dx, al
    
    mov dx, COM1_LCR
    mov al, 0x03
    out dx, al
    
    pop edx
    pop eax
    ret

; AL = symbol
serial_putc:
    push edx
    push eax
    
    mov dx, COM1_LSR
.wait_tx:
    in al, dx
    test al, 0x20   ; THRE (Transmit Holding Register Empty)
    jz .wait_tx
    
    pop eax
    mov dx, COM1_DATA
    out dx, al
    
    pop edx
    ret

; ESI = string (ASCIIZ)
serial_puts:
    push eax
    push esi
    
.send_loop:
    lodsb
    test al, al
    jz .done
    call serial_putc
    jmp .send_loop
    
.done:
    pop esi
    pop eax
    ret

serial_getc:
    push edx
    
    mov dx, COM1_LSR
    in al, dx
    test al, 0x01
    jz .no_data
    
    mov dx, COM1_DATA
    in al, dx
    stc
    jmp .done
    
.no_data:
    clc
    
.done:
    pop edx
    ret

serial_has_data:
    push edx
    mov dx, COM1_LSR
    in al, dx
    test al, 0x01
    pop edx
    ret