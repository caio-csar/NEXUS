@echo off
setlocal EnableDelayedExpansion

chcp 65001 >nul
title RESET WMI AGRESSIVO SEGURO - MAXDATA
color 0C

set "DATA=%date:~6,4%%date:~3,2%%date:~0,2%"
set "HORA=%time:~0,2%%time:~3,2%%time:~6,2%"
set "HORA=%HORA: =0%"

set "BASE=%~dp0"
set "LOG=%BASE%Reset_WMI_%DATA%_%HORA%.log"
set "WBEM=%windir%\System32\wbem"
set "REPO=%WBEM%\Repository"
set "BKP=%WBEM%\Repository.old_%DATA%_%HORA%"

echo ============================================
echo     RESET WMI AGRESSIVO, SEGURO E ROBUSTO
echo ============================================
echo.
echo Log: "%LOG%"
echo.

echo [%date% %time%] INICIO > "%LOG%"

net session >nul 2>&1
if %errorlevel% neq 0 (
    echo ERRO: execute como Administrador.
    echo [%date% %time%] ERRO: sem permissao admin >> "%LOG%"
    pause
    exit /b 1
)

if not exist "%WBEM%" (
    echo ERRO: pasta WBEM nao encontrada: "%WBEM%"
    echo [%date% %time%] ERRO: WBEM nao encontrada >> "%LOG%"
    pause
    exit /b 1
)

echo.
echo [1/10] VERIFICANDO ESTADO ATUAL DO WMI...
winmgmt /verifyrepository >> "%LOG%" 2>&1
winmgmt /salvagerepository >> "%LOG%" 2>&1

echo.
echo [2/10] PARANDO SERVICOS RELACIONADOS...
for %%S in (
    winmgmt
    iphlpsvc
    wscsvc
    wmiApSrv
) do (
    echo Parando %%S...
    net stop %%S /y >> "%LOG%" 2>&1
    sc stop %%S >> "%LOG%" 2>&1
)

timeout /t 5 /nobreak >nul

echo.
echo [3/10] FINALIZANDO PROCESSOS QUE PODEM PRENDER O WMI...
for %%P in (
    wmiprvse.exe
    wmiapsrv.exe
) do (
    taskkill /f /im %%P >> "%LOG%" 2>&1
)

timeout /t 3 /nobreak >nul

echo.
echo [4/10] AJUSTANDO PERMISSOES DO REPOSITORIO...
if exist "%REPO%" (
    takeown /f "%REPO%" /r /d y >> "%LOG%" 2>&1
    icacls "%REPO%" /grant Administrators:F /t /c >> "%LOG%" 2>&1
    icacls "%REPO%" /grant SYSTEM:F /t /c >> "%LOG%" 2>&1
)

echo.
echo [5/10] CRIANDO BACKUP DO REPOSITORIO WMI...

if exist "%REPO%" (
    echo Tentando renomear Repository...
    ren "%REPO%" "Repository.old_%DATA%_%HORA%" >> "%LOG%" 2>&1

    if exist "%BKP%" (
        echo Backup criado por renomeacao:
        echo "%BKP%"
        echo [%date% %time%] Backup criado por REN >> "%LOG%"
    ) else (
        echo Renomeacao falhou. Tentando backup por copia...
        mkdir "%BKP%" >> "%LOG%" 2>&1

        robocopy "%REPO%" "%BKP%" /E /COPYALL /R:2 /W:2 >> "%LOG%" 2>&1

        if exist "%BKP%" (
            echo Backup criado por copia:
            echo "%BKP%"
            echo [%date% %time%] Backup criado por ROBOCOPY >> "%LOG%"

            echo Removendo Repository antigo...
            attrib -r -s -h "%REPO%" /s /d >> "%LOG%" 2>&1
            rmdir /s /q "%REPO%" >> "%LOG%" 2>&1
        )
    )

    if exist "%REPO%" (
        echo.
        echo ERRO: nao foi possivel remover/renomear o Repository.
        echo Provavel bloqueio ativo do Windows.
        echo.
        echo SOLUCAO: reinicie o computador e rode este BAT logo apos iniciar.
        echo [%date% %time%] ERRO: Repository permaneceu bloqueado >> "%LOG%"
        pause
        exit /b 1
    )
) else (
    echo Repository nao existe. Prosseguindo...
    echo [%date% %time%] Repository nao encontrado >> "%LOG%"
)

echo.
echo [6/10] FORCANDO RESET FINAL DO REPOSITORIO WMI...
winmgmt /resetrepository >> "%LOG%" 2>&1

echo.
echo [7/10] INICIANDO SERVICO WMI...
net start winmgmt >> "%LOG%" 2>&1

timeout /t 8 /nobreak >nul

echo.
echo [8/10] REGISTRANDO DLLS DO WMI...
cd /d "%WBEM%"

for %%F in (*.dll) do (
    echo Registrando %%F...
    regsvr32 /s "%%F" >> "%LOG%" 2>&1
)

echo.
echo [9/10] RECOMPILANDO MOF/MFL DO WMI...
for /r "%WBEM%" %%F in (*.mof *.mfl) do (
    echo Compilando %%F...
    mofcomp "%%F" >> "%LOG%" 2>&1
)

echo.
echo REINICIANDO WMI APOS RECOMPILACAO...
net stop winmgmt /y >> "%LOG%" 2>&1
timeout /t 5 /nobreak >nul
net start winmgmt >> "%LOG%" 2>&1
timeout /t 8 /nobreak >nul

echo.
echo [10/10] TESTANDO WMI...
echo.

wmic os get Caption
wmic cpu get Name
wmic logicaldisk get Caption,FreeSpace,Size

echo.
echo VERIFICANDO REPOSITORIO FINAL...
winmgmt /verifyrepository

echo.
echo REINICIANDO SERVICOS AUXILIARES...
for %%S in (
    iphlpsvc
    wscsvc
    wmiApSrv
) do (
    net start %%S >> "%LOG%" 2>&1
)

echo.
echo ============================================
echo             PROCESSO FINALIZADO
echo ============================================
echo.
echo Log salvo em:
echo "%LOG%"
echo.
echo Backup do Repository, se existia:
echo "%BKP%"
echo.
echo OBRIGATORIO REINICIAR O WINDOWS AGORA.
echo Depois teste o ERP.
echo.
pause
exit /b 0