;speaker.asm

speaker_init:
    push eax
    in al, SPEAKER_PORT
    or al, 0x03
    out SPEAKER_PORT, al
    pop eax
    ret

speaker_beep:
    pushad
    push eax
    
    mov al, 0xB6
    out PIT_CMD_PORT, al

    mov eax, 1193180
    xor edx, edx
    pop ebx
    div ebx

    out PIT_CH2_PORT, al
    mov al, ah
    out PIT_CH2_PORT, al

    in al, SPEAKER_PORT
    or al, 0x03
    out SPEAKER_PORT, al
    
    popad
    ret

speaker_off:
    push eax
    in al, SPEAKER_PORT
    and al, 0xFC
    out SPEAKER_PORT, al
    pop eax
    ret

beep:
    push eax
    mov eax, 10000
    call speaker_beep
    pop eax
    ret

delay_short:
    push ecx
    mov ecx, 0x2FFFF
.delay:
    nop
    loop .delay
    pop ecx
    ret