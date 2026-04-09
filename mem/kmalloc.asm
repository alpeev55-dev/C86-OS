HEAP_START      equ 0x30000     
HEAP_INITIAL    equ 0x100000    ; 1 MB
HEAP_MAX        equ 0x1000000   ; 16 MB max
PAGE_SIZE       equ 4096
PAGE_MASK       equ 0xFFFFF000
MIN_ALLOC       equ 16          
ALIGNMENT       equ 8         

heap_start      dd HEAP_START
heap_current    dd HEAP_START
heap_end        dd HEAP_START + HEAP_INITIAL
heap_max        dd HEAP_MAX
free_list       dd 0


total_memory    dd HEAP_INITIAL
used_memory     dd 0
free_memory     dd HEAP_INITIAL
peak_memory     dd 0
alloc_count     dd 0
free_count      dd 0

init_memory:
    pushad
    
    call detect_memory_size
    
    cmp eax, [heap_max]
    jb .size_ok
    mov eax, [heap_max]
.size_ok:
    mov [total_memory], eax
    mov [free_memory], eax
    
    mov edi, [heap_start]
    mov [free_list], edi
    
    mov [edi], eax              ; size
    mov dword [edi + 4], 0      ; next = NULL
    mov dword [edi + 8], 0      ; prev = NULL
    

    add edi, eax
    mov dword [edi], 0          ; size 0
    mov dword [edi + 4], 0      ; busy
    
    mov eax, [heap_start]
    add eax, [total_memory]
    mov [heap_end], eax
    
    popad
    ret


detect_memory_size:
    mov eax, 0x100000    
.probe_loop:
    push eax
    call test_memory_address
    pop eax
    jc .probe_done
    
    add eax, 0x100000    
    cmp eax, 0x1000000   
    jb .probe_loop
    
.probe_done:
    ret

test_memory_address:
    push ebx
    push ecx
    
    mov ebx, eax
    mov ecx, [ebx]        
    mov byte [ebx], 0xAA  
    cmp byte [ebx], 0xAA  
    jne .fail
    
    mov byte [ebx], 0x55 
    cmp byte [ebx], 0x55
    jne .fail
    
    mov [ebx], ecx        
    clc
    jmp .done
    
.fail:
    stc
.done:
    pop ecx
    pop ebx
    ret


kmalloc:
    push ebx
    push ecx
    push edx
    push esi
    push edi
    

    add ecx, 11            
    and ecx, 0xFFFFFFF8    
    

    cmp ecx, MIN_ALLOC
    jae .size_ok
    mov ecx, MIN_ALLOC
.size_ok:
    

    mov esi, [free_list]
    xor edi, edi           
    
.search_loop:
    test esi, esi
    jz .expand_heap        
    
    mov eax, [esi]          
    test eax, 1             
    jnz .next_block        
    
    cmp eax, ecx
    jb .next_block          
    
    jmp .allocate_block
    
.next_block:
    mov edi, esi
    mov esi, [esi + 4]     
    jmp .search_loop

.allocate_block:
    mov ebx, eax
    sub ebx, ecx
    cmp ebx, MIN_ALLOC
    jb .use_whole_block    
    
    mov [esi], ecx          
    or dword [esi], 1           

    add esi, ecx
    mov [esi], ebx         
    and dword [esi], 0xFFFFFFFE 
    mov edx, [edi + 4]      
    mov [esi + 4], edx      
    

    mov [edi + 4], esi         

    sub esi, ecx
    add esi, 8             
    mov eax, esi
    
    jmp .update_stats

.use_whole_block:

    or dword [esi], 1       
    

    mov eax, [esi + 4]      
    mov [edi + 4], eax
    

    add esi, 8
    mov eax, esi

.update_stats:

    add [used_memory], ecx
    sub [free_memory], ecx
    inc [alloc_count]
    

    mov ebx, [used_memory]
    cmp ebx, [peak_memory]
    jbe .done
    mov [peak_memory], ebx
    
    jmp .done

