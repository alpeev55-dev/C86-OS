;;;
; FAT32 Driver for C86-OS
; Pure x86 assembly, BIOS flat binary
; Compatible with FASM syntax
;;;

; ============================================
; FAT32 BPB Structure offsets
; ============================================
BPB_BYTES_PER_SEC  equ 11
BPB_SEC_PER_CLUST  equ 13
BPB_RESERVED_SEC   equ 14
BPB_NUM_FATS       equ 16
BPB_FAT_SIZE32     equ 36
BPB_ROOT_CLUSTER   equ 44
BPB_FSINFO         equ 48

; FAT32 Directory Entry
DIR_Name           equ 0
DIR_Attr           equ 11
DIR_FstClusHI      equ 20
DIR_FstClusLO      equ 26
DIR_FileSize       equ 28

; Attributes
ATTR_READ_ONLY     equ 0x01
ATTR_HIDDEN        equ 0x02
ATTR_SYSTEM        equ 0x04
ATTR_VOLUME_ID     equ 0x08
ATTR_DIRECTORY     equ 0x10
ATTR_ARCHIVE       equ 0x20
ATTR_LONG_NAME     equ 0x0F

; FAT32 constants
FAT32_EOC          equ 0x0FFFFFF8
FAT32_FREE         equ 0x00000000
FAT32_BAD          equ 0x0FFFFFF7

; ============================================
; Globals
; ============================================
fat32_present      db 0
partition_lba      dd 0
fat_start          dd 0
data_start         dd 0
root_cluster       dd 0
sectors_per_clust  db 0
bytes_per_sector   dw 0
sectors_per_fat    dd 0
fat_buffer         dd 0
dir_buffer         dd 0
data_buffer        dd 0

; Temporary variables
current_cluster    dd 0
file_size_temp     dd 0
temp_lba           dd 0

; ============================================
; Initialize FAT32 filesystem
; ============================================
init_fat32:
    pushad
    
    mov esi, fat32_init_msg
    call print_string
    
    ; Check if PATA is initialized
    cmp byte [pata_ok], 1
    jne .no_disk
    
    ; Read MBR (sector 0)
    mov eax, 0
    mov edi, sector_buffer
    call pata_read_sector
    jc .error
    
    ; Check for FAT32 partition (type 0x0B or 0x0C)
    mov esi, sector_buffer + 0x1BE
    mov ecx, 4
    
.check_part:
    mov al, [esi + 4]
    cmp al, 0x0B
    je .found_fat32
    cmp al, 0x0C
    je .found_fat32
    add esi, 16
    loop .check_part
    
    mov esi, fat32_no_part_msg
    call print_string
    mov byte [fat32_present], 0
    jmp .done
    
.found_fat32:
    mov eax, [esi + 8]
    mov [partition_lba], eax
    
    ; Read FAT32 boot sector
    mov edi, sector_buffer
    call pata_read_sector
    jc .error
    
    ; Parse BPB
    mov ax, [sector_buffer + BPB_BYTES_PER_SEC]
    mov [bytes_per_sector], ax
    
    mov al, [sector_buffer + BPB_SEC_PER_CLUST]
    mov [sectors_per_clust], al
    
    movzx eax, word [sector_buffer + BPB_RESERVED_SEC]
    add eax, [partition_lba]
    mov [fat_start], eax
    
    mov eax, [sector_buffer + BPB_FAT_SIZE32]
    mov [sectors_per_fat], eax
    
    movzx eax, byte [sector_buffer + BPB_NUM_FATS]
    mul dword [sectors_per_fat]
    add eax, [fat_start]
    mov [data_start], eax
    
    mov eax, [sector_buffer + BPB_ROOT_CLUSTER]
    mov [root_cluster], eax
    
    ; Allocate FAT buffer
    movzx eax, word [bytes_per_sector]
    call kmalloc
    mov [fat_buffer], eax
    
    ; Allocate directory buffer
    movzx eax, word [bytes_per_sector]
    call kmalloc
    mov [dir_buffer], eax
    
    ; Allocate data buffer (one cluster)
    movzx eax, byte [sectors_per_clust]
    movzx ebx, word [bytes_per_sector]
    mul ebx
    call kmalloc
    mov [data_buffer], eax
    
    mov byte [fat32_present], 1
    mov esi, fat32_ok_msg
    call print_string
    
    mov esi, fat32_info_msg
    call print_string
    
    mov eax, [partition_lba]
    call print_hex
    
    call print_newline
    jmp .done
    
.no_disk:
    mov esi, fat32_no_disk_msg
    call print_string
    mov byte [fat32_present], 0
    jmp .done
    
