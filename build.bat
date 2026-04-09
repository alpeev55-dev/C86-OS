@echo off
setlocal EnableDelayedExpansion

echo [1/4] Setting up paths...
set "FASM_PATH=C:\Users\User\Documents\FASM.EXE"Enter the path to FASM here
set "BOOT_SRC=bootloader.asm"
set "KERNEL_SRC=kernel.asm"
set "BOOT_OUT=boot.bin"
set "KERNEL_OUT=kernel.bin"
set "OS_IMAGE=os.img"

echo [2/4] Checking files...
if not exist "%FASM_PATH%" (
echo ERROR: FASM not found at %FASM_PATH%
pause
exit /b 1
)

if not exist "%BOOT_SRC%" (
echo ERROR: %BOOT_SRC% not found!
echo Available ASM files:
dir *.asm
pause
exit /b 1
)

if not exist "%KERNEL_SRC%" (
echo ERROR: %KERNEL_SRC% not found!
echo Available ASM files:
dir *.asm
pause
exit /b 1
)

echo [3/4] Compiling bootloader...
"%FASM_PATH%" "%BOOT_SRC%" "%BOOT_OUT%"
if errorlevel 1 (
echo ERROR: Failed to compile bootloader!
pause
exit /b 1
)

echo [4/4] Compiling kernel...
"%FASM_PATH%" "%KERNEL_SRC%" "%KERNEL_OUT%"
if errorlevel 1 (
echo ERROR: Failed to compile kernel!
pause
exit /b 1
)

echo [5/5] Creating OS image...
copy /b "%BOOT_OUT%" + "%KERNEL_OUT%" "%OS_IMAGE%" > nul

if exist "%OS_IMAGE%" (
echo SUCCESS: OS image created: %OS_IMAGE%
for %%F in ("%OS_IMAGE%") do echo File size: %%~zF bytes
) else (
echo ERROR: Failed to create OS image!
echo Trying manual method...
echo n %OS_IMAGE% > create.txt
echo e 0100 >> create.txt
echo. >> create.txt
echo rcx >> create.txt
echo 2000 >> create.txt  ; 8KB размер
echo w >> create.txt
echo q >> create.txt

debug < create.txt > nul 2>&1
del create.txt

if exist "%OS_IMAGE%" (
    copy /b "%BOOT_OUT%" + "%KERNEL_OUT%" "%OS_IMAGE%" > nul
    echo SUCCESS: OS image created manually
) else (
    echo ERROR: Cannot create image file
)
)

echo.
echo Cleaning up...
if exist "%BOOT_OUT%" del "%BOOT_OUT%"
if exist "%KERNEL_OUT%" del "%KERNEL_OUT%"

echo.
if exist "%OS_IMAGE%" (
echo Build completed successfully!
echo.
) else (
echo Build failed - no OS image created
)

echo.
pause