.expand_heap:

    mov eax, [heap_end]
    cmp eax, [heap_max]
    jae .out_of_memory
    

    add dword [heap_end], 0x10000
    add dword [total_memory], 0x10000
    add dword [free_memory], 0x10000
    

    mov esi, [heap_end]
    sub esi, 0x10000
    mov dword [esi], 0x10000
    and dword [esi], 0xFFFFFFFE 
    mov dword [esi + 4], 0       
    

    mov ebx, [free_list]
    mov [esi + 4], ebx
    mov [free_list], esi
    

    mov esi, [free_list]
    xor edi, edi
    jmp .search_loop

.out_of_memory:
    xor eax, eax                ; return 0
    
.done:
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    ret
kfree:
    push eax
    push ebx
    push ecx
    push edx
    push esi
    push edi
    
    test eax, eax
    jz .done                    

    sub eax, 8
    mov esi, eax

    cmp esi, [heap_start]
    jb .invalid
    cmp esi, [heap_end]
    jae .invalid

    mov ecx, [esi]
    test ecx, 1
    jz .already_free

    and dword [esi], 0xFFFFFFFE

    sub [used_memory], ecx
    add [free_memory], ecx
    inc [free_count]

    mov eax, [free_list]
    mov [esi + 4], eax
    mov [free_list], esi

    call coalesce
    
    jmp .done

.invalid:
    mov esi, .invalid_msg
    call print_string
    jmp .done

.already_free:
    mov esi, .double_free_msg
    call print_string

.done:
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    pop eax
    ret

.invalid_msg     db "[kfree] Invalid pointer!", 0x0D, 0x0A, 0
.double_free_msg db "[kfree] Double free detected!", 0x0D, 0x0A, 0

coalesce:
    push esi
    push edi
    
    mov esi, [free_list]
    
.coalesce_loop:
    test esi, esi
    jz .done
    
    mov edi, [esi + 4]     
    
.next_iter:
    test edi, edi
    jz .done
    

    mov eax, esi
    add eax, [esi]        
    cmp eax, edi            
    jne .no_merge
    
    mov eax, [edi]
    test eax, 1
    jnz .no_merge
    

    mov eax, [esi]         
    add eax, [edi]         
    mov [esi], eax        
    
    mov eax, [edi + 4]
    mov [esi + 4], eax
    
    mov edi, eax
    jmp .next_iter
    
.no_merge:
    mov esi, edi
    mov edi, [esi + 4]
    jmp .coalesce_loop
    
.done:
    pop edi
    pop esi
    ret


do_meminfo:
    pushad
    
    mov esi, meminfo_header
    call print_string
    
    mov esi, meminfo_total
    call print_string
    mov eax, [total_memory]
    shr eax, 10                 
    call print_number
    mov esi, meminfo_kb
    call print_string
    
    mov esi, meminfo_used
    call print_string
    mov eax, [used_memory]
    shr eax, 10
    call print_number
    mov esi, meminfo_kb
    call print_string
    
    mov esi, meminfo_free
    call print_string
    mov eax, [free_memory]
    shr eax, 10
    call print_number
    mov esi, meminfo_kb
    call print_string
    
    mov esi, meminfo_peak
    call print_string
    mov eax, [peak_memory]
    shr eax, 10
    call print_number
    mov esi, meminfo_kb
    call print_string
    
    mov esi, meminfo_allocs
    call print_string
    mov eax, [alloc_count]
    call print_number
    call print_newline
    
    popad
    ret

meminfo_header   db 0x0D, 0x0A, "Memory Information:", 0x0D, 0x0A, 0
meminfo_total    db "  Total: ", 0
meminfo_used     db "  Used:  ", 0
meminfo_free     db "  Free:  ", 0
meminfo_peak     db "  Peak:  ", 0
meminfo_allocs   db "  Allocations: ", 0
meminfo_kb       db " KB", 0x0D, 0x0A, 0