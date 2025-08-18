@echo off
setlocal enabledelayedexpansion

:: Check if running as administrator and auto-elevate if not
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

if "%choice%"=="1" goto backup_drivers
if "%choice%"=="2" goto restore_drivers
if "%choice%"=="3" goto exit_script
echo Invalid choice. Please enter 1, 2, or 3.
timeout /t 2 >nul
goto main_menu

:backup_drivers
cls
echo.
echo ===============================================
echo             BACKUP DRIVERS
echo ===============================================
echo.
echo This will export all third-party drivers from your system.
echo.

:backup_path_input
set /p backup_path="Enter the destination folder path (or press Enter for default C:\DriverBackup): "

:: Set default path if none provided
if "%backup_path%"=="" set backup_path=C:\DriverBackup

:: Remove trailing backslash if present
if "%backup_path:~-1%"=="\" set backup_path=%backup_path:~0,-1%

echo.
echo Backup destination: %backup_path%
echo.
set /p confirm="Is this correct? (Y/N): "
if /i not "%confirm%"=="Y" goto backup_path_input

:: Create directory if it doesn't exist
if not exist "%backup_path%" (
    echo Creating directory: %backup_path%
    mkdir "%backup_path%" 2>nul
    if !errorLevel! neq 0 (
        echo ERROR: Failed to create directory. Please check the path and permissions.
        pause
        goto backup_drivers
    )
)

:: Check if directory is writable
echo test > "%backup_path%\test.tmp" 2>nul
if !errorLevel! neq 0 (
    echo ERROR: Cannot write to the specified directory. Please check permissions.
    pause
    goto backup_drivers
) else (
    del "%backup_path%\test.tmp" 2>nul
)

echo.
echo ===============================================
echo Starting driver backup...
echo This may take several minutes...
echo ===============================================
echo.

:: Execute the backup command
dism /online /export-driver /destination:"%backup_path%"

if %errorLevel% equ 0 (
    echo.
    echo ===============================================
    echo     BACKUP COMPLETED SUCCESSFULLY!
    echo ===============================================
    echo.
    echo Drivers have been backed up to: %backup_path%
    echo.
    :: Count the backed up drivers
    for /f %%i in ('dir "%backup_path%\*.inf" /s /b 2^>nul ^| find /c /v ""') do set driver_count=%%i
    echo Total drivers backed up: !driver_count!
) else (
    echo.
    echo ===============================================
    echo         BACKUP FAILED!
    echo ===============================================
    echo.
    echo An error occurred during the backup process.
    echo Error code: %errorLevel%
    echo Please check the destination path and try again.
)

echo.
pause
goto main_menu

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

:restore_path_input
set /p restore_path="Enter the source folder path (where driver backup is located): "

if "%restore_path%"=="" (
    echo ERROR: Please specify a valid path.
    goto restore_path_input
)

:: Remove trailing backslash if present
if "%restore_path:~-1%"=="\" set restore_path=%restore_path:~0,-1%

:: Check if path exists
if not exist "%restore_path%" (
    echo ERROR: The specified path does not exist.
    echo Path: %restore_path%
    echo.
    set /p retry="Try again? (Y/N): "
    if /i "!retry!"=="Y" goto restore_path_input
    goto main_menu
)

:: Check for .inf files
dir "%restore_path%\*.inf" /s >nul 2>&1
if %errorLevel% neq 0 (
    echo WARNING: No .inf files found in the specified directory.
    echo Path: %restore_path%
    echo.
    set /p retry="Try a different path? (Y/N): "
    if /i "!retry!"=="Y" goto restore_path_input
    goto main_menu
)

:: Count available drivers
for /f %%i in ('dir "%restore_path%\*.inf" /s /b 2^>nul ^| find /c /v ""') do set available_drivers=%%i

echo.
echo Restore source: %restore_path%
echo Available drivers found: !available_drivers!
echo.
echo WARNING: This operation will install drivers on your system.
echo Make sure you trust the source of these drivers.
echo.
set /p final_confirm="Do you want to proceed with the restore? (Y/N): "
if /i not "%final_confirm%"=="Y" goto main_menu

echo.
echo ===============================================
echo Starting driver restore...
echo This may take several minutes...
echo ===============================================
echo.

:: Execute the restore command
pnputil /add-driver "%restore_path%\*.inf" /subdirs /install

if %errorLevel% equ 0 (
    echo.
    echo ===============================================
    echo     RESTORE COMPLETED SUCCESSFULLY!
    echo ===============================================
    echo.
    echo Drivers have been restored from: %restore_path%
    echo.
    echo NOTE: Some drivers may require a system restart to take effect.
    echo.
    set /p restart="Do you want to restart now? (Y/N): "
    if /i "!restart!"=="Y" (
        echo Restarting system in 10 seconds...
        shutdown /r /t 10 /c "System restart required for driver installation"
        exit /b 0
    )
) else (
    echo.
    echo ===============================================
    echo         RESTORE FAILED!
    echo ===============================================
    echo.
    echo An error occurred during the restore process.
    echo Error code: %errorLevel%
    echo.
    echo Possible causes:
    echo - Invalid or corrupted driver files
    echo - Incompatible drivers for this system
    echo - Insufficient permissions
    echo.
    echo Please check the source files and try again.
)

echo.
pause
goto main_menu

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
