;ramdisk.asm

init_fs:
    mov edi, file_table
    mov ecx, MAX_FILES * FILE_SIZE
    xor al, al
    rep stosb
    
    mov esi, file_readme
    call register_file
    
    mov esi, file_test
    call register_file
    
    mov esi, file_system
    call register_file
    
    mov esi, file_config
    call register_file
    ret

register_file:
    mov edi, file_table
    mov ecx, MAX_FILES
.find_free_slot:
    cmp byte [edi], 0
    je .copy_file
    add edi, FILE_SIZE
    loop .find_free_slot
    ret

.copy_file:
    push esi
    mov ecx, 16
    rep movsb
    pop esi
    
    mov eax, [esi + 16]
    mov [edi], eax
    add edi, 4
    
    mov eax, [esi + 20]
    mov [edi], eax
    add edi, 4
    
    mov al, [esi + 24]
    mov [edi], al
    inc edi
    mov al, [esi + 25]
    mov [edi], al
    
    ret

find_file:
    push esi
    mov esi, debug_find_file
    call print_string
    pop esi
    call print_string
    call print_newline
    
    mov edi, file_table
    mov ecx, MAX_FILES
.search_loop:
    cmp byte [edi], 0
    je .next_file
    
    push esi
    push edi
    mov esi, debug_checking
    call print_string
    mov esi, edi
    call print_string
    call print_newline
    pop edi
    pop esi
    
    push esi
    push edi
    call compare_string
    pop edi
    pop esi
    jc .found
    
.next_file:
    add edi, FILE_SIZE
    loop .search_loop
    
    mov esi, debug_search_failed
    call print_string
    xor edi, edi
    ret

.found:
    mov esi, debug_search_success
    call print_string
    ret

debug_find_file:    db "FIND_FILE searching: ", 0x0D, 0x0A, 0
debug_checking:     db "Checking file...", 0x0D, 0x0A, 0
debug_search_success: db "FIND_FILE: MATCH!", 0x0D, 0x0A, 0
debug_search_failed: db "FIND_FILE: NO MATCH", 0x0D, 0x0A, 0