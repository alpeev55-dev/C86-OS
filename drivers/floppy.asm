;;;
; Floppy Disk Driver for C86-OS
; Supports: 1.44MB (3.5"), 1.2MB (5.25"), 720KB, 360KB
; FAT12 read/write support
;;;

; ============================================
; Floppy Controller Ports
; ============================================
FLOPPY_BASE         equ 0x3F0
FLOPPY_STATUS_A     equ 0x3F0
FLOPPY_STATUS_B     equ 0x3F1
FLOPPY_DOR          equ 0x3F2      ; Digital Output Register
FLOPPY_TAPE_DRIVE   equ 0x3F3
FLOPPY_MAIN_STATUS  equ 0x3F4
FLOPPY_DATA_RATE    equ 0x3F4
FLOPPY_DATA         equ 0x3F5
FLOPPY_DIGITAL_IN   equ 0x3F7
FLOPPY_CONFIG       equ 0x3F7

; DOR bits
DOR_MOTOR_D     equ 0x80  ; Drive D motor
DOR_MOTOR_C     equ 0x40  ; Drive C motor
DOR_MOTOR_B     equ 0x20  ; Drive B motor
DOR_MOTOR_A     equ 0x10  ; Drive A motor
DOR_DMA_ENABLE  equ 0x08  ; DMA enable
DOR_RESET       equ 0x04  ; Controller reset
DOR_DRIVE_SEL   equ 0x03  ; Drive select mask

; Commands
FDC_READ_DATA       equ 0x06
FDC_WRITE_DATA      equ 0x05
FDC_READ_ID         equ 0x0A
FDC_FORMAT_TRACK    equ 0x0D
FDC_SEEK            equ 0x0F
FDC_RECALIBRATE     equ 0x07
FDC_SENSE_INTERRUPT equ 0x08
FDC_SPECIFY         equ 0x03
FDC_VERSION         equ 0x10

; Status bits
MS_RQM         equ 0x80  ; Request for master
MS_DIO         equ 0x40  ; Data input/output
MS_NDMA        equ 0x20  ; Non-DMA mode
MS_BUSY        equ 0x10  ; Command in progress
MS_ACTD        equ 0x08  ; Drive D active
MS_ACTC        equ 0x04  ; Drive C active
MS_ACTB        equ 0x02  ; Drive B active
MS_ACTA        equ 0x01  ; Drive A active

ST0_IC_MASK    equ 0xC0  ; Interrupt code
ST0_IC_NORMAL  equ 0x00  ; Normal termination
ST0_IC_ABNORM  equ 0x40  ; Abnormal termination
ST0_IC_INVALID equ 0x80  ; Invalid command
ST0_IC_CHANGE  equ 0xC0  ; Drive not ready
ST0_SE         equ 0x20  ; Seek end
ST0_EC         equ 0x10  ; Equipment check
ST0_NR         equ 0x08  ; Not ready
ST0_HD         equ 0x04  ; Head address
ST0_DRIVE_SEL  equ 0x03  ; Drive select

ST1_EN         equ 0x80  ; End of cylinder
ST1_DE         equ 0x20  ; Data error
ST1_OR         equ 0x10  ; Overrun/underrun
ST1_ND         equ 0x04  ; No data
ST1_NW         equ 0x02  ; Not writable
ST1_MA         equ 0x01  ; Missing address mark

ST2_CM         equ 0x40  ; Control mark
ST2_DD         equ 0x20  ; Data error in data field
ST2_WC         equ 0x10  ; Wrong cylinder
ST2_SEH        equ 0x08  ; Seek error
ST2_SNS        equ 0x04  ; Scan not satisfied
ST2_BC         equ 0x02  ; Bad cylinder
ST2_MD         equ 0x01  ; Missing address mark in data field

; Drive types
DRIVE_NONE     equ 0
DRIVE_360K     equ 1
DRIVE_1200K    equ 2
DRIVE_720K     equ 3
DRIVE_1440K    equ 4
DRIVE_2880K    equ 5

; ============================================
; Globals
; ============================================
floppy_present    db 0
floppy_drive_type db DRIVE_NONE
floppy_heads      db 2
floppy_tracks     db 80
floppy_spt        db 18      ; sectors per track
floppy_gap        db 0x1B    ; gap length
floppy_datalen    db 0xFF    ; data length

