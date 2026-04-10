
user_name db 'user',0
 
calc_buffer: times 32 db 0
calc_num1 dd 0
calc_num2 dd 0
calc_operator db 0
calc_result_value dd 0

calc_welcome db "Enter expressions like: 5+3", 0x0D, 0x0A
             db "Supported: + - * /", 0x0D, 0x0A
             db "Empty line to exit", 0x0D, 0x0A, 0
calc_prompt db 0x0D, 0x0A,"> ", 0
calc_result db "= ", 0
calc_error db "Error: Missing operator", 0x0D, 0x0A, 0
calc_unknown_op db "Error: Unknown operator", 0x0D, 0x0A, 0
calc_div_zero db "Error: Division by zero", 0x0D, 0x0A, 0

command_buffer: rb 64
task_table: rb TASK_COUNT * TASK_SIZE
file_table: rb MAX_FILES * FILE_SIZE

idle_task_name db "Idle Task      ", 0
shell_task_name db "Shell          ", 0
service_task_name db "Service Task   ", 0

readme_data:
    db "Welcome to C86/OS!", 0x0D, 0x0A, 0
readme_end:

test_data:
    db "This is test.txt content", 0
test_data_end:

system_data:
    db "System binary data", 0
system_end:

config_data:
    db 0
config_end:

file_readme:
    db "readme.txt", 0
    times 5 db 0  
    dd readme_end - readme_data  
    dd readme_data               
    db 1, 0

file_test:
    db "test.txt", 0             
    times 8 db 0                 
    dd test_data_end - test_data 
    dd test_data                 
    db 1, 0

file_system:
    db "system.bin", 0
    times 5 db 0
    dd system_end - system_data
    dd system_data               
    db 1, 0

file_config:
    db "config.cfg", 0
    times 6 db 0
    dd config_end - config_data  
    dd config_data               
    db 1, 0

prompt_user db 0x0D,0x0A,0xDA,0xC4,0xC4,0xC4, 0
prompt_at db '', 0
prompt_end db 0x0D,0x0A,0xC0,0x1A,' ', 0
cmd_floppy_info   db "floppy", 0
cmd_floppy_ls     db "fls", 0
cmd_floppy_format db "format", 0
cmd_fat32_ls     db "ls", 0
cmd_fat32_cat    db "cat", 0
cmd_fat32_write  db "write", 0
cmd_cpuinfo db 'cpuinfo', 0
cmd_help db 'help', 0
cmd_clear db 'clear', 0
cmd_reboot db 'reboot', 0
cmd_ls db 'ls', 0
cmd_cat db 'cat', 0
cmd_ps db 'ps', 0
cmd_meminfo db 'meminfo', 0
cmd_beep db 'beep', 0
cmd_uname db 'uname',0
cmd_echo db 'echo',0
cmd_calc db 'calc', 0
cmd_fetch db 'osfetch', 0
cmd_pci db 'pci',0
cmd_syscall db 'syscall', 0
cmd_whoami db 'whoami', 0
cmd_diskinfo db 'diskio',0
cmd_date          db "date", 0

help_text:
    db 0x0D, 0x0A, "Available commands:", 0x0D, 0x0A
    db  "help     - This help",0x0D, 0x0A
    db  "clear    - Clear screen",  0x0D, 0x0A
    db  "reboot   - Reboot system",  0x0D, 0x0A
    db  "ls       - List files",  0x0D, 0x0A
    db  "cat      - Show file content",  0x0D, 0x0A
    db  "ps       - Show processes",  0x0D, 0x0A
    db  "meminfo  - Memory information", 0x0D, 0x0A
    db  "uname    - Kernel info",  0x0D, 0x0A
    db  "beep     - Play beep sound",  0x0D, 0x0A
    db  "cpuinfo  - CPU information",  0x0D, 0x0A
    db  "calc     - Simple calculator", 0x0D, 0x0A
    db  "osfetch  - OS info", 0x0D, 0x0A
    db  "echo     - Echo text",  0x0D, 0x0A, 0
ls_header db "Files:", 0x0D, 0x0A, 0
ls_file_marker db " [file]", 0

ps_header db  0x0D, 0x0A,"Processes:", 0x0D, 0x0A, 0
ps_state db " state:", 0
ps_pid db " pid:", 0

