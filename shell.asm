;shell.asm

shell:
    mov esi, line7
    call print_string
    mov esi, line8
    call print_string
    call print_newline
.shell_loop:

    mov esi, prompt_user
    call print_string
    mov esi, prompt_at
    call print_string
    mov esi, user_name
    call print_string
    mov esi, prompt_end
    call print_string
    
    mov edi, command_buffer
    mov ecx, 64
    call read_line
    
    mov esi, command_buffer
    call process_input
    jmp .shell_loop

process_input:
    mov edi, cmd_help
    call compare_string
    jc do_help
    
    mov edi, cmd_clear
    call compare_string
    jc do_clear
    
    mov edi, cmd_reboot
    call compare_string
    jc do_reboot

    mov edi, cmd_fetch
    call compare_string
    jc do_fetch

    mov edi, cmd_pci
    call compare_string
    jc do_pci

    mov edi, cmd_whoami
    call compare_string
    jc do_whoami

    mov edi, cmd_calc
    call compare_string
    jc do_calc

    mov edi, cmd_uname
    call compare_string
    jc do_uname
    
    mov edi, cmd_beep
    call compare_string
    jc do_beep
    
    mov edi, cmd_fat32_ls
    call compare_string
    jc fat32_ls_cmd

    mov edi, cmd_fat32_cat
    call compare_string
    jc fat32_cat_cmd

    mov edi, cmd_fat32_write
    call compare_string
    jc fat32_write_cmd
    
    mov edi, cmd_meminfo
    call compare_string
    jc do_meminfo
    
    mov edi, cmd_echo
    call compare_string
    jc do_echo

    mov edi, cmd_cpuinfo
    call compare_string
    jc do_cpuinfo

    mov edi, cmd_date
    call compare_string
    jc do_date

    mov edi, cmd_read_sector
    call compare_string
    jc do_read_sector

    mov edi, cmd_pata_size
    call compare_string
    jc do_pata_size

    mov edi, cmd_floppy_info
    call compare_string
    jc do_floppy_info

    mov edi, cmd_floppy_ls
    call compare_string
    jc do_floppy_ls

    mov edi, cmd_floppy_format
    call compare_string
    jc do_floppy_format

    mov edi, cmd_pata_chs
    call compare_string
    jc do_pata_chs

    jmp try_access_file

do_date:
    call print_datetime
    ret
do_help:
    mov esi, help_text
    call print_string
    ret
do_clear:
    call clear_screen
    ret

do_reboot:
    mov al, 0xFE
    out 0x64, al
    jmp $

do_ls:
    mov esi, ls_header
    call print_string
    mov edi, file_table
    mov ecx, MAX_FILES
.ls_loop:
    cmp byte [edi], 0
    je .next_file
    mov al, ' '
    call print_char
    mov esi, edi
    call print_string
    mov esi, ls_file_marker
    call print_string
    call print_newline
.next_file:
    add edi, FILE_SIZE
    loop .ls_loop
    ret

do_cat:
    add esi, 4
    call find_file
    test edi, edi
    jz .not_found
    

    mov esi, debug_file_found
    call print_string
    mov esi, edi         
    call print_string
    call print_newline

    mov eax, [edi + 20]
    mov esi, debug_data_addr
    call print_string
    call print_hex 
    call print_newline
    
    mov esi, eax
    mov esi, debug_first_bytes
    call print_string
    mov esi, [edi + 20]

    mov ecx, 16
.check_data_loop:
    mov al, [esi]
    call print_hex_byte
    mov al, ' '
    call print_char
    inc esi
    loop .check_data_loop
    call print_newline
    mov esi, [edi + 20]
    call print_string
    
    mov esi, debug_done
    call print_string
    ret

.not_found:
    mov esi, file_not_found
    call print_string
    ret

print_hex:
    push eax
    push ebx
    push ecx
    push edx
    
    mov ebx, eax
    mov ecx, 8
    
.hex_loop:
    rol ebx, 4
    mov al, bl
    and al, 0x0F
    
    cmp al, 9
    jbe .digit
    add al, 7           ; A-F
.digit:
    add al, '0'         ; 0-9
    
    call print_char
    loop .hex_loop
    
    pop edx
    pop ecx
    pop ebx
    pop eax
    ret


;                     
debug_file_found:   db  0x0D, 0x0A,"File found: ", 0
debug_data_addr:    db  0x0D, 0x0A,"Data address: 0x", 0  
debug_first_bytes:  db  0x0D, 0x0A,"First 16 bytes: ", 0
debug_done:         db  0x0D, 0x0A,"--- CAT DONE ---", 0x0D, 0x0A, 0
do_uname:
    push eax
    
    mov al, 0x0D
    call print_char
    mov al, 0x0A
    call print_char
    
    mov esi, kernel_info_text
    call print_string
    
    mov al, 0x0D
    call print_char
    mov al, 0x0A
    call print_char
    
    pop eax
    ret
do_beep:
    call beep
    call delay_short
    call speaker_off
    mov al, 0x0D
    call print_char
    mov al, 0x0A
    call print_char
    
    ret
do_cpuinfo:
    call detect_cpu
    ret