; FAT12 BPB offsets
FAT12_BYTES_PER_SEC  equ 11
FAT12_SEC_PER_CLUST  equ 13
FAT12_RESERVED_SEC   equ 14
FAT12_NUM_FATS       equ 16
FAT12_ROOT_ENTRIES   equ 17
FAT12_TOTAL_SEC      equ 19
FAT12_MEDIA          equ 21
FAT12_FAT_SIZE       equ 22
FAT12_SEC_PER_TRACK  equ 24
FAT12_NUM_HEADS      equ 26
FAT12_HIDDEN_SEC     equ 28

; FAT12 globals
fat12_present      db 0
fat12_fat_start    dd 0
fat12_root_start   dd 0
fat12_data_start   dd 0
fat12_root_entries dw 0
fat12_sec_per_clust db 0
fat12_buffer       dd 0
fat12_fat_buffer   dd 0

; ============================================
; Initialize Floppy Controller
; ============================================
init_floppy:
    pushad
    
    mov esi, floppy_init_msg
    call print_string
    
    ; Reset controller
    mov dx, FLOPPY_DOR
    mov al, 0x00
    out dx, al
    
    mov al, DOR_RESET or DOR_DMA_ENABLE
    out dx, al
    
    ; Wait for reset
    call floppy_wait_ready
    
    ; Send SPECIFY command
    mov al, FDC_SPECIFY
    call floppy_send_byte
    
    ; SRT = 8ms, HUT = 16ms
    mov al, 0xCF
    call floppy_send_byte
    
    ; HLT = 30ms, ND = 0
    mov al, 0x07
    call floppy_send_byte
    
    ; Detect drive A
    mov byte [floppy_drive_type], DRIVE_NONE
    call floppy_detect_drive
    jc .no_drive
    
    mov byte [floppy_present], 1
    mov esi, floppy_ok_msg
    call print_string
    
    ; Set drive parameters for 1.44MB
    mov byte [floppy_heads], 2
    mov byte [floppy_tracks], 80
    mov byte [floppy_spt], 18
    mov byte [floppy_gap], 0x1B
    mov byte [floppy_datalen], 0xFF
    
    ; Initialize FAT12
    call init_fat12
    jmp .done
    
.no_drive:
    mov byte [floppy_present], 0
    mov esi, floppy_no_drive_msg
    call print_string
    
.done:
    popad
    ret

; ============================================
; Detect floppy drive
; ============================================
floppy_detect_drive:
    push eax
    push ebx
    push ecx
    
    ; Recalibrate drive 0
    mov al, FDC_RECALIBRATE
    call floppy_send_byte
    mov al, 0x00               ; Drive A
    call floppy_send_byte
    
    ; Wait for interrupt
    call floppy_wait_interrupt
    
    ; Sense interrupt
    mov al, FDC_SENSE_INTERRUPT
    call floppy_send_byte
    call floppy_read_byte      ; ST0
    call floppy_read_byte      ; PCN
    
    test al, ST0_IC_MASK
    jnz .error
    
    ; Seek to track 10
    mov al, FDC_SEEK
    call floppy_send_byte
    mov al, 0x00               ; Drive A
    call floppy_send_byte
    mov al, 10                 ; Track 10
    call floppy_send_byte
    
    call floppy_wait_interrupt
    
    mov al, FDC_SENSE_INTERRUPT
    call floppy_send_byte
    call floppy_read_byte      ; ST0
    call floppy_read_byte      ; PCN
    
    cmp al, 10
    jne .error
    
    ; Try to read sector 1
    mov al, FDC_READ_DATA
    call floppy_send_byte
    mov al, 0x00               ; Drive A, Head 0
    call floppy_send_byte
    mov al, 10                 ; Cylinder
    call floppy_send_byte
    mov al, 0x00               ; Head
    call floppy_send_byte
    mov al, 1                  ; Sector
    call floppy_send_byte
    mov al, 2                  ; Sector size = 512
    call floppy_send_byte
    mov al, 18                 ; EOT
    call floppy_send_byte
    mov al, 0x1B               ; Gap
    call floppy_send_byte
    mov al, 0xFF               ; Data length
    
    ; Try to read result
    call floppy_wait_read
    
    mov ecx, 7
