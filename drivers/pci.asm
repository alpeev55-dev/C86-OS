;pci.asm

PCI_CONFIG_ADDRESS equ 0xCF8
PCI_CONFIG_DATA    equ 0xCFC

pci_device_size equ 12  


pci_vendor_id    equ 0
pci_device_id    equ 2
pci_class_code   equ 4
pci_subclass     equ 5
pci_prog_if      equ 6
pci_revision     equ 7
pci_bus          equ 8
pci_device       equ 9
pci_function     equ 10
pci_header_type  equ 11

pci_devices: times 32 * pci_device_size db 0
pci_device_count db 0




; AL = bus, BL = device, CL = function, DL = register

pci_read_config_dword:
    push edx
    push ecx
    push ebx

    and eax, 0xFF
    shl eax, 16
    and ebx, 0x1F
    shl ebx, 11
    or eax, ebx
    and ecx, 0x07
    shl ecx, 8
    or eax, ecx
    and edx, 0xFC
    or eax, edx
    or eax, 0x80000000
    
    mov dx, PCI_CONFIG_ADDRESS
    out dx, eax
    mov dx, PCI_CONFIG_DATA
    in eax, dx
    
    pop ebx
    pop ecx
    pop edx
    ret

; AL = bus, BL = device, CL = function
pci_check_device:
    push eax
    push ebx
    push ecx
    push edx
    
    mov dl, 0x00  ; Vendor ID register
    call pci_read_config_dword
    
    cmp ax, 0xFFFF
    je .no_device
    cmp ax, 0       
    je .no_device
    
    stc
    jmp .done
    
.no_device:
    clc
.done:
    pop edx
    pop ecx
    pop ebx
    pop eax
    ret

pci_scan_bus:
    push eax
    push ebx
    push ecx
    push edi
    
    mov bl, 0
.device_loop:
    mov cl, 0   
.function_loop:
    call pci_check_device
    jnc .next_function
    call pci_save_device
    
.next_function:
    inc cl
    cmp cl, 8
    jb .function_loop
    
.next_device:
    inc bl
    cmp bl, 32
    jb .device_loop
    
    pop edi
    pop ecx
    pop ebx
    pop eax
    ret

pci_save_device:
    push eax
    push ebx
    push ecx
    push edx
    push edi
    
    movzx edi, byte [pci_device_count]
    imul edi, pci_device_size
    add edi, pci_devices
    
    ; Save bus/device/function
    mov [edi + pci_bus], al
    mov [edi + pci_device], bl
    mov [edi + pci_function], cl
    
    ; Read Vendor/Device ID
    mov dl, 0x00
    call pci_read_config_dword
    mov [edi + pci_vendor_id], ax
    shr eax, 16
    mov [edi + pci_device_id], ax
    
    ; Read Class/Subclass/ProgIf/Revision
    mov dl, 0x08
    call pci_read_config_dword
    mov [edi + pci_revision], al
    shr eax, 8
    mov [edi + pci_prog_if], al
    shr eax, 8
    mov [edi + pci_subclass], al
    shr eax, 8
    mov [edi + pci_class_code], al
    
    mov dl, 0x0C
    call pci_read_config_dword
    shr eax, 16
    mov [edi + pci_header_type], al

    inc byte [pci_device_count]
    
    pop edi
    pop edx
    pop ecx
    pop ebx
    pop eax
    ret

pci_list_devices:
    push eax
    push ebx
    push ecx
    push edx
    push esi
    push edi
    
    mov esi, pci_header_msg
    call print_string
    
    movzx ecx, byte [pci_device_count]
    test ecx, ecx
    jz .no_devices
    
    mov edi, pci_devices
.device_loop:
    call print_pci_device
    add edi, pci_device_size
    loop .device_loop
    
    jmp .done
    
.no_devices:
    mov esi, pci_no_devices_msg
    call print_string
    
.done:
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    pop eax
    ret

