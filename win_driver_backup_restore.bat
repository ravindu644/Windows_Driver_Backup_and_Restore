@echo off
setlocal enabledelayedexpansion

:: ========================================================================
:: Windows Driver Backup & Restore Tool - Enhanced Version
:: Author: ravindu644
:: Description: Backup and restore Windows drivers with online/offline support
:: ========================================================================

:: Check administrator privileges and auto-elevate if needed
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo Requesting administrator privileges...
    powershell -Command "Start-Process cmd -ArgumentList '/c \"\"%~f0\"\"' -Verb RunAs"
    exit /b
)

title Windows Driver Backup ^& Restore Tool - by ravindu644

:main_menu
cls
echo.
echo ===============================================
echo    WINDOWS DRIVER BACKUP AND RESTORE TOOL
echo             by ravindu644
echo ===============================================
echo.
echo Please select an option:
echo.
echo [1] Backup Drivers
echo [2] Restore Drivers
echo [3] Exit
echo.
set /p choice="Enter your choice (1-3): "

if "%choice%"=="1" goto backup_menu
if "%choice%"=="2" goto restore_drivers
if "%choice%"=="3" goto exit_script
echo Invalid choice. Please try again.
timeout /t 2 >nul
goto main_menu

:: ========================================================================
:: BACKUP MENU - Choose between online and offline backup
:: ========================================================================
:backup_menu
cls
echo.
echo ===============================================
echo             BACKUP DRIVERS
echo ===============================================
echo.
echo Please choose backup type:
echo.
echo [1] Online Backup  - Backup from currently running Windows
echo                     (Use when Windows is working normally)
echo.
echo [2] Offline Backup - Backup from Windows on another drive
echo                     (Use when target Windows won't boot)
echo.
echo [3] Back to Main Menu
echo.
set /p backup_choice="Enter your choice (1-3): "

if "%backup_choice%"=="1" goto backup_online
if "%backup_choice%"=="2" goto backup_offline
if "%backup_choice%"=="3" goto main_menu
echo Invalid choice. Please try again.
timeout /t 2 >nul
goto backup_menu

:: ========================================================================
:: ONLINE BACKUP - Backup drivers from running system
:: ========================================================================
:backup_online
cls
echo.
echo ===============================================
echo             ONLINE DRIVER BACKUP
echo ===============================================
echo.
echo This will export all third-party drivers from your currently running system.
echo.

:get_online_backup_path
set /p backup_path="Enter destination folder path (or press Enter for default C:\DriverBackup_Online): "
if "%backup_path%"=="" set backup_path=C:\DriverBackup_Online
if "%backup_path:~-1%"=="\" set backup_path=%backup_path:~0,-1%

echo.
echo Backup destination: %backup_path%
set /p confirm="Is this correct? (Y/N): "
if /i not "%confirm%"=="Y" goto get_online_backup_path

:: Create backup directory
if not exist "%backup_path%" (
    echo Creating directory: %backup_path%
    mkdir "%backup_path%" 2>nul
    if !errorLevel! neq 0 (
        echo ERROR: Failed to create directory. Check path and permissions.
        pause
        goto backup_online
    )
)

:: Test write permissions
echo test > "%backup_path%\test.tmp" 2>nul
if !errorLevel! neq 0 (
    echo ERROR: Cannot write to directory. Check permissions.
    pause
    goto backup_online
)
del "%backup_path%\test.tmp" 2>nul

echo.
echo ===============================================
echo Starting online driver backup...
echo This may take several minutes...
echo ===============================================
echo.

:: Execute online backup
dism /online /export-driver /destination:"%backup_path%"
set backup_result=%errorLevel%

echo.
if %backup_result% equ 0 (
    echo ===============================================
    echo     BACKUP COMPLETED SUCCESSFULLY!
    echo ===============================================
    echo.
    echo Drivers have been backed up to: %backup_path%
    :: Count drivers
    for /f %%i in ('dir "%backup_path%\*.inf" /s /b 2^>nul ^| find /c /v ""') do set driver_count=%%i
    echo Total drivers backed up: !driver_count!
) else (
    echo ===============================================
    echo         BACKUP FAILED!
    echo ===============================================
    echo.
    echo Error code: %backup_result%
    echo Please check the destination path and try again.
)

pause
goto main_menu

:: ========================================================================
:: OFFLINE BACKUP - Backup drivers from non-bootable Windows installation
:: ========================================================================
:backup_offline
cls
echo.
echo ===============================================
echo            OFFLINE DRIVER BACKUP
echo ===============================================
echo.
echo This will export drivers from a Windows installation on another drive.
echo.
echo Detecting available Windows installations...

:: Detect Windows drives
set drive_count=0
for %%d in (C D E F G H I J K L M N O P Q R S T U V W X Y Z) do (
    if exist "%%d:\Windows\System32" (
        set /a drive_count+=1
        echo Found Windows installation: %%d:\
    )
)

if %drive_count% equ 0 (
    echo ERROR: No Windows installations found.
    pause
    goto main_menu
)

echo.
:select_drive
set /p target_drive="Enter drive letter of Windows installation (e.g., C): "
if "%target_drive%"=="" goto select_drive
set target_drive=%target_drive:~0,1%

if not exist "%target_drive%:\Windows\System32" (
    echo ERROR: No Windows installation found on drive %target_drive%:\
    goto select_drive
)

echo.
echo Selected: %target_drive%:\

:get_offline_backup_path
set /p backup_path="Enter destination folder path (or press Enter for default C:\DriverBackup_Offline): "
if "%backup_path%"=="" set backup_path=C:\DriverBackup_Offline
if "%backup_path:~-1%"=="\" set backup_path=%backup_path:~0,-1%

echo.
echo Source: %target_drive%:\ 
echo Destination: %backup_path%
set /p confirm="Is this correct? (Y/N): "
if /i not "%confirm%"=="Y" goto get_offline_backup_path

:: Create backup directory
if not exist "%backup_path%" (
    mkdir "%backup_path%" 2>nul
    if !errorLevel! neq 0 (
        echo ERROR: Failed to create directory.
        pause
        goto backup_offline
    )
)

echo.
echo ===============================================
echo Starting offline driver backup...
echo This may take several minutes...
echo ===============================================
echo.

:: Execute offline backup
dism /Image:%target_drive%:\ /export-driver /destination:"%backup_path%"
set backup_result=%errorLevel%

echo.
if %backup_result% equ 0 (
    echo ===============================================
    echo     BACKUP COMPLETED SUCCESSFULLY!
    echo ===============================================
    echo.
    echo Source: %target_drive%:\
    echo Destination: %backup_path%
    :: Count drivers
    for /f %%i in ('dir "%backup_path%\*.inf" /s /b 2^>nul ^| find /c /v ""') do set driver_count=%%i
    echo Total drivers backed up: !driver_count!
) else (
    echo ===============================================
    echo         BACKUP FAILED!
    echo ===============================================
    echo.
    echo Error code: %backup_result%
)

pause
goto main_menu

:: ========================================================================
:: RESTORE DRIVERS - Install drivers from backup folder
:: ========================================================================
:restore_drivers
cls
echo.
echo ===============================================
echo             RESTORE DRIVERS
echo ===============================================
echo.
echo This will install drivers from a backup folder.
echo WARNING: This will install ALL .inf files found in the specified folder and subfolders.
echo.

:get_restore_path
set /p restore_path="Enter source folder path (where driver backup is located): "
if "%restore_path%"=="" goto get_restore_path
if "%restore_path:~-1%"=="\" set restore_path=%restore_path:~0,-1%

:: Validate path exists
if not exist "%restore_path%" (
    echo ERROR: Path does not exist: %restore_path%
    set /p retry="Try again? (Y/N): "
    if /i "!retry!"=="Y" goto get_restore_path
    goto main_menu
)

:: Check for .inf files
dir "%restore_path%\*.inf" /s >nul 2>&1
if %errorLevel% neq 0 (
    echo ERROR: No .inf files found in: %restore_path%
    set /p retry="Try different path? (Y/N): "
    if /i "!retry!"=="Y" goto get_restore_path
    goto main_menu
)

:: Count available drivers
for /f %%i in ('dir "%restore_path%\*.inf" /s /b 2^>nul ^| find /c /v ""') do set available_drivers=%%i

echo.
echo Source: %restore_path%
echo Available drivers: !available_drivers!
echo.
echo WARNING: This will install drivers on your system.
echo Make sure you trust the source of these drivers.
echo.
set /p final_confirm="Proceed with restore? (Y/N): "
if /i not "%final_confirm%"=="Y" goto main_menu

echo.
echo ===============================================
echo Starting driver restore...
echo This may take several minutes...
echo ===============================================
echo.

:: Count drivers before restoration
echo Counting current drivers...
for /f %%i in ('pnputil /enum-drivers 2^>nul ^| find /c "Published Name"') do set drivers_before=%%i
echo Current drivers: !drivers_before!
echo.

:: Execute restoration - show output directly to console
echo Executing: pnputil /add-driver "%restore_path%\*.inf" /subdirs /install
echo.
echo PNPUTIL OUTPUT:
echo ================================================================================
pnputil /add-driver "%restore_path%\*.inf" /subdirs /install
set pnputil_exit_code=%errorLevel%
echo ================================================================================
echo.

:: Count drivers after restoration
echo Counting drivers after restoration...
for /f %%i in ('pnputil /enum-drivers 2^>nul ^| find /c "Published Name"') do set drivers_after=%%i
set /a drivers_installed=%drivers_after% - %drivers_before%

echo.
echo ===============================================
echo        RESTORATION SUMMARY
echo ===============================================
echo.
echo Available drivers in backup: !available_drivers!
echo Drivers before restoration: !drivers_before!
echo Drivers after restoration: !drivers_after!
echo New drivers installed: !drivers_installed!
echo PNPUTIL exit code: !pnputil_exit_code!
echo.

:: Determine success - if pnputil ran without critical error, consider it successful
:: Exit codes 0-3010 are typically successful (0=success, 3010=reboot required)
if !pnputil_exit_code! leq 3010 (
    echo ===============================================
    echo     RESTORE COMPLETED SUCCESSFULLY!
    echo ===============================================
    echo.
    if !drivers_installed! equ 0 (
        echo NOTE: No new drivers were installed. This usually means:
        echo - All drivers were already installed ^(same or newer version^)
        echo - Drivers are not compatible with this system
        echo - Drivers are not needed for current hardware
        echo.
        echo This is normal and not an error.
    ) else (
        echo Successfully installed !drivers_installed! new drivers.
    )
    echo.
    echo NOTE: Some drivers may require a restart to take effect.
    echo.
    set /p restart="Restart now? (Y/N): "
    if /i "!restart!"=="Y" (
        echo Restarting in 10 seconds...
        shutdown /r /t 10 /c "Restart required for driver installation"
        exit /b 0
    )
) else (
    echo ===============================================
    echo         RESTORE FAILED!
    echo ===============================================
    echo.
    echo PNPUTIL returned error code: !pnputil_exit_code!
    echo.
    echo Check the output above for specific error details.
)

pause
goto main_menu

:: ========================================================================
:: EXIT SCRIPT
:: ========================================================================
:exit_script
cls
echo.
echo ===============================================
echo    Thank you for using Driver Backup Tool!
echo             by ravindu644
echo ===============================================
echo.
timeout /t 2 >nul
exit /b 0