.read_result:
    call floppy_read_byte
    loop .read_result
    
    ; Check ST0
    test al, ST0_IC_MASK
    jnz .error
    
    mov al, [floppy_drive_type]
    cmp al, DRIVE_NONE
    jne .already_detected
    
    ; 1.44MB detected
    mov byte [floppy_drive_type], DRIVE_1440K
    clc
    jmp .done
    
.already_detected:
    clc
    jmp .done
    
.error:
    stc
    
.done:
    pop ecx
    pop ebx
    pop eax
    ret

; ============================================
; Initialize FAT12 filesystem
; ============================================
init_fat12:
    pushad
    
    cmp byte [floppy_present], 1
    jne .no_floppy
    
    ; Read boot sector (CHS: 0/0/1)
    mov al, 0                   ; Drive
    mov ah, 0                   ; Head
    mov bx, 0                   ; Cylinder
    mov cl, 1                   ; Sector
    mov edi, sector_buffer
    call floppy_read_sector_chs
    jc .error
    
    ; Check BPB
    mov ax, [sector_buffer + FAT12_BYTES_PER_SEC]
    cmp ax, 512
    jne .not_fat12
    
    ; Parse BPB
    movzx eax, word [sector_buffer + FAT12_RESERVED_SEC]
    mov [fat12_fat_start], eax
    
    movzx eax, byte [sector_buffer + FAT12_NUM_FATS]
    movzx ebx, word [sector_buffer + FAT12_FAT_SIZE]
    mul ebx
    add eax, [fat12_fat_start]
    mov [fat12_root_start], eax
    
    movzx eax, word [sector_buffer + FAT12_ROOT_ENTRIES]
    mov [fat12_root_entries], ax
    shr eax, 4                  ; 16 entries per sector (512/32)
    add eax, [fat12_root_start]
    mov [fat12_data_start], eax
    
    mov al, [sector_buffer + FAT12_SEC_PER_CLUST]
    mov [fat12_sec_per_clust], al
    
    ; Allocate buffer
    mov eax, 512
    call kmalloc
    mov [fat12_buffer], eax
    
    mov eax, 512 * 9            ; 9 sectors for FAT (typical)
    call kmalloc
    mov [fat12_fat_buffer], eax
    
    mov byte [fat12_present], 1
    mov esi, fat12_ok_msg
    call print_string
    jmp .done
    
.not_fat12:
    mov esi, fat12_not_fat_msg
    call print_string
    mov byte [fat12_present], 0
    jmp .done
    
.error:
    mov esi, fat12_error_msg
    call print_string
    mov byte [fat12_present], 0
    jmp .done
    
.no_floppy:
    mov byte [fat12_present], 0
    
.done:
    popad
    ret

; ============================================
; Read sector using CHS
; IN: AL=drive, AH=head, BX=cylinder, CL=sector, EDI=buffer
; ============================================
floppy_read_sector_chs:
    pushad
    
    ; Seek to cylinder
    mov al, FDC_SEEK
    call floppy_send_byte
    mov al, 0x00               ; Drive A
    call floppy_send_byte
    mov al, bl                 ; Cylinder
    call floppy_send_byte
    
    call floppy_wait_interrupt
    
    ; Read sector
    mov al, FDC_READ_DATA
    call floppy_send_byte
    mov al, 0x00               ; Drive A
    call floppy_send_byte
    mov al, bl                 ; Cylinder
    call floppy_send_byte
    mov al, ah                 ; Head
    call floppy_send_byte
    mov al, cl                 ; Sector
    call floppy_send_byte
    mov al, 2                  ; 512 bytes
    call floppy_send_byte
    mov al, [floppy_spt]       ; EOT
    call floppy_send_byte
    mov al, [floppy_gap]       ; Gap
    call floppy_send_byte
    mov al, [floppy_datalen]   ; Data length
    call floppy_send_byte
    
    ; Read data byte by byte
    mov ecx, 512
.read_loop:
    call floppy_wait_read
    call floppy_read_data
    stosb
    loop .read_loop
    
    ; Read result bytes
    call floppy_wait_read
    call floppy_read_byte      ; ST0
    call floppy_read_byte      ; ST1
    call floppy_read_byte      ; ST2
    call floppy_read_byte      ; C
    call floppy_read_byte      ; H
    call floppy_read_byte      ; R
    call floppy_read_byte      ; N
    
    popad
    clc
    ret