.error:
    mov esi, fat32_error_msg
    call print_string
    mov byte [fat32_present], 0
    
.done:
    popad
    ret

; ============================================
; Read FAT entry
; IN: EAX = cluster number
; OUT: EAX = next cluster (0x0FFFFFFF mask applied)
; ============================================
fat32_read_fat:
    push ebx
    push ecx
    push edx
    push edi
    push esi
    
    mov esi, eax
    
    ; Calculate sector offset
    mov eax, esi
    shl eax, 2
    movzx ecx, word [bytes_per_sector]
    xor edx, edx
    div ecx
    push edx                     ; save offset in sector
    
    ; Read FAT sector
    add eax, [fat_start]
    mov edi, [fat_buffer]
    call pata_read_sector
    jc .error
    
    ; Get entry
    pop edx
    mov edi, [fat_buffer]
    mov eax, [edi + edx]
    and eax, 0x0FFFFFFF
    
    pop esi
    pop edi
    pop edx
    pop ecx
    pop ebx
    ret
    
.error:
    pop edx
    pop esi
    pop edi
    pop edx
    pop ecx
    pop ebx
    xor eax, eax
    ret

; ============================================
; Write FAT entry
; IN: EAX = cluster number, EBX = value to write
; ============================================
fat32_write_fat:
    push ecx
    push edx
    push edi
    push esi
    
    mov esi, eax                 ; cluster number
    mov edi, ebx                 ; value to write
    
    ; Calculate sector offset
    mov eax, esi
    shl eax, 2
    movzx ecx, word [bytes_per_sector]
    xor edx, edx
    div ecx
    push edx                     ; offset in sector
    
    ; Read sector
    add eax, [fat_start]
    push eax
    mov edi, [fat_buffer]
    call pata_read_sector
    pop eax
    jc .error_pop
    
    ; Modify entry
    pop edx
    mov ebx, [fat_buffer]
    and edi, 0x0FFFFFFF
    mov ecx, [ebx + edx]
    and ecx, 0xF0000000
    or  edi, ecx
    mov [ebx + edx], edi
    
    ; Write back
    call fat32_pata_write_sector
    jc .error
    
    ; Write to second FAT
    add eax, [sectors_per_fat]
    call fat32_pata_write_sector
    
    pop esi
    pop edi
    pop edx
    pop ecx
    ret
    
.error_pop:
    pop edx
    
.error:
    pop esi
    pop edi
    pop edx
    pop ecx
    ret

; ============================================
; Cluster to LBA
; IN: EAX = cluster number
; OUT: EAX = LBA
; ============================================
cluster_to_lba:
    push ebx
    push ecx
    
    sub eax, 2
    movzx ebx, byte [sectors_per_clust]
    mul ebx
    add eax, [data_start]
    
    pop ecx
    pop ebx
    ret

; ============================================
; Read one cluster
; IN: EAX = cluster number, EDI = buffer
; ============================================
read_cluster:
    push eax
    push ecx
    push edi
    
    call cluster_to_lba
    mov [temp_lba], eax
    movzx ecx, byte [sectors_per_clust]
    
.read_loop:
    push ecx
    mov eax, [temp_lba]
    call pata_read_sector
    pop ecx
    jc .error
    
    movzx eax, word [bytes_per_sector]
    add edi, eax
    inc dword [temp_lba]
    loop .read_loop
    
    pop edi
    pop ecx
    pop eax
    clc
    ret
    
.error:
    pop edi
    pop ecx
    pop eax
    stc
    ret

; ============================================
; Parse 8.3 filename
; IN: ESI = source string
; OUT: fat32_filename filled
; ============================================
parse_filename:
    push edi
    push ecx
    push eax
    
    mov edi, fat32_filename
    mov ecx, 11
    mov al, ' '
    rep stosb
    
    mov edi, fat32_filename
    mov ecx, 8
    
.parse_name:
    lodsb
    cmp al, 0
    je .done
    cmp al, '.'
    je .parse_ext
    cmp al, ' '
    je .done
    
    cmp al, 'a'
    jl .store
    cmp al, 'z'
    jg .store
    sub al, 0x20
    
.store:
    cmp ecx, 0
    je .skip_name
    stosb
    dec ecx
    jmp .parse_name
    
.skip_name:
    lodsb
    cmp al, 0
    je .done
    cmp al, '.'
    je .parse_ext
    jmp .skip_name
    
.parse_ext:
    mov edi, fat32_filename + 8
    mov ecx, 3
    