meminfo_text:
    db 0x0D, 0x0A,"", 0x0D, 0x0A, 0

kernel_info_text db 0x0D, 0x0A, 'C86/OS (32bit)', 0

file_not_found db 0x0D, 0x0A,"File not found                    ):", 0x0D, 0x0A, 0
unknown_cmd db 0x0D, 0x0A,"Unknown command                    ):", 0x0D, 0x0A, 0

line1 db 0x0D,0x0A,"Text mode (80x50, VGA)                                                      [OK]",0
line2 db 0x0D,0x0A,"VFS                                                                         [OK]",0
line3 db 0x0D,0x0A,"Scheduler                                                                   [OK]",0
line4 db 0x0D,0x0A,"Shell                                                                 [LAUNCHED]",0
line5 db 0x0D,0x0A,"PCI devices                                                                 [OK]",0
line6 db 0x0D,0x0A,"Kmalloc                                                                     [OK]",0
line7 db 0x0D,0x0A,"Welcome to C86/OS!",0x01,0x0D,0x0A,0
line8 db 'Enter ',0x22, 'help',0x22, ' to get help.',0x0D,0x0A,0


debug_found:    db "Found file: ", 0
debug_address:  db "Data at: 0x", 0
no_data_msg:    db "File has no data", 0

newline db 0x0D, 0x0A,0

cpuinfo_header:
    db 0x0D, 0x0A, "          CPU Information:", 0x0D, 0x0A, 0

cpu_vendor:
    db 0x0D,0x0A,"          Vendor: ", 0

cpu_brand:
    db 0x0D,0x0A,"          Model:  ", 0

cpu_cores:
    db 0x0D,0x0A,"          Cores:  ", 0

cpu_phys_cores:
    db "physical, ", 0

cpu_logical_cores:
    db "logical", 0

cpu_freq:
    db 0x0D,0x0A,"          Frequency: ~", 0

cpu_mhz:
    db " MHz", 0

cpu_cache:
    db 0x0D,0x0A,"          Cache: ", 0

cpu_no_cache:
    db "Unknown", 0x0D, 0x0A, 0

cpu_basic_info:
    db 0x0D,0x0A,"          Extended CPUID not supported                    ):", 0x0D, 0x0A, 0

cpu_no_cpuid:
    db 0x0D,0x0A,"          CPUID not supported                    ):", 0x0D, 0x0A, 0

keymap_normal:
    db 0,   0,   '1', '2', '3', '4', '5', '6', '7', '8', '9', '0', '-', '=', 0
    db 0,   'q', 'w', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p', '[', ']', 0
    db 0,   'a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l', ';', "'", '`', 0
    db '\', 'z', 'x', 'c', 'v', 'b', 'n', 'm', ',', '.', '/', 0,   '*', 0, ' '

keymap_shift:
    db 0,   0,   '!', '@', '#', '$', '%', '^', '&', '*', '(', ')', '_', '+', 0
    db 0,   'Q', 'W', 'E', 'R', 'T', 'Y', 'U', 'I', 'O', 'P', '{', '}', 0
    db 0,   'A', 'S', 'D', 'F', 'G', 'H', 'J', 'K', 'L', ':', '"', '~', 0
    db '|', 'Z', 'X', 'C', 'V', 'B', 'N', 'M', '<', '>', '?', 0,   '*', 0, ' '
; data.asm (          )

no_volume_msg: db "No volume label found", 0
volume_label_msg: db "Volume Label: ", 0
filesystem_msg: db "File System: ", 0
fat12_msg: db "FAT12", 0
fat16_msg: db "FAT16", 0
fat32_msg: db "FAT32", 0

geometry_msg: db "Sectors per track: ", 0
geometry_error_msg: db "Cannot get disk geometry", 0

oem_msg: db "OEM Name: ", 0
bps_msg: db "Bytes per sector: ", 0
spc_msg: db "Sectors per cluster: ", 0
total_sectors_msg: db "Total sectors: ", 0

volume_label: times 12 db 0
echo_com_sent_msg: db "Text sent to COM1", 0x0D, 0x0A, 0
screen_buffer: rb SCREEN_WIDTH * SCREEN_HEIGHT * 4 * 2
