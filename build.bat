@echo off
if not exist ".\lib\x86_64-win64" mkdir ".\lib\x86_64-win64"
fpc -MObjFPC -Scgi -O1 -g -gl -l -vewnhibq -Fi.\lib\x86_64-win64 -Fu. -FE. -FU.\lib\x86_64-win64 DANFE_Org.lpr
if errorlevel 1 (
    echo Erro na compilacao!
    pause
) else (
    echo Compilacao concluida com sucesso!
    echo Pressione qualquer tecla para executar o programa...
    pause
    DANFE_Org.exe
)