.parse_ext_loop:
    lodsb
    cmp al, 0
    je .done
    cmp al, ' '
    je .done
    
    cmp al, 'a'
    jl .store_ext
    cmp al, 'z'
    jg .store_ext
    sub al, 0x20
    
.store_ext:
    cmp ecx, 0
    je .skip_ext
    stosb
    dec ecx
    jmp .parse_ext_loop
    
.skip_ext:
    lodsb
    cmp al, 0
    je .done
    jmp .skip_ext
    
.done:
    pop eax
    pop ecx
    pop edi
    ret

; ============================================
; Compare 8.3 name with directory entry
; IN: ESI = fat32_filename, EDI = dir_entry
; OUT: CF=1 if match
; ============================================
compare_83_name:
    push ecx
    push esi
    push edi
    
    mov ecx, 11
    repe cmpsb
    je .match
    
    clc
    jmp .done
    
.match:
    stc
    
.done:
    pop edi
    pop esi
    pop ecx
    ret

; ============================================
; Find file in directory
; IN: ESI = filename string, EAX = start cluster
; OUT: EAX = first cluster, EBX = size, CF=1 if not found
; ============================================
fat32_find_file:
    push ecx
    push edx
    push esi
    push edi
    push ebp
    
    ; Parse filename to 8.3 format
    call parse_filename
    
    mov ebp, eax                 ; start cluster
    mov esi, fat32_filename
    
.search_loop:
    cmp ebp, FAT32_EOC
    jae .not_found
    
    mov eax, ebp
    call cluster_to_lba
    mov [temp_lba], eax
    movzx ecx, byte [sectors_per_clust]
    
.search_sector:
    push ecx
    
    mov eax, [temp_lba]
    mov edi, [dir_buffer]
    call pata_read_sector
    jc .error_pop
    
    mov edi, [dir_buffer]
    movzx ecx, word [bytes_per_sector]
    shr ecx, 5
    
.search_entry:
    cmp byte [edi], 0x00
    je .not_found_pop
    cmp byte [edi], 0xE5
    je .next_entry
    
    test byte [edi + DIR_Attr], ATTR_LONG_NAME
    jnz .next_entry
    
    push esi
    push edi
    call compare_83_name
    pop edi
    pop esi
    jc .found
    
.next_entry:
    add edi, 32
    loop .search_entry
    
    inc dword [temp_lba]
    pop ecx
    loop .search_sector
    
    ; Next cluster
    mov eax, ebp
    call fat32_read_fat
    mov ebp, eax
    jmp .search_loop
    
.not_found_pop:
    pop ecx
    
.not_found:
    stc
    jmp .done_pop
    
.error_pop:
    pop ecx
    stc
    jmp .done_pop
    
.found:
    pop ecx
    movzx eax, word [edi + DIR_FstClusHI]
    shl eax, 16
    mov ax, [edi + DIR_FstClusLO]
    mov ebx, [edi + DIR_FileSize]
    clc
    
.done_pop:
    pop ebp
    pop edi
    pop esi
    pop edx
    pop ecx
    ret

; ============================================
; Shell command: fat32_ls
; ============================================
fat32_ls_cmd:
    cmp byte [fat32_present], 1
    jne .no_fat32
    
    mov eax, [root_cluster]
    mov ebp, eax
    
.list_loop:
    cmp ebp, FAT32_EOC
    jae .done
    
    mov eax, ebp
    call cluster_to_lba
    mov [temp_lba], eax
    movzx ecx, byte [sectors_per_clust]
    
.list_sector:
    push ecx
    
    mov eax, [temp_lba]
    mov edi, [dir_buffer]
    call pata_read_sector
    jc .error_pop
    
    mov edi, [dir_buffer]
    movzx ecx, word [bytes_per_sector]
    shr ecx, 5
    test ecx, ecx
    jz .skip_entries
    
.list_entry:
    cmp byte [edi], 0x00
    je .done_pop
    cmp byte [edi], 0xE5
    je .skip_entry
    
    test byte [edi + DIR_Attr], ATTR_LONG_NAME
    jnz .skip_entry
    
    ; Print name (8 chars)
    push ecx
    mov ecx, 8
    mov esi, edi
    
.print_name:
    lodsb
    cmp al, ' '
    je .pad_done
    call print_char
    dec ecx
    jnz .print_name
    jmp .print_ext
    
.pad_done:
    mov al, ' '
    call print_char
    dec ecx
    jnz .pad_done
    
.print_ext:
    test byte [edi + DIR_Attr], ATTR_DIRECTORY
    jnz .is_dir
    
    ; Print dot and extension
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
    mov al, ' '
    call print_char
    mov eax, [edi + DIR_FileSize]
    call print_number
    mov esi, fat32_bytes
    call print_string
    jmp .next_line
    
