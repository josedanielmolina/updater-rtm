@echo off
chcp 65001 >nul
setlocal EnableDelayedExpansion

:: ============================================================
:: Script de Actualización - RTMyG Administración
:: Compatible con Windows 7 SP1+ (requiere PowerShell)
:: El nombre del ejecutable se deriva del nombre de este .bat
:: Con auto-actualización desde GitHub
:: ============================================================

set "NOMBRE_EXE=%~n0.exe"
set "VERSIONES_DOC_URL=https://docs.google.com/document/d/1TLs3j4jLR6U4Zv7dGlD12OZxjAmXypDjkfla_MtCi5M/export?format=txt"
set "UPDATER_URL=https://raw.githubusercontent.com/josedanielmolina/updater-rtm/main/RTMyG%%20Administracion%%20v52.bat"
set "CARPETA_BACKUP=backup"
set "TEMP_VERSIONES=%TEMP%\versiones_%RANDOM%.txt"
set "TEMP_MENU=%TEMP%\menu_%RANDOM%.txt"
set "TEMP_UPDATER=%TEMP%\updater_nuevo_%RANDOM%.bat"

:: Obtener directorio y ruta del script
set "SCRIPT_DIR=%~dp0"
set "SCRIPT_PATH=%~f0"
cd /d "%SCRIPT_DIR%"

echo.
echo ╔════════════════════════════════════════════════════════════╗
echo ║       ACTUALIZADOR - RTMyG Administración                  ║
echo ╚════════════════════════════════════════════════════════════╝
echo.

:: ─────────────────────────────────────────────────────────────
:: AUTO-ACTUALIZACIÓN DEL SCRIPT
:: ─────────────────────────────────────────────────────────────
if "%~1"=="--skip-update" goto skip_self_update

echo [0/5] Verificando actualizaciones del instalador...

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "$ProgressPreference = 'SilentlyContinue'; " ^
    "try { " ^
    "    $remoto = (Invoke-WebRequest -Uri '%UPDATER_URL%' -UseBasicParsing -TimeoutSec 10).Content; " ^
    "    $local = Get-Content '%SCRIPT_PATH%' -Raw -Encoding UTF8; " ^
    "    if ($remoto -ne $local) { " ^
    "        [System.IO.File]::WriteAllText('%TEMP_UPDATER%', $remoto, [System.Text.Encoding]::UTF8); " ^
    "        Write-Host 'ACTUALIZAR'; " ^
    "    } else { " ^
    "        Write-Host 'OK'; " ^
    "    } " ^
    "} catch { " ^
    "    Write-Host 'ERROR'; " ^
    "}" > "%TEMP%\update_check.txt"

set /p UPDATE_STATUS=<"%TEMP%\update_check.txt"
del "%TEMP%\update_check.txt" 2>nul

if "%UPDATE_STATUS%"=="ACTUALIZAR" (
    echo       √ Nueva versión del instalador encontrada
    echo       Actualizando...
    
    :: Crear script de actualización diferida
    echo @echo off > "%TEMP%\do_update.bat"
    echo timeout /t 1 /nobreak ^>nul >> "%TEMP%\do_update.bat"
    echo copy /Y "%TEMP_UPDATER%" "%SCRIPT_PATH%" ^>nul >> "%TEMP%\do_update.bat"
    echo del "%TEMP_UPDATER%" 2^>nul >> "%TEMP%\do_update.bat"
    echo start "" "%SCRIPT_PATH%" --skip-update >> "%TEMP%\do_update.bat"
    echo del "%%~f0" >> "%TEMP%\do_update.bat"
    
    start "" "%TEMP%\do_update.bat"
    exit /b 0
)

if "%UPDATE_STATUS%"=="OK" (
    echo       √ Instalador actualizado
)

if "%UPDATE_STATUS%"=="ERROR" (
    echo       ! No se pudo verificar actualizaciones, continuando...
)

