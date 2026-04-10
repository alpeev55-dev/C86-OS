format binary as 'bin'
use32

org 0x10000

SPEAKER_PORT equ 0x61
PIT_CH2_PORT equ 0x42
PIT_CMD_PORT equ 0x43

VIDEO_MEMORY equ 0xB8000
SCREEN_WIDTH equ 80
SCREEN_HEIGHT equ 50
KERNEL_STACK equ 0x9FFFF
TASK_COUNT equ 3
MAX_FILES equ 16

TASK_SIZE equ 48
FILE_SIZE equ 24

TASK_READY equ 0
TASK_RUNNING equ 1
TASK_BLOCKED equ 2

vendor: rb 13
brand: rb 49
tsc_start: dq 0


kernel_start:
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    mov esp, KERNEL_STACK

    call init_video
    mov esi, line1
    call print_string

    call init_memory
    mov esi, line6
    call print_string

    call init_pata
    call init_fat32
    call init_floppy

    call init_fs
    mov esi, line2
    call print_string

    call init_pci
    mov esi, line5
    call print_string
    call init_rtc


    call init_scheduler
    mov esi, line3
    call print_string
    call print_newline

    mov esi, line4
    call print_string
    call print_newline
    call shell

    call print_newline
    call print_newline
    mov esi, line7
    call print_string
    mov esi, line8
    call print_string
    call print_newline
    call print_newline
    call init_uptime

    jmp init_scheduler

include 'mem\scheduler.asm'
include 'mem\kmalloc.asm'

include 'drivers\keyboard-ps.asm'
include 'drivers\speaker.asm'
include 'drivers\ramdisk.asm'
include 'drivers\video.asm'
include 'drivers\pci.asm'
include 'drivers\serial.asm'
include 'drivers\rtc.asm'
include 'drivers\pata.asm'
include 'drivers\fat32.asm'
include 'drivers\floppy.asm'

include 'shell.asm'
include 'packages\calc.asm'
include 'packages\whoami.asm'
include 'packages\osfetch.asm'
include 'packages\uptime.asm'

include 'data.asm'

times 65792-($-kernel_start) db 0
