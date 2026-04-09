TASK_READY      equ 0
TASK_RUNNING    equ 1
TASK_SLEEPING   equ 2
TASK_ZOMBIE     equ 3

; 0-3:   eax
; 4-7:   ebx
; 8-11:  ecx
; 12-15: edx
; 16-19: esi
; 20-23: edi
; 24-27: ebp
; 28-31: esp
; 32-35: eip
; 36-39: eflags
; 40:    state
; 41:    pid
; 42:    priority
; 43:    timeslice
; 44-47: sleep_ticks
; 48-63: name (16 bytes)

TASK_SIZE equ 64

current_task    db 0
tick_counter    dd 0
schedule_locked db 0

; ============================================
; Init
; ============================================
init_scheduler:
    pushad
    
    mov edi, task_table
    mov ecx, TASK_COUNT * TASK_SIZE
    xor al, al
    rep stosb

    mov edi, task_table
    mov byte [edi + 40], TASK_RUNNING
    mov byte [edi + 41], 0
    mov byte [edi + 42], 0          
    mov byte [edi + 43], 1
    mov dword [edi + 28], KERNEL_STACK - 0x1000  ; esp
    mov dword [edi + 32], idle_task              ; eip
    mov esi, idle_task_name
    lea edi, [edi + 48]
    mov ecx, 15
    rep movsb
    
    mov edi, task_table + TASK_SIZE
    mov byte [edi + 40], TASK_READY
    mov byte [edi + 41], 1
    mov byte [edi + 42], 1
    mov byte [edi + 43], 3
    mov dword [edi + 28], KERNEL_STACK - 0x2000
    mov dword [edi + 32], shell_task
    mov esi, shell_task_name
    lea edi, [edi + 48]
    mov ecx, 15
    rep movsb
    
    mov edi, task_table + TASK_SIZE * 2
    mov byte [edi + 40], TASK_READY
    mov byte [edi + 41], 2
    mov byte [edi + 42], 1
    mov byte [edi + 43], 2
    mov dword [edi + 28], KERNEL_STACK - 0x3000
    mov dword [edi + 32], service_task
    mov esi, service_task_name
    lea edi, [edi + 48]
    mov ecx, 15
    rep movsb
    
    mov byte [current_task], 0
    mov dword [tick_counter], 0
    mov byte [schedule_locked], 0
    
    popad
    ret


scheduler_tick:
    pushad
    pushf
    
    cmp byte [schedule_locked], 1
    je .done
    
    inc dword [tick_counter]

    call update_sleeping_tasks
    

    movzx ebx, byte [current_task]
    mov eax, TASK_SIZE
    mul ebx
    mov edi, task_table
    add edi, eax
    
    dec byte [edi + 43]     ; timeslice--
    jz .do_switch
    
.done:
    popf
    popad
    ret
    
.do_switch:

    mov byte [edi + 43], 3
    
    popf                        
    popad                      
    

    mov [edi + 0], eax
    mov [edi + 4], ebx
    mov [edi + 8], ecx
    mov [edi + 12], edx
    mov [edi + 16], esi
    mov [edi + 20], edi
    mov [edi + 24], ebp
    mov [edi + 28], esp
    
    pop eax                     ; EIP
    mov [edi + 32], eax
    pop eax                     ; CS
    pop eax                     ; EFLAGS
    mov [edi + 36], eax
    
    cmp byte [edi + 40], TASK_RUNNING
    jne .find_next
    mov byte [edi + 40], TASK_READY
    
.find_next:
    call find_next_task
    
    movzx ebx, byte [current_task]
    mov eax, TASK_SIZE
    mul ebx
    mov esi, task_table
    add esi, eax
    
    mov byte [esi + 40], TASK_RUNNING
    
    mov eax, [esi + 0]
    mov ebx, [esi + 4]
    mov ecx, [esi + 8]
    mov edx, [esi + 12]
    mov edi, [esi + 20]
    mov ebp, [esi + 24]
    mov esp, [esi + 28]
    
    push dword [esi + 36]       ; EFLAGS
    push 0x08                   ; CS (from GDT)
    push dword [esi + 32]       ; EIP
    
    mov esi, [esi + 16]
    
    iret                       

find_next_task:
    pushad
    
    mov ecx, TASK_COUNT
    movzx ebx, byte [current_task]
    
.search_loop:
    inc ebx
    cmp ebx, TASK_COUNT
    jb .check
    xor ebx, ebx        ; круг
    
.check:
    push ebx
    mov eax, TASK_SIZE
    mul ebx
    mov edi, task_table
    add edi, eax
    pop ebx
    
    cmp byte [edi + 40], TASK_READY
    je .found
    
    loop .search_loop
    

    xor ebx, ebx
    mov eax, TASK_SIZE
    mul ebx
    mov edi, task_table
    add edi, eax
    mov byte [edi + 40], TASK_READY
    
.found:
    mov byte [current_task], bl
    
    popad
    ret