:skip_self_update

:: ─────────────────────────────────────────────────────────────
:: PASO 1: Verificar que el proceso no esté corriendo
:: ─────────────────────────────────────────────────────────────
echo [1/5] Verificando que el programa no esté en ejecución...

tasklist /FI "IMAGENAME eq %NOMBRE_EXE%" 2>nul | find /I "%NOMBRE_EXE%" >nul
if not errorlevel 1 (
    echo.
    echo ╔════════════════════════════════════════════════════════════╗
    echo ║  ERROR: El programa está en ejecución.                     ║
    echo ║  Por favor ciérralo antes de actualizar.                   ║
    echo ╚════════════════════════════════════════════════════════════╝
    echo.
    pause
    exit /b 1
)
echo       √ Programa no está en ejecución

:: ─────────────────────────────────────────────────────────────
:: PASO 2: Descargar lista de versiones desde Google Doc
:: ─────────────────────────────────────────────────────────────
echo [2/5] Descargando lista de versiones disponibles...

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "$ProgressPreference = 'SilentlyContinue'; " ^
    "$url = '%VERSIONES_DOC_URL%'; " ^
    "try { " ^
    "    Invoke-WebRequest -Uri $url -UseBasicParsing -OutFile '%TEMP_VERSIONES%'; " ^
    "} catch { " ^
    "    Write-Host 'ERROR_DESCARGA'; " ^
    "}"

if not exist "%TEMP_VERSIONES%" (
    echo.
    echo ╔════════════════════════════════════════════════════════════╗
    echo ║  ERROR: No se pudo descargar la lista de versiones.        ║
    echo ║  Verifica tu conexión a internet.                          ║
    echo ╚════════════════════════════════════════════════════════════╝
    echo.
    pause
    exit /b 1
)

:: Verificar que no sea HTML de error
for %%A in ("%TEMP_VERSIONES%") do set "TXT_SIZE=%%~zA"
if %TXT_SIZE% LSS 10 (
    echo.
    echo ╔════════════════════════════════════════════════════════════╗
    echo ║  ERROR: Lista de versiones vacía o inaccesible.            ║
    echo ╚════════════════════════════════════════════════════════════╝
    echo.
    del "%TEMP_VERSIONES%" 2>nul
    pause
    exit /b 1
)

echo       √ Lista de versiones obtenida

:: ─────────────────────────────────────────────────────────────
:: PASO 3: Mostrar últimas 10 versiones y permitir selección
:: ─────────────────────────────────────────────────────────────
echo [3/5] Procesando versiones disponibles...
echo.