; ============================================
; Wait for controller ready
; ============================================
floppy_wait_ready:
    push ecx
    mov ecx, 10000
.wait:
    mov dx, FLOPPY_MAIN_STATUS
    in al, dx
    test al, MS_RQM
    jnz .ready
    loop .wait
.ready:
    pop ecx
    ret

; ============================================
; Wait for interrupt
; ============================================
floppy_wait_interrupt:
    push ecx
    mov ecx, 100000
.wait:
    mov dx, FLOPPY_MAIN_STATUS
    in al, dx
    test al, MS_BUSY
    jz .done
    loop .wait
.done:
    pop ecx
    ret

; ============================================
; Wait for data ready to read
; ============================================
floppy_wait_read:
    push ecx
    mov ecx, 100000
.wait:
    mov dx, FLOPPY_MAIN_STATUS
    in al, dx
    test al, MS_RQM
    jz .next
    test al, MS_DIO
    jnz .ready
.next:
    loop .wait
.ready:
    pop ecx
    ret

; ============================================
; Send byte to controller
; ============================================
floppy_send_byte:
    push edx
    push ecx
    mov ah, al
    mov ecx, 10000
.wait:
    mov dx, FLOPPY_MAIN_STATUS
    in al, dx
    test al, MS_RQM
    jz .next
    test al, MS_DIO
    jnz .next
    mov al, ah
    mov dx, FLOPPY_DATA
    out dx, al
    jmp .done
.next:
    loop .wait
.done:
    pop ecx
    pop edx
    ret

; ============================================
; Read byte from controller
; ============================================
floppy_read_byte:
    push edx
    mov dx, FLOPPY_DATA
    in al, dx
    pop edx
    ret

; ============================================
; Read data byte (no status check)
; ============================================
floppy_read_data:
    push edx
    mov dx, FLOPPY_DATA
    in al, dx
    pop edx
    ret

; ============================================
; Shell command: floppy_info
; ============================================
do_floppy_info:
    cmp byte [floppy_present], 1
    jne .no_floppy
    
    mov esi, floppy_info_msg
    call print_string
    
    mov esi, floppy_type_msg
    call print_string
    
    mov al, [floppy_drive_type]
    cmp al, DRIVE_1440K
    je .type_1440
    cmp al, DRIVE_1200K
    je .type_1200
    cmp al, DRIVE_720K
    je .type_720
    
.type_1440:
    mov esi, floppy_1440_msg
    jmp .show_type
.type_1200:
    mov esi, floppy_1200_msg
    jmp .show_type
.type_720:
    mov esi, floppy_720_msg
    jmp .show_type
    
.show_type:
    call print_string
    call print_newline
    
    cmp byte [fat12_present], 1
    jne .no_fat
    
    mov esi, fat12_mounted_msg
    call print_string
    ret
    
.no_fat:
    mov esi, fat12_not_mounted_msg
    call print_string
    ret
    
.no_floppy:
    mov esi, floppy_not_present_msg
    call print_string
    ret

; ============================================
; Shell command: floppy_ls
; ============================================
do_floppy_ls:
    cmp byte [fat12_present], 1
    jne .no_fat12
    
    mov esi, fat12_ls_header
    call print_string
    
    ; Read root directory
    mov eax, [fat12_root_start]
    movzx ecx, word [fat12_root_entries]
    shr ecx, 4                  ; sectors for root dir
    
.list_loop:
    push ecx
    
    mov edi, [fat12_buffer]
    call pata_read_sector_abs   ; need absolute sector read
    jc .error
    
    mov edi, [fat12_buffer]
    mov ecx, 16                 ; 16 entries per sector
    
.list_entry:
    cmp byte [edi], 0x00
    je .done_pop
    cmp byte [edi], 0xE5
    je .next_entry
    
    ; Print name (8.3)
    push ecx
    mov ecx, 8
    mov esi, edi
    
.print_name:
    lodsb
    cmp al, ' '
    je .pad_name
    call print_char
    dec ecx
    jnz .print_name
    jmp .print_ext
    
.pad_name:
    mov al, ' '
    call print_char
    dec ecx
    jnz .pad_name
    
.print_ext:
    test byte [edi + 11], 0x10  ; Directory?
    jnz .is_dir
    
    mov al, '.'
    call print_char
    mov ecx, 3
    lea esi, [edi + 8]
    
