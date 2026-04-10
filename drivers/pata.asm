; ============================================
; MINIMALISTIC PATA DRIVER
; For Protected Mode operation
; ============================================

; Ports (Primary Master)
PATA_BASE    equ 0x1F0
PATA_DATA    equ 0x1F0
PATA_ERR     equ 0x1F1
PATA_COUNT   equ 0x1F2
PATA_LBA0    equ 0x1F3
PATA_LBA1    equ 0x1F4
PATA_LBA2    equ 0x1F5
PATA_DEV     equ 0x1F6
PATA_CMD     equ 0x1F7
PATA_STATUS  equ 0x1F7

; Commands
ATA_READ     equ 0x20
ATA_IDENTIFY equ 0xEC

; Status bits
ATA_BSY      equ 0x80
ATA_RDY      equ 0x40
ATA_DRQ      equ 0x08
ATA_ERR      equ 0x01

; ============================================
; Initialization
; ============================================
init_pata:
    pushad
    
    ; Try to detect drive
    mov dx, PATA_DEV
    mov al, 0xA0      ; Master, LBA
    out dx, al
    
    call pata_wait_ready
    
    ; IDENTIFY command
    mov dx, PATA_CMD
    mov al, ATA_IDENTIFY
    out dx, al
    
    call pata_wait_drq
    
    ; Read 256 words (512 bytes) of identification data
    mov dx, PATA_DATA
    mov edi, pata_buffer
    mov ecx, 256
    rep insw
    
    ; Check validity
    cmp word [pata_buffer], 0
    je .no_disk
    
    mov byte [pata_ok], 1
    mov esi, pata_msg_ok
    call print_string
    
    ; Print model (offset 54)
    mov esi, pata_buffer + 54
    mov edi, pata_model
    mov ecx, 20
    call pata_copy_string
    mov esi, pata_model
    call print_string
    call print_newline
    jmp .done
    
.no_disk:
    mov byte [pata_ok], 0
    mov esi, pata_msg_no
    call print_string
    
.done:
    popad
    ret

; ============================================
; Wait for drive ready
; ============================================
pata_wait_ready:
    push ecx
    mov ecx, 10000
.wait:
    mov dx, PATA_STATUS
    in al, dx
    test al, ATA_BSY
    jz .ready
    loop .wait
.ready:
    pop ecx
    ret

; ============================================
; Wait for data request
; ============================================
pata_wait_drq:
    push ecx
    mov ecx, 10000
.wait:
    mov dx, PATA_STATUS
    in al, dx
    test al, ATA_BSY
    jnz .next
    test al, ATA_DRQ
    jnz .ready
.next:
    loop .wait
.ready:
    pop ecx
    ret

; ============================================
; Read sector
; IN:  EAX = LBA (28-bit)
;      EDI = buffer
; OUT: CF=1 on error
; ============================================
pata_read_sector:
    pushad
    
    cmp byte [pata_ok], 1
    jne .error
    
    call pata_wait_ready
    
    ; Select drive and LBA
    mov dx, PATA_DEV
    mov al, 0xE0
    or al, ah         ; upper 4 bits of LBA
    out dx, al
    
    ; Sector count (1)
    mov dx, PATA_COUNT
    mov al, 1
    out dx, al
    
    ; LBA (lower 24 bits)
    mov dx, PATA_LBA0
    mov al, bl
    out dx, al
    
    mov dx, PATA_LBA1
    mov al, bh
    out dx, al
    
    mov dx, PATA_LBA2
    mov al, cl
    out dx, al
    
    ; Read command
    mov dx, PATA_CMD
    mov al, ATA_READ
    out dx, al
    
    call pata_wait_drq
    
    ; Read 256 words = 512 bytes
    mov dx, PATA_DATA
    mov ecx, 256
    rep insw
    
    popad
    clc
    ret
    
.error:
    popad
    stc
    ret

; ============================================
; Copy string from ATA (swap bytes)
; ============================================
pata_copy_string:
    push ecx
.copy:
    mov al, [esi]
    mov [edi], al
    inc esi
    inc edi
    loop .copy
    mov byte [edi], 0
    pop ecx
    ret

; ============================================
; Shell command: pata_info
; ============================================
do_pata:
    call init_pata
    ret

; ============================================
; Command: read_sector LBA
; ============================================
do_read_sector:
    ; Parse LBA from arguments
    mov esi, command_buffer
    add esi, 12       ; "read_sector "
    call parse_number_2
    
    mov edi, sector_buffer
    call pata_read_sector
    jc .error
    
    mov esi, sector_buffer
    call print_string
    ret
    
.error:
    mov esi, pata_read_error
    call print_string
    ret

parse_number_2:
    push ebx
    xor eax, eax
    xor ecx, ecx
    mov ebx, 10
.next:
    mov cl, [esi]
    test cl, cl
    jz .done
    cmp cl, '0'
    jb .done
    cmp cl, '9'
    ja .done
    sub cl, '0'
    mul ebx
    add eax, ecx
    inc esi
    jmp .next
.done:
    pop ebx
    ret

; ============================================
; Data
; ============================================
pata_ok          db 0
pata_buffer:     times 512 db 0
pata_model:      times 41 db 0
sector_buffer:   times 512 db 0

pata_msg_ok      db "PATA: Drive detected - ", 0
pata_msg_no      db "PATA: No drive found", 0x0D, 0x0A, 0
pata_read_error  db 0x0D, 0x0A, "PATA: Read error", 0x0D, 0x0A, 0

