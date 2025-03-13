@echo off
if not exist ".\windows" mkdir ".\windows"
if not exist ".\lib\x86_64-win64" mkdir ".\lib\x86_64-win64"

echo Compilando DANFE_Organizer para Windows...

fpc -MObjFPC -Scgi -O1 -g -gl -l -vewnhibq ^
    -Fi.\lib\x86_64-win64 ^
    -Fu. ^
    -FE.\windows ^
    -FU.\lib\x86_64-win64 ^
    DANFE_Org.lpr

if errorlevel 1 (
    echo Erro na compilacao!
    pause
) else (
    echo Compilacao concluida com sucesso!
    if exist ".\windows\DANFE_Org.exe" (
        echo Executavel criado em .\windows\DANFE_Org.exe
        echo Pressione qualquer tecla para sair...
    ) else (
        echo ERRO: Executavel nao foi gerado!
    )
    pause
)