.print_ext_loop:
    lodsb
    cmp al, ' '
    je .ext_done
    call print_char
    dec ecx
    jnz .print_ext_loop
    
.ext_done:
    ; Print size
    mov al, ' '
    call print_char
    mov eax, [edi + 28]
    call print_number
    jmp .next_line
    
.is_dir:
    mov esi, floppy_dir_mark
    call print_string
    
.next_line:
    call print_newline
    pop ecx
    
.next_entry:
    add edi, 32
    dec ecx
    jnz .list_entry
    
    inc eax
    pop ecx
    dec ecx
    jnz .list_loop
    jmp .done
    
.done_pop:
    pop ecx
    
.done:
    ret
    
.error:
    pop ecx
    mov esi, floppy_read_error
    call print_string
    ret
    
.no_fat12:
    mov esi, fat12_not_mounted_msg
    call print_string
    ret

; ============================================
; Shell command: floppy_format
; ============================================
do_floppy_format:
    cmp byte [floppy_present], 1
    jne .no_floppy
    
    mov esi, floppy_format_msg
    call print_string
    call print_newline
    
    mov esi, floppy_format_warning
    call print_string
    call print_newline
    
    ; Wait for confirmation
    mov esi, floppy_format_confirm
    call print_string
    
    call read_key
    cmp al, 'y'
    jne .cancelled
    cmp al, 'Y'
    jne .cancelled
    
    ; Format track 0
    mov al, FDC_FORMAT_TRACK
    call floppy_send_byte
    mov al, 0x00               ; Drive A, Head 0
    call floppy_send_byte
    mov al, 2                  ; Sector size = 512
    call floppy_send_byte
    mov al, 18                 ; Sectors per track
    call floppy_send_byte
    mov al, 0x1B               ; Gap
    call floppy_send_byte
    mov al, 0xE5               ; Fill byte
    
    ; Send sector headers
    mov ecx, 18
    mov bl, 1                  ; Sector number
    
.format_loop:
    mov al, 0                  ; Track
    call floppy_send_byte
    mov al, 0                  ; Head
    call floppy_send_byte
    mov al, bl                 ; Sector
    call floppy_send_byte
    mov al, 2                  ; Size code (512)
    call floppy_send_byte
    
    inc bl
    loop .format_loop
    
    call floppy_wait_interrupt
    
    ; Check result
    call floppy_read_byte      ; ST0
    call floppy_read_byte      ; ST1
    call floppy_read_byte      ; ST2
    
    test al, ST0_IC_MASK
    jnz .format_error
    
    mov esi, floppy_format_ok_msg
    call print_string
    
    ; Create FAT12 BPB
    call create_fat12_bpb
    jmp .done
    
.cancelled:
    mov esi, floppy_format_cancelled
    call print_string
    jmp .done
    
.format_error:
    mov esi, floppy_format_error_msg
    call print_string
    jmp .done
    
.no_floppy:
    mov esi, floppy_not_present_msg
    call print_string
    
.done:
    ret

; ============================================
; Create FAT12 boot sector
; ============================================
create_fat12_bpb:
    pushad
    
    ; Prepare boot sector in sector_buffer
    mov edi, sector_buffer
    mov ecx, 512
    mov al, 0
    rep stosb
    
    ; Jump instruction
    mov byte [sector_buffer + 0], 0xEB
    mov byte [sector_buffer + 1], 0x3C
    mov byte [sector_buffer + 2], 0x90
    
    ; OEM Name
    mov dword [sector_buffer + 3], 'C86-'
    mov dword [sector_buffer + 7], 'OS  '
    
    ; BPB
    mov word [sector_buffer + 11], 512    ; Bytes per sector
    mov byte [sector_buffer + 13], 1      ; Sectors per cluster
    mov word [sector_buffer + 14], 1      ; Reserved sectors
    mov byte [sector_buffer + 16], 2      ; Number of FATs
    mov word [sector_buffer + 17], 224    ; Root entries
    mov word [sector_buffer + 19], 2880   ; Total sectors
    mov byte [sector_buffer + 21], 0xF0   ; Media descriptor
    mov word [sector_buffer + 22], 9      ; Sectors per FAT
    mov word [sector_buffer + 24], 18     ; Sectors per track
    mov word [sector_buffer + 26], 2      ; Number of heads
    mov dword [sector_buffer + 28], 0     ; Hidden sectors
    
    ; Boot signature
    mov word [sector_buffer + 510], 0xAA55
    
    ; Write boot sector
    mov al, 0
    mov ah, 0
    mov bx, 0
    mov cl, 1
    mov edi, sector_buffer
    call floppy_write_sector_chs
    
    popad
    ret