; Add to command table
cmd_pata         db "pata", 0
cmd_read_sector  db "read_sector", 0

; ============================================
; Get disk size
; ============================================
do_pata_size:
    call init_pata
    
    cmp byte [pata_ok], 1
    jne .no_disk
    
    ; Read sector count from IDENTIFY
    ; Offset 60-61: LBA28 sectors (28-bit)
    ; Offset 100-103: LBA48 sectors (48-bit)
    
    mov eax, [pata_buffer + 100]  ; LBA48 lower 4 bytes
    test eax, eax
    jnz .lba48
    
    ; LBA28
    movzx eax, word [pata_buffer + 60]
    mov ebx, 512        ; sector size
    mul ebx
    jmp .show_size
    
.lba48:
    ; LBA48 - already in eax
    mov ebx, 512
    mul ebx
    
.show_size:
    ; eax = size in bytes
    push eax
    
    mov esi, pata_size_msg
    call print_string
    
    pop eax
    
    ; Convert to human readable format
    cmp eax, 1024*1024*1024  ; 1 GB
    jge .show_gb
    
    cmp eax, 1024*1024       ; 1 MB
    jge .show_mb
    
    ; Show in KB
    shr eax, 10               ; /1024
    call print_number
    mov esi, pata_kb
    call print_string
    jmp .show_sectors
    
.show_mb:
    shr eax, 20               ; / (1024*1024)
    call print_number
    mov esi, pata_mb
    call print_string
    jmp .show_sectors
    
.show_gb:
    shr eax, 30               ; / (1024*1024*1024)
    call print_number
    mov esi, pata_gb
    call print_string
    
.show_sectors:
    ; Show sector count
    mov esi, pata_sectors_msg
    call print_string
    
    ; Get sector count again
    mov eax, [pata_buffer + 100]
    test eax, eax
    jnz .show_lba48_sectors
    
    movzx eax, word [pata_buffer + 60]
    jmp .show_sectors_count
    
.show_lba48_sectors:
    mov eax, [pata_buffer + 100]
    
.show_sectors_count:
    call print_number
    call print_newline
    ret
    
.no_disk:
    mov esi, pata_no_drive_msg
    call print_string
    ret

; ============================================
; Alternative method - via CHS
; ============================================
do_pata_chs:
    call init_pata
    
    cmp byte [pata_ok], 1
    jne .no_disk
    
    ; Read CHS parameters from IDENTIFY
    mov ax, word [pata_buffer + 1]   ; cylinders
    movzx eax, ax
    push eax
    
    mov bx, word [pata_buffer + 3]   ; heads
    movzx ebx, bx
    push ebx
    
    mov cx, word [pata_buffer + 6]   ; sectors per track
    movzx ecx, cx
    push ecx
    
    mov esi, pata_chs_msg
    call print_string
    
    pop ecx
    pop ebx
    pop eax
    
    mov esi, pata_cyl_msg
    call print_string
    call print_number
    
    mov esi, pata_heads_msg
    call print_string
    mov eax, ebx
    call print_number
    
    mov esi, pata_spt_msg
    call print_string
    mov eax, ecx
    call print_number
    
    ; Total size
    mov eax, ebx
    mul ecx
    mul dword [esp]
    mov ebx, 512
    mul ebx
    
    mov esi, pata_chs_total
    call print_string
    call print_number
    mov esi, pata_bytes
    call print_string
    call print_newline
    ret
    
.no_disk:
    mov esi, pata_no_drive_msg
    call print_string
    ret
; ============================================
; Write sector
; IN: EAX = LBA, EDI = buffer
; ============================================
pata_write_sector:
    pushad
    
    cmp byte [pata_ok], 1
    jne .error
    
    call pata_wait_ready
    
    mov dx, PATA_DEV
    mov al, 0xE0
    mov ah, byte [esp + 28]
    and ah, 0x0F
    or al, ah
    out dx, al
    
    mov dx, PATA_COUNT
    mov al, 1
    out dx, al
    
    mov eax, [esp + 28]
    mov dx, PATA_LBA0
    out dx, al
    
    mov dx, PATA_LBA1
    mov al, ah
    out dx, al
    
    mov dx, PATA_LBA2
    shr eax, 16
    out dx, al
    
    mov dx, PATA_CMD
    mov al, 0x30           ; WRITE SECTORS
    out dx, al
    
    call pata_wait_drq
    
    mov dx, PATA_DATA
    mov esi, edi
    mov ecx, 256
    rep outsw
    
    call pata_wait_ready
    
    popad
    clc
    ret
    
.error:
    popad
    stc
    ret
; ============================================
; Data
; ============================================
pata_size_msg      db "Disk size: ", 0
pata_sectors_msg   db " (", 0
pata_sectors_end   db " sectors)", 0x0D, 0x0A, 0
pata_kb            db " KB", 0
pata_mb            db " MB", 0
pata_gb            db " GB", 0
pata_bytes         db " bytes", 0
pata_no_drive_msg  db "No drive", 0
pata_chs_msg       db 0x0D, 0x0A, "CHS Parameters:", 0x0D, 0x0A, 0
pata_cyl_msg       db "  Cylinders: ", 0
pata_heads_msg     db 0x0D, 0x0A, "  Heads:     ", 0
pata_spt_msg       db 0x0D, 0x0A, "  Sectors:   ", 0
pata_chs_total     db 0x0D, 0x0A, "Total size: ", 0

; Add to command table
cmd_pata_size      db "pata_size", 0
cmd_pata_chs       db "pata_chs", 0