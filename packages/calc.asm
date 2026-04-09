; ========== CALCULATOR ==========

do_calc:
    push eax
    mov al, 0x0D
    call print_char
    mov al, 0x0A
    call print_char
    
    mov esi, calc_welcome
    call print_string
    
.calc_loop:
    call print_newline
    mov esi, calc_prompt
    call print_string
    
    ; Read expression
    mov edi, calc_buffer
    mov ecx, 32
    call read_line
    
    ; Check for exit
    mov esi, calc_buffer
    cmp byte [esi], 0
    je .calc_exit
    
    ; Process expression
    call calculate_expression
    
    jmp .calc_loop
    
.calc_exit:
    pop eax
    ret

; Process expression: number operator number
calculate_expression:
    pushad
    
    mov esi, calc_buffer
    
    ; Parse first number
    call parse_number
    mov [calc_num1], eax
    
    ; Skip spaces
.skip_spaces:
    lodsb
    cmp al, ' '
    je .skip_spaces
    cmp al, 0
    je .missing_operator
    
    ; Save operator
    mov [calc_operator], al
    
    ; Parse second number
    call parse_number
    mov [calc_num2], eax
    
    ; Perform calculation
    call perform_calculation
    
    ; Print result
    call print_newline
    mov esi, calc_result
    call print_string
    mov eax, [calc_result_value]
    call print_number
    call print_newline
    
    popad
    ret

.missing_operator:
    mov esi, calc_error
    call print_string
    popad
    ret

; Parse number from string
; ESI = string, returns EAX = number
parse_number:
    push ebx
    push ecx
    xor eax, eax
    xor ebx, ebx
    xor ecx, ecx
    
.parse_loop:
    lodsb
    cmp al, '0'
    jb .parse_done
    cmp al, '9'
    ja .parse_done
    
    ; Convert digit and add to number
    sub al, '0'
    imul ebx, 10
    add ebx, eax
    jmp .parse_loop
    
.parse_done:
    dec esi         ; return last character
    mov eax, ebx
    pop ecx
    pop ebx
    ret

; Perform calculation
perform_calculation:
    mov al, [calc_operator]
    mov ebx, [calc_num1]
    mov ecx, [calc_num2]
    
    cmp al, '+'
    je .add
    cmp al, '-'
    je .sub
    cmp al, '*'
    je .mul
    cmp al, '/'
    je .div
    
    ; Unknown operator
    mov esi, calc_unknown_op
    call print_string
    ret

.add:
    add ebx, ecx
    jmp .store_result

.sub:
    sub ebx, ecx
    jmp .store_result

.mul:
    mov eax, ebx
    imul ecx
    mov ebx, eax
    jmp .store_result

.div:
    cmp ecx, 0
    je .div_zero
    mov eax, ebx
    xor edx, edx
    div ecx
    mov ebx, eax
    jmp .store_result

.div_zero:
    mov esi, calc_div_zero
    call print_string
    mov ebx, 0

.store_result:
    mov [calc_result_value], ebx
    ret