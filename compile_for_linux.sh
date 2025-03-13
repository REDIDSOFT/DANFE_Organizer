#!/bin/bash

mkdir -p ./linux
mkdir -p ./lib/x86_64-linux

if ! command -v fpc &> /dev/null; then
    echo "Erro: Free Pascal Compiler (fpc) nao encontrado."
    echo "Por favor, instale o Free Pascal Compiler."
    exit 1
fi

fpc -MObjFPC -Scgi -O1 -g -gl -l -vewnhibq \
    -Fi./lib/x86_64-linux \
    -Fu. \
    -FE./linux \
    -FU./lib/x86_64-linux \
    DANFE_Org.lpr

if [ $? -ne 0 ]; then
    echo "Erro na compilacao!"
    read -p "Pressione ENTER para continuar..."
else
    echo "Compilacao concluida com sucesso!"
    echo "Executavel criado em ./linux/DANFE_Org"
    read -p "Pressione ENTER para continuar..."
fi
