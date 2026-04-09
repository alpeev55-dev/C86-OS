; uptime.asm - system uptime counter (via RTC)

UPTIME_SECONDS  dd 0
UPTIME_MINUTES  dd 0
UPTIME_HOURS    dd 0
UPTIME_DAYS     dd 0

BOOT_TIME_SEC   dd 0

; ----- INIT UPTIME (CALL AT STARTUP) -----
init_uptime:
    push eax
    
    call get_rtc_seconds
    mov [BOOT_TIME_SEC], eax
    
    pop eax
    ret

; ----- CONVERT RTC TO SECONDS SINCE MIDNIGHT -----
; Output: eax = seconds since midnight
get_rtc_seconds:
    push ebx
    push ecx
    push edx
    
    ; Update time from RTC
    call rtc_update
    
    ; Hours -> seconds
    movzx eax, [rtc_hour]
    mov ebx, 3600
    mul ebx
    mov ecx, eax
    
    ; Minutes -> seconds
    movzx eax, [rtc_minute]
    mov ebx, 60
    mul ebx
    add ecx, eax
    
    ; Seconds
    movzx eax, [rtc_second]
    add eax, ecx
    
    pop edx
    pop ecx
    pop ebx
    ret

; ----- CALCULATE UPTIME -----
calculate_uptime:
    push eax
    push ebx
    push edx
    
    ; Current time in seconds
    call get_rtc_seconds
    
    ; Subtract boot time
    sub eax, [BOOT_TIME_SEC]
    jns .ok
    add eax, 86400          ; handle midnight overflow (24*3600)
.ok:
    
    ; eax = seconds since boot
    mov ebx, 60
    xor edx, edx
    div ebx                 ; eax = minutes, edx = seconds
    mov [UPTIME_SECONDS], edx
    
    xor edx, edx
    div ebx                 ; eax = hours, edx = minutes
    mov [UPTIME_MINUTES], edx
    
    xor edx, edx
    mov ebx, 24
    div ebx                 ; eax = days, edx = hours
    mov [UPTIME_HOURS], edx
    mov [UPTIME_DAYS], eax
    
    pop edx
    pop ebx
    pop eax
    ret

; ----- PRINT UPTIME -----
print_uptime:
    push eax
    push edx
    push esi
    
    call calculate_uptime
    
    ; Days
    cmp dword [UPTIME_DAYS], 0
    je .no_days
    mov eax, [UPTIME_DAYS]
    call print_number
    mov esi, days_text
    call print_string
    mov al, ' '
    call print_char
    
.no_days:
    ; Hours (always 2 digits)
    mov eax, [UPTIME_HOURS]
    call print_two_digits
    mov al, ':'
    call print_char
    
    ; Minutes
    mov eax, [UPTIME_MINUTES]
    call print_two_digits
    mov al, ':'
    call print_char
    
    ; Seconds
    mov eax, [UPTIME_SECONDS]
    call print_two_digits
    
    pop esi
    pop edx
    pop eax
    ret

days_text       db "d ", 0