print_pci_device:
    push eax
    push ebx
    push ecx
    push edx
    push esi
    
    ; Bus:Device.Function
    mov esi, pci_bdf_msg
    call print_string
    
    mov al, [edi + pci_bus]
    call print_hex_byte
    mov al, ':'
    call print_char
    
    mov al, [edi + pci_device]
    call print_hex_byte
    mov al, '.'
    call print_char
    
    mov al, [edi + pci_function]
    call print_hex_byte
    
    ; Vendor:Device ID
    mov esi, pci_vendor_msg
    call print_string
    
    mov ax, [edi + pci_vendor_id]
    call print_hex_word
    
    mov al, ':'
    call print_char
    
    mov ax, [edi + pci_device_id]
    call print_hex_word
    
    ; Class/Subclass
    mov esi, pci_class_msg
    call print_string
    
    mov al, [edi + pci_class_code]
    call print_hex_byte
    
    mov al, '/'
    call print_char
    
    mov al, [edi + pci_subclass]
    call print_hex_byte
    
    ; Описание устройства
    mov esi, pci_desc_msg
    call print_string
    
    mov al, [edi + pci_class_code]
    mov bl, [edi + pci_subclass]
    call get_pci_device_name
    call print_string
    
    call print_newline
    
    pop esi
    pop edx
    pop ecx
    pop ebx
    pop eax
    ret

get_pci_device_name:
    push ebx
    push ecx
    push esi
    
    cmp al, 0x01
    jne .not_storage
    cmp bl, 0x00
    je .scsi_controller
    cmp bl, 0x01
    je .ide_controller
    cmp bl, 0x02
    je .floppy_controller
    cmp bl, 0x03
    je .unknown_storage 
    cmp bl, 0x04
    je .unknown_storage 
    cmp bl, 0x05
    je .unknown_storage 
    je .sata_controller
    jmp .unknown_storage
    
.scsi_controller:
    mov esi, pci_scsi_msg
    jmp .done
.ide_controller:
    mov esi, pci_ide_msg
    jmp .done
.floppy_controller:
    mov esi, pci_floppy_msg
    jmp .done
.sata_controller:
    mov esi, pci_sata_msg
    jmp .done
.unknown_storage:
    mov esi, pci_unknown_storage_msg
    jmp .done

.not_storage:
    ; Network Controller
    cmp al, 0x02
    jne .not_network
    mov esi, pci_network_msg
    jmp .done

.not_network:
    ; Display Controller
    cmp al, 0x03
    jne .not_display
    cmp bl, 0x00
    je .vga_controller
    cmp bl, 0x01
    je .xga_controller
    mov esi, pci_display_msg
    jmp .done
    
.vga_controller:
    mov esi, pci_vga_msg
    jmp .done
.xga_controller:
    mov esi, pci_xga_msg
    jmp .done

.not_display:
    ; Bridge Device
    cmp al, 0x06
    jne .not_bridge
    mov esi, pci_bridge_msg
    jmp .done

.not_bridge:
    ; Unknown device
    mov esi, pci_unknown_msg

.done:
    pop esi
    pop ecx
    pop ebx
    ret

print_hex_word:
    push eax
    xchg al, ah
    call print_hex_byte
    xchg al, ah
    call print_hex_byte
    pop eax
    ret

init_pci:
    mov byte [pci_device_count], 0
    mov al, 0  ; Сканируем шину 0
    call pci_scan_bus
    ret

do_pci:
    call pci_list_devices
    ret


pci_header_msg       db "PCI Devices:", 0x0D, 0x0A, 0
pci_no_devices_msg   db "No PCI devices found", 0x0D, 0x0A, 0
pci_bdf_msg          db "PCI ", 0
pci_vendor_msg       db " Vendor=", 0
pci_class_msg        db " Class=", 0
pci_desc_msg         db " (",0x0D, 0x0A, 0

pci_scsi_msg         db "SCSI Controller", 0
pci_ide_msg          db "IDE Controller", 0
pci_floppy_msg       db "Floppy Controller", 0
pci_sata_msg         db "SATA Controller", 0
pci_unknown_storage_msg db "Storage Controller", 0
pci_network_msg      db "Network Controller", 0
pci_vga_msg          db "VGA Controller", 0
pci_xga_msg          db "XGA Controller", 0
pci_display_msg      db "Display Controller", 0
pci_bridge_msg       db "Bridge Device", 0
pci_unknown_msg      db "Unknown Device", 0