:: Usar PowerShell para procesar el archivo y mostrar menú (formato multi-línea)
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "$content = Get-Content '%TEMP_VERSIONES%' -Encoding UTF8; " ^
    "$versiones = @(); " ^
    "$currentVer = $null; " ^
    "$currentHora = $null; " ^
    "foreach ($line in $content) { " ^
    "    $trimmed = $line.Trim(); " ^
    "    if ($trimmed -match '^(\d+)\s+(\d{3,4})\s+(https://.+)$') { " ^
    "        $hora = $matches[2].PadLeft(4,'0'); " ^
    "        $horaFmt = $hora.Substring(0,2) + ':' + $hora.Substring(2,2); " ^
    "        $versiones += [PSCustomObject]@{Ver=$matches[1]; Hora=$horaFmt; Url=$matches[3]}; " ^
    "    } elseif ($trimmed -match '^(\d+)\s+(https://.+)$') { " ^
    "        $versiones += [PSCustomObject]@{Ver=$matches[1]; Hora=$null; Url=$matches[2]}; " ^
    "    } elseif ($trimmed -match '^(\d+)\s+(\d{3,4})$') { " ^
    "        $currentVer = $matches[1]; " ^
    "        $hora = $matches[2].PadLeft(4,'0'); " ^
    "        $currentHora = $hora.Substring(0,2) + ':' + $hora.Substring(2,2); " ^
    "    } elseif ($trimmed -match '^(\d+)$') { " ^
    "        $currentVer = $matches[1]; $currentHora = $null; " ^
    "    } elseif ($trimmed -match '^https://' -and $currentVer) { " ^
    "        $versiones += [PSCustomObject]@{Ver=$currentVer; Hora=$currentHora; Url=$trimmed}; " ^
    "        $currentVer = $null; $currentHora = $null; " ^
    "    } " ^
    "} " ^
    "$total = $versiones.Count; " ^
    "if ($total -eq 0) { Write-Host 'NO_VERSIONES'; exit 1; } " ^
    "$ultimas = if ($total -le 10) { $versiones } else { $versiones[($total-10)..($total-1)] }; " ^
    "$ultimas = $ultimas | Sort-Object { [int]$_.Ver }, { $_.Hora } -Descending; " ^
    "$i = 1; " ^
    "Write-Host '╔════════════════════════════════════════════════════════════╗'; " ^
    "Write-Host '║         VERSIONES DISPONIBLES (últimas 10)                 ║'; " ^
    "Write-Host '╠════════════════════════════════════════════════════════════╣'; " ^
    "foreach ($v in $ultimas) { " ^
    "    if ($v.Hora) { $verText = '{0} ({1})' -f $v.Ver, $v.Hora } else { $verText = $v.Ver }; " ^
    "    $display = '  [{0,2}] Versión {1}' -f $i, $verText; " ^
    "    Write-Host ('║' + $display.PadRight(60) + '║'); " ^
    "    Add-Content '%TEMP_MENU%' ('{0}|{1}|{2}' -f $i, $verText, $v.Url); " ^
    "    $i++; " ^
    "} " ^
    "Write-Host '╚════════════════════════════════════════════════════════════╝';"

echo.

:seleccionar_version
set /p "SELECCION=Selecciona una opción (1-10): "

:: Validar que sea número
echo %SELECCION%| findstr /r "^[0-9][0-9]*$" >nul
if errorlevel 1 (
    echo       ! Por favor ingresa un número válido
    goto seleccionar_version
)

:: Buscar la selección en el archivo temporal
set "VERSION_ELEGIDA="
set "URL_DESCARGA="
for /f "tokens=1,2,* delims=|" %%a in (%TEMP_MENU%) do (
    if "%%a"=="%SELECCION%" (
        set "VERSION_ELEGIDA=%%b"
        set "URL_DESCARGA=%%c"
    )
)

if "%VERSION_ELEGIDA%"=="" (
    echo       ! Opción no válida. Intenta de nuevo.
    goto seleccionar_version
)

echo.
echo       √ Seleccionada: Versión %VERSION_ELEGIDA%

:: ─────────────────────────────────────────────────────────────
:: PASO 4: Crear backup del ejecutable actual
:: ─────────────────────────────────────────────────────────────
echo [4/5] Verificando archivos...

if not exist "%CARPETA_BACKUP%" mkdir "%CARPETA_BACKUP%"

if exist "%NOMBRE_EXE%" (
    :: Determinar nombre de backup (old, old 1, old 2, etc.)
    set "BACKUP_BASE=%NOMBRE_EXE:.exe= old.exe%"
    
    if not exist "%CARPETA_BACKUP%\!BACKUP_BASE!" (
        copy "%NOMBRE_EXE%" "%CARPETA_BACKUP%\!BACKUP_BASE!" >nul
        echo       √ Backup creado: %CARPETA_BACKUP%\!BACKUP_BASE!
    ) else (
        set "CONTADOR=1"
        :buscar_nombre
        set "BACKUP_NOMBRE=%NOMBRE_EXE:.exe= old !CONTADOR!.exe%"
        if exist "%CARPETA_BACKUP%\!BACKUP_NOMBRE!" (
            set /a CONTADOR+=1
            goto buscar_nombre
        )
        copy "%NOMBRE_EXE%" "%CARPETA_BACKUP%\!BACKUP_NOMBRE!" >nul
        echo       √ Backup creado: %CARPETA_BACKUP%\!BACKUP_NOMBRE!
    )
) else (
    echo       √ Listo para instalar
)