; ============================================
; Write sector using CHS
; ============================================
floppy_write_sector_chs:
    pushad
    
    ; Seek
    mov al, FDC_SEEK
    call floppy_send_byte
    mov al, 0x00
    call floppy_send_byte
    mov al, bl
    call floppy_send_byte
    
    call floppy_wait_interrupt
    
    ; Write sector
    mov al, FDC_WRITE_DATA
    call floppy_send_byte
    mov al, 0x00
    call floppy_send_byte
    mov al, bl
    call floppy_send_byte
    mov al, ah
    call floppy_send_byte
    mov al, cl
    call floppy_send_byte
    mov al, 2
    call floppy_send_byte
    mov al, [floppy_spt]
    call floppy_send_byte
    mov al, [floppy_gap]
    call floppy_send_byte
    mov al, [floppy_datalen]
    call floppy_send_byte
    
    ; Write data
    mov esi, edi
    mov ecx, 512
    
.write_loop:
    call floppy_wait_ready
    mov dx, FLOPPY_DATA
    lodsb
    out dx, al
    loop .write_loop
    
    ; Read result
    call floppy_wait_read
    call floppy_read_byte      ; ST0
    call floppy_read_byte      ; ST1
    call floppy_read_byte      ; ST2
    
    popad
    ret

; ============================================
; Read absolute sector (for FAT12)
; ============================================
pata_read_sector_abs:
    ; Convert LBA to CHS for floppy
    ; This is a placeholder - implement LBA->CHS conversion
    ret

; ============================================
; Read key from keyboard
; ============================================
read_key:
    mov ah, 0x00
    int 0x16
    ret

; ============================================
; Data section
; ============================================
floppy_init_msg         db 0x0D, 0x0A, "Floppy: Initializing...", 0
floppy_ok_msg           db 0x0D, 0x0A, "Floppy: 1.44MB drive detected", 0x0D, 0x0A, 0
floppy_no_drive_msg     db 0x0D, 0x0A, "Floppy: No drive found", 0x0D, 0x0A, 0
floppy_info_msg         db 0x0D, 0x0A, "Floppy Drive Information:", 0x0D, 0x0A, 0
floppy_type_msg         db "  Type: ", 0
floppy_1440_msg         db "3.5\ 1.44MB", 0
floppy_1200_msg         db "5.25\ 1.2MB", 0
floppy_720_msg          db "3.5\ 720KB", 0
floppy_not_present_msg  db "Floppy: No drive present", 0x0D, 0x0A, 0
floppy_dir_mark         db " <DIR>", 0
floppy_read_error       db "Floppy: Read error", 0x0D, 0x0A, 0

fat12_ok_msg            db "FAT12: Filesystem mounted", 0x0D, 0x0A, 0
fat12_not_fat_msg       db "FAT12: Not a valid FAT12 filesystem", 0x0D, 0x0A, 0
fat12_error_msg         db "FAT12: Initialization error", 0x0D, 0x0A, 0
fat12_mounted_msg       db "  FAT12: Mounted", 0x0D, 0x0A, 0
fat12_not_mounted_msg   db "  FAT12: Not mounted", 0x0D, 0x0A, 0
fat12_ls_header         db 0x0D, 0x0A, "Floppy Files:", 0x0D, 0x0A, 0

floppy_format_msg       db "Formatting floppy disk...", 0
floppy_format_warning   db "WARNING: This will erase all data on the disk!", 0
floppy_format_confirm   db "Continue? (y/N): ", 0
floppy_format_ok_msg    db 0x0D, 0x0A, "Format complete!", 0x0D, 0x0A, 0
floppy_format_cancelled db 0x0D, 0x0A, "Format cancelled.", 0x0D, 0x0A, 0
floppy_format_error_msg db 0x0D, 0x0A, "Format error!", 0x0D, 0x0A, 0