; rtc.asm - CMOS/RTC driver

RTC_ADDR       equ 0x70
RTC_DATA       equ 0x71

RTC_SECONDS    equ 0x00
RTC_MINUTES    equ 0x02
RTC_HOURS      equ 0x04
RTC_DAY        equ 0x07
RTC_MONTH      equ 0x08
RTC_YEAR       equ 0x09
RTC_STATUS_A   equ 0x0A
RTC_STATUS_B   equ 0x0B

rtc_second     db 0
rtc_minute     db 0
rtc_hour       db 0
rtc_day        db 0
rtc_month      db 0
rtc_year       dw 0
rtc_bcd        db 1

; ----- INIT RTC -----
init_rtc:
    push eax
    
    mov al, RTC_STATUS_B
    call rtc_read
    test al, 0x04        
    jz .bcd_mode
    mov byte [rtc_bcd], 0
    jmp .done
.bcd_mode:
    mov byte [rtc_bcd], 1
    
.done:
    pop eax
    ret

rtc_read:
    pushf
    cli
    out RTC_ADDR, al
    jmp $+2
    jmp $+2
    in al, RTC_DATA
    popf
    ret

rtc_write:
    pushf
    push eax
    cli
    mov al, ah
    out RTC_DATA, al
    pop eax
    out RTC_ADDR, al
    popf
    ret

rtc_update:
    push eax
    push ebx
    
    mov al, RTC_SECONDS
    call rtc_read
    call rtc_convert
    mov [rtc_second], al
    
    mov al, RTC_MINUTES
    call rtc_read
    call rtc_convert
    mov [rtc_minute], al
    
    mov al, RTC_HOURS
    call rtc_read
    call rtc_convert
    mov [rtc_hour], al
    
    mov al, RTC_DAY
    call rtc_read
    call rtc_convert
    mov [rtc_day], al
    
    mov al, RTC_MONTH
    call rtc_read
    call rtc_convert
    mov [rtc_month], al
    
    mov al, RTC_YEAR
    call rtc_read
    call rtc_convert
    mov [rtc_year], ax
    add word [rtc_year], 2000
    
    pop ebx
    pop eax
    ret


rtc_convert:
    cmp byte [rtc_bcd], 1
    jne .done
    
    push ebx
    mov bl, al
    shr al, 4
    mov ah, 0
    mov bh, 10
    mul bh           ; AX = десятки * 10
    and bl, 0x0F
    add al, bl
    pop ebx
    
.done:
    ret

print_datetime:
    push esi
    push edx
    push eax
    push ebx
    
    call rtc_update
    

    movzx eax, [rtc_hour]      
    call print_two_digits
    mov al, ':'
    call print_char
    
    movzx eax, [rtc_minute]    
    call print_two_digits
    mov al, ':'
    call print_char
    
    movzx eax, [rtc_second]  
    call print_two_digits
    

    mov al, ' '
    call print_char
    

    movzx eax, [rtc_day]    
    call print_two_digits
    mov al, '.'
    call print_char
    
    movzx eax, [rtc_month]  
    call print_two_digits
    mov al, '.'
    call print_char
    
    movzx eax, [rtc_year]    
    call print_number
    
    pop ebx
    pop eax
    pop edx
    pop esi
    ret

print_two_digits:
    push eax
    push ebx
    mov bl, 10
    div bl
    add al, '0'
    call print_char
    add ah, '0'
    mov al, ah
    call print_char
    pop ebx
    pop eax
    ret