update_sleeping_tasks:
    pushad
    
    mov ecx, TASK_COUNT
    mov edi, task_table
    
.update_loop:
    cmp byte [edi + 40], TASK_SLEEPING
    jne .next
    
    cmp dword [edi + 44], 0
    je .wake_up
    
    dec dword [edi + 44]
    jmp .next
    
.wake_up:
    mov byte [edi + 40], TASK_READY
    
.next:
    add edi, TASK_SIZE
    loop .update_loop
    
    popad
    ret




yield:
    pushad
    
    movzx ebx, byte [current_task]
    mov eax, TASK_SIZE
    mul ebx
    mov edi, task_table
    add edi, eax
    

    mov [edi + 0], eax
    mov [edi + 4], ebx
    mov [edi + 8], ecx
    mov [edi + 12], edx
    mov [edi + 16], esi
    mov [edi + 20], edi
    mov [edi + 24], ebp
    mov [edi + 28], esp
    
    mov eax, [esp + 32]         
    mov [edi + 32], eax
 
    pushf
    pop eax
    mov [edi + 36], eax
    
    mov byte [edi + 40], TASK_READY
    mov byte [edi + 43], 3  

    call find_next_task
    

    movzx ebx, byte [current_task]
    mov eax, TASK_SIZE
    mul ebx
    mov esi, task_table
    add esi, eax
    
    mov byte [esi + 40], TASK_RUNNING
    
    mov eax, [esi + 0]
    mov ebx, [esi + 4]
    mov ecx, [esi + 8]
    mov edx, [esi + 12]
    mov edi, [esi + 20]
    mov ebp, [esi + 24]
    mov esp, [esi + 28]
    
    push dword [esi + 36]       ; EFLAGS
    push 0x08                   ; CS
    push dword [esi + 32]       ; EIP
    
    mov esi, [esi + 16]
    
    iret

sleep:
    pushad
    
    cmp eax, 0
    je .done
    
    movzx ebx, byte [current_task]
    push eax
    mov eax, TASK_SIZE
    mul ebx
    mov edi, task_table
    add edi, eax
    pop eax
    
    mov [edi + 44], eax
    mov byte [edi + 40], TASK_SLEEPING
    
    call yield
    
.done:
    popad
    ret

exit:
    movzx ebx, byte [current_task]
    mov eax, TASK_SIZE
    mul ebx
    mov edi, task_table
    add edi, eax
    
    mov byte [edi + 40], TASK_ZOMBIE
    
    call yield
    
    jmp $

start_scheduler:

    call find_next_task
    
    movzx ebx, byte [current_task]
    mov eax, TASK_SIZE
    mul ebx
    mov esi, task_table
    add esi, eax
    
    mov byte [esi + 40], TASK_RUNNING
    

    mov eax, [esi + 0]
    mov ebx, [esi + 4]
    mov ecx, [esi + 8]
    mov edx, [esi + 12]
    mov edi, [esi + 20]
    mov ebp, [esi + 24]
    mov esp, [esi + 28]
    

    pushf                       
    pop dword [esi + 36]
    push dword [esi + 36]
    push 0x08                  
    push dword [esi + 32]     
    
    mov esi, [esi + 16]
    
    iret                    


idle_task:
    sti
    hlt
    jmp idle_task

shell_task:
    call shell
    call exit
    jmp $

service_task:
.service_loop:
    mov ecx, 0xFFFF
.delay:
    nop
    loop .delay

    call yield
    jmp .service_loop


lock_schedule:
    mov byte [schedule_locked], 1
    ret

unlock_schedule:
    mov byte [schedule_locked], 0
    ret

do_ps:
    mov esi, ps_header
    call print_string
    
    mov ecx, TASK_COUNT
    mov edi, task_table
    xor ebx, ebx        
    
.ps_loop:
    cmp byte [edi + 40], TASK_ZOMBIE
    je .next_task
    
    ; task name
    lea esi, [edi + 48]
    call print_string
    
    ; Status
    mov esi, ps_state
    call print_string
    
    mov al, [edi + 40]
    cmp al, TASK_READY
    je .state_ready
    cmp al, TASK_RUNNING
    je .state_running
    cmp al, TASK_SLEEPING
    je .state_sleeping
    
.state_ready:
    mov esi, ps_ready_str
    jmp .print_state
.state_running:
    mov esi, ps_running_str
    jmp .print_state
.state_sleeping:
    mov esi, ps_sleeping_str
.print_state:
    call print_string
    

    mov esi, ps_pid
    call print_string
    movzx eax, byte [edi + 41]
    call print_number
    

    mov esi, ps_priority
    call print_string
    movzx eax, byte [edi + 42]
    call print_number
    
    call print_newline
    
.next_task:
    add edi, TASK_SIZE
    inc ebx
    loop .ps_loop
    
    ret

ps_ready_str    db "READY", 0
ps_running_str  db "RUN", 0
ps_sleeping_str db "SLEEP", 0
ps_priority     db " prio=", 0