detect_cpu:
    pushad

    mov esi, cpuinfo_header
    call print_string
    
    pushfd
    pop eax
    mov ecx, eax
    xor eax, 0x200000
    push eax
    popfd
    pushfd
    pop eax
    xor eax, ecx
    test eax, 0x200000
    jz .no_cpuid
    
    mov esi, cpu_vendor
    call print_string
    xor eax, eax
    cpuid
    mov [vendor], ebx
    mov [vendor+4], edx
    mov [vendor+8], ecx
    mov byte [vendor+12], 0
    mov esi, vendor
    call print_string
    call print_newline

    mov esi, cpu_brand
    call print_string
    mov eax, 0x80000002
    cpuid
    mov [brand], eax
    mov [brand+4], ebx
    mov [brand+8], ecx
    mov [brand+12], edx
    mov eax, 0x80000003
    cpuid
    mov [brand+16], eax
    mov [brand+20], ebx
    mov [brand+24], ecx
    mov [brand+28], edx
    mov eax, 0x80000004
    cpuid
    mov [brand+32], eax
    mov [brand+36], ebx
    mov [brand+40], ecx
    mov [brand+44], edx
    mov byte [brand+48], 0
    mov esi, brand
    call print_string
    call print_newline
    
    mov esi, cpu_cores
    call print_string
    
    mov eax, 0x80000000
    cpuid
    cmp eax, 0x80000008
    jb .basic_info
    
    mov eax, 0x80000008
    cpuid
    movzx ecx, cl
    inc ecx
    mov eax, ecx
    call print_number
    
    mov esi, cpu_phys_cores
    call print_string

    mov eax, 1
    cpuid
    mov eax, ebx
    shr eax, 16
    and eax, 0xFF
    call print_number
    
    mov esi, cpu_logical_cores
    call print_string
    call print_newline
    
    mov esi, cpu_freq
    call print_string
    call measure_cpu_frequency
    call print_number
    mov esi, cpu_mhz
    call print_string
    call print_newline
    ;    
    call print_cache_info
    jmp .done
    
.basic_info:
    mov esi, cpu_basic_info
    call print_string
    call print_newline
    
.done:
    popad
    ret

.no_cpuid:
    mov esi, cpu_no_cpuid
    call print_string
    call print_newline
    popad
    ret

measure_cpu_frequency:
    push ecx
    push edx
    
    mov ecx, 0x10000
.delay:
    nop
    loop .delay
    
    rdtsc
    mov [tsc_start], eax
    mov [tsc_start+4], edx
    
    mov ecx, 0x20000
.delay_loop:
    nop
    loop .delay_loop
    
    rdtsc
    sub eax, [tsc_start]
    sbb edx, [tsc_start+4]
    
    mov ecx, 10000
    div ecx
    
    pop edx
    pop ecx
    ret

print_cache_info:
    mov esi, cpu_cache
    call print_string
    
    ; L1 Data Cache
    mov eax, 2
    cpuid
    test al, 1
    jz .no_cache
    
    call print_newline
    ret
.no_cache:
    mov esi, cpu_no_cache
    call print_string
    call print_newline
    ret
try_access_file:
    mov esi, unknown_cmd
    call print_string
    ret

compare_string:
    push esi
    push edi
    push eax
    push ebx
.compare_loop:
    mov al, [esi]
    mov bl, [edi]
    cmp bl, 0
    je .check_end
    cmp al, bl
    jne .not_equal
    inc esi
    inc edi
    jmp .compare_loop

.check_end:
    cmp al, 0
    je .equal
    cmp al, ' '
    je .equal
    cmp al, 0x0D
    je .equal
    cmp al, 0x0A
    je .equal

.not_equal:
    clc
    jmp .done

.equal:
    stc
.done:
    pop ebx
    pop eax
    pop edi
    pop esi
    ret

print_number:
    push eax
    push ebx
    push ecx
    push edx
    mov ebx, 10
    xor ecx, ecx
    test eax, eax
    jnz .convert_loop
    mov al, '0'
    call print_char
    jmp .done
.convert_loop:
    xor edx, edx
    div ebx
    push dx
    inc ecx
    test eax, eax
    jnz .convert_loop
.print_loop:
    pop ax
    add al, '0'
    call print_char
    loop .print_loop
.done:
    pop edx
    pop ecx
    pop ebx
    pop eax
    ret

delay:
    push ecx
    mov ecx, 0xFFFFF
.delay_loop:
    nop
    loop .delay_loop
    pop ecx
    ret

do_echo:
    ;                        -com
    mov esi, command_buffer + 5  ;       "echo "
    
    ;                   
.skip_spaces:
    cmp byte [esi], ' '
    jne .check_flag
    inc esi
    jmp .skip_spaces

.check_flag:
    ;                "-com"
    cmp word [esi], '-c'
    jne .normal_echo  ;         -com,         echo
    cmp byte [esi+2], 'o'
    jne .normal_echo
    cmp byte [esi+3], 'm'
    jne .normal_echo
    
    ;       -com!                          
    add esi, 4        ;            "-com"
    
.skip_after_flag:
    cmp byte [esi], ' '
    jne .get_text
    inc esi
    jmp .skip_after_flag

.get_text:
    ; ESI                          
    call serial_init  ;                COM     
    
    ;                    COM1
    call serial_puts
    
    ;                         
    mov al, 0x0D
    call serial_putc
    mov al, 0x0A  
    call serial_putc
    
    mov esi, echo_com_sent_msg
    call print_string
    ret

.normal_echo:
    ;         echo (                     )
    add esi, 5
    call print_string
    call print_newline
    ret