.is_dir:
    mov esi, fat32_dir_mark
    call print_string
    
.next_line:
    call print_newline
    pop ecx
    
.skip_entry:
    add edi, 32
    dec ecx
    jnz .list_entry
    
.skip_entries:
    inc dword [temp_lba]
    pop ecx
    dec ecx
    jnz .list_sector
    
    mov eax, ebp
    call fat32_read_fat
    mov ebp, eax
    jmp .list_loop
    
.done_pop:
    pop ecx
    
.done:
    ret
    
.error_pop:
    pop ecx
    mov esi, fat32_read_error
    call print_string
    ret
    
.no_fat32:
    mov esi, fat32_not_init_msg
    call print_string
    ret

; ============================================
; Shell command: fat32_cat <file>
; ============================================
fat32_cat_cmd:
    cmp byte [fat32_present], 1
    jne .no_fat32
    
    ; Get filename from command buffer
    mov esi, command_buffer + 4
    cmp byte [esi], 0
    je .no_filename
    
    ; Find file
    mov eax, [root_cluster]
    call fat32_find_file
    jc .not_found
    
    mov [file_size_temp], ebx
    mov ecx, ebx
    test ecx, ecx
    jz .done
    
    ; Read and print cluster by cluster
    mov ebp, eax
    
.read_loop:
    cmp ebp, FAT32_EOC
    jae .done
    
    mov eax, ebp
    mov edi, [data_buffer]
    call read_cluster
    jc .error
    
    ; Calculate bytes to print from this cluster
    movzx eax, byte [sectors_per_clust]
    movzx ebx, word [bytes_per_sector]
    mul ebx
    mov ebx, eax
    
    cmp ecx, ebx
    jae .print_full
    mov ebx, ecx
    
.print_full:
    push ecx
    mov esi, [data_buffer]
    mov ecx, ebx
    
.print_loop:
    lodsb
    call print_char
    loop .print_loop
    
    pop ecx
    sub ecx, ebx
    jz .done
    
    ; Next cluster
    mov eax, ebp
    call fat32_read_fat
    mov ebp, eax
    jmp .read_loop
    
.done:
    call print_newline
    ret
    
.no_filename:
    mov esi, fat32_usage_cat
    call print_string
    ret
    
.not_found:
    mov esi, fat32_not_found_msg
    call print_string
    ret
    
.error:
    mov esi, fat32_read_error
    call print_string
    ret
    
.no_fat32:
    mov esi, fat32_not_init_msg
    call print_string
    ret

; ============================================
; Shell command: fat32_write <file> <content>
; ============================================
fat32_write_cmd:
    cmp byte [fat32_present], 1
    jne .no_fat32
    
    mov esi, fat32_write_todo_msg
    call print_string
    ret
    
.no_fat32:
    mov esi, fat32_not_init_msg
    call print_string
    ret

; ============================================
; PATA write sector wrapper
; IN: EAX = LBA, EDI = buffer
; ============================================
fat32_pata_write_sector:
    pushad
    
    cmp byte [pata_ok], 1
    jne .error
    
    call pata_wait_ready
    
    mov dx, PATA_DEV
    mov al, 0xE0
    mov ah, byte [esp + 28]
    and ah, 0x0F
    or  al, ah
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
    mov al, 0x30
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
; Data section
; ============================================
fat32_init_msg      db 0x0D, 0x0A, "FAT32: Initializing...", 0
fat32_ok_msg        db 0x0D, 0x0A, "FAT32: Filesystem mounted", 0x0D, 0x0A, 0
fat32_info_msg      db "FAT32: Partition at LBA 0x", 0
fat32_no_disk_msg   db "FAT32: No disk present", 0x0D, 0x0A, 0
fat32_no_part_msg   db "FAT32: No FAT32 partition found", 0x0D, 0x0A, 0
fat32_error_msg     db "FAT32: Initialization error", 0x0D, 0x0A, 0
fat32_not_init_msg  db "FAT32: Filesystem not mounted", 0x0D, 0x0A, 0
fat32_not_found_msg db "FAT32: File not found", 0x0D, 0x0A, 0
fat32_read_error    db "FAT32: Read error", 0x0D, 0x0A, 0
fat32_dir_mark      db " <DIR>", 0
fat32_bytes         db " bytes", 0
fat32_write_todo_msg db "FAT32: Write support - TODO", 0x0D, 0x0A, 0
fat32_usage_cat     db "Usage: cat <filename>", 0x0D, 0x0A, 0

; Filename buffer (11 bytes + null)
fat32_filename      db "           ", 0