:: ─────────────────────────────────────────────────────────────
:: PASO 5: Descargar y reemplazar ejecutable
:: ─────────────────────────────────────────────────────────────
echo [5/5] Descargando versión %VERSION_ELEGIDA% desde el servidor...

set "TEMP_FILE=%TEMP%\nuevo_admin_%RANDOM%.exe"

:: Usar PowerShell para descargar (URL de descarga)
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "$ProgressPreference = 'SilentlyContinue'; " ^
    "$url = '%URL_DESCARGA%'; " ^
    "$output = '%TEMP_FILE%'; " ^
    "try { " ^
    "    Invoke-WebRequest -Uri $url -UseBasicParsing -OutFile $output; " ^
    "    if ((Test-Path $output) -and ((Get-Item $output).Length -gt 1000)) { " ^
    "        Write-Host 'DESCARGA_OK'; " ^
    "    } else { " ^
    "        Write-Host 'DESCARGA_FAIL'; " ^
    "    } " ^
    "} catch { " ^
    "    Write-Host 'DESCARGA_FAIL'; " ^
    "    Write-Host $_.Exception.Message; " ^
    "}"

:: Verificar descarga
if not exist "%TEMP_FILE%" (
    echo.
    echo ╔════════════════════════════════════════════════════════════╗
    echo ║  ERROR: No se pudo descargar el archivo.                   ║
    echo ║  Verifica tu conexión a internet.                        ║
    echo ╚════════════════════════════════════════════════════════════╝
    echo.
    del "%TEMP_VERSIONES%" 2>nul
    del "%TEMP_MENU%" 2>nul
    pause
    exit /b 1
)

:: Verificar tamaño mínimo (evitar archivos HTML de error)
for %%A in ("%TEMP_FILE%") do set "FILE_SIZE=%%~zA"
if %FILE_SIZE% LSS 10000 (
    echo.
    echo ╔════════════════════════════════════════════════════════════╗
    echo ║  ERROR: El archivo descargado parece inválido.             ║
    echo ║  El archivo solicitado no está disponible.                ║
    echo ╚════════════════════════════════════════════════════════════╝
    echo.
    del "%TEMP_FILE%" 2>nul
    del "%TEMP_VERSIONES%" 2>nul
    del "%TEMP_MENU%" 2>nul
    pause
    exit /b 1
)

echo       √ Descarga completada (%FILE_SIZE% bytes)

:: Reemplazar ejecutable
echo       Reemplazando ejecutable...

if exist "%NOMBRE_EXE%" del "%NOMBRE_EXE%"
move "%TEMP_FILE%" "%NOMBRE_EXE%" >nul

:: Limpiar archivos temporales
del "%TEMP_VERSIONES%" 2>nul
del "%TEMP_MENU%" 2>nul

if exist "%NOMBRE_EXE%" (
    echo       √ Ejecutable reemplazado exitosamente
    echo.
    echo ╔════════════════════════════════════════════════════════════╗
    echo ║                                                            ║
    echo ║   ✓ ACTUALIZACIÓN A VERSIÓN %VERSION_ELEGIDA% COMPLETADA            ║
    echo ║                                                            ║
    echo ╚════════════════════════════════════════════════════════════╝
) else (
    echo.
    echo ╔════════════════════════════════════════════════════════════╗
    echo ║  ERROR: No se pudo reemplazar el ejecutable.               ║
    echo ║  Verifica los permisos de la carpeta.                      ║
    echo ╚════════════════════════════════════════════════════════════╝
)

echo.
pause
exit /b 0
