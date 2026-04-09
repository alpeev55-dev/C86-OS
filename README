# C86/OS
![C86/OS Screenshot](screenshot.png)
> A minimalistic 32-bit operating system written entirely in x86 assembly.

---

## Features

- **Protected Mode** (32-bit)
- **Preemptive multitasking** with round-robin scheduler
- **Text mode 80x50** (VGA) — optimized for modern displays
- **Virtual File System** (ramdisk with 4 built-in files)
- **Memory manager** (kmalloc/kfree with coalescing)
- **Custom shell** with 20+ commands

---

## Drivers

| Driver        |          Status |
|---------------|-----------------|
| PS/2 Keyboard | Working         |
| PATA/IDE      | Read only       |
| PCI Bus       | Scanner         |
| RTC           | Real-Time Clock |
| PC Speaker    | Beep support    |
| Serial (COM1) | TX only         |
| RTL8139       | Detection only  |

---

## Shell Commands

### System Info
| Command   | Description |
|-----------|----------------------------------------|
| `help`    | Show available commands                |
| `uname`   | Display kernel version                 |
| `osfetch` | System info with ASCII art             |
| `cpuinfo` | CPU details (vendor, cores, frequency) |
| `meminfo` | Memory usage statistics                |
| `date`    | Current date and time                  |
| `whoami`  | Show current user                      |
| `ps`      | List running processes                 |

### File Operations
| Command      | Description |
|--------------|-------------|
| `ls`         | List files in ramdisk |
| `cat <file>` | Display file contents |

### Hardware
| Command | Description |
|---------|-------------|
| `pci` | List PCI devices |
| `pata` | Detect PATA drives |
| `pata_size` | Show disk size |
| `pata_chs` | Show CHS parameters |
| `beep` | Test PC speaker |

### Utilities
| Command | Description |
|---------|-------------|
| `calc` | Simple calculator (+, -, *, /) |
| `echo <text>` | Print text to screen |
| `echo -com <text>` | Send text to COM1 port |
| `clear` | Clear screen |
| `reboot` | Reboot system |

---

## Building

**Requirements:**
- [FASM](https://flatassembler.net/) (Flat Assembler)

```bash
fasm bootloader.asm bootloader.bin
fasm kernel.asm kernel.bin
```

---

## Creating a Bootable Image

```bash
dd if=/dev/zero of=floppy.img bs=512 count=2880
dd if=bootloader.bin of=floppy.img conv=notrunc
dd if=kernel.bin of=floppy.img bs=512 seek=1 conv=notrunc
```

---

## Running

```bash
qemu-system-i386 -fda floppy.img -vga std -m 64
```

---
---

## License

C86/OS is released under the **BSD 3-Clause License**.

```
Copyright (c) 2026 Alpeev Timofey. All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice,
   this list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright notice,
   this list of conditions and the following disclaimer in the documentation
   and/or other materials provided with the distribution.

3. Neither the name of Alpeev Timofey nor the names of its contributors may
   be used to endorse or promote products derived from this software without
   specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
ARE DISCLAIMED.
```

See [LICENSE](LICENSE) for full text.

---

## Author

**Alpeev Timofey**

- GitHub: [@alpeev55-dev](https://github.com/alpeev55-dev)
- Project: [C86/OS](https://github.com/alpeev55-dev/C86-OS)

---

*"Those who say it cannot be done should not interrupt those doing it in assembly."*
