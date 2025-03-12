# DANFE Organizer

## Descrição

O DANFE Organizer é uma ferramenta utilitária desenvolvida em Free Pascal que
organiza arquivos XML de notas fiscais eletrônicas (DANFEs), classificando-os
automaticamente em pastas por ano e mês.

## Funcionalidades

### Menu Principal

O programa oferece três opções:

1. Reorganizar arquivos
2. Compactar pastas
3. Reorganizar e compactar

### 1. Reorganização de Arquivos

- Organiza automaticamente os arquivos XML da pasta atual
- Cria estrutura de pastas ano/mês baseada na data do arquivo
- Exemplo: Um arquivo de Janeiro/2022 vai para `.\2022\01\`
- Exibe barra de progresso em tempo real
- Processa apenas arquivos da pasta atual (não inclui subpastas)

### 2. Compactação

- Cria um arquivo DANFE.zip contendo todas as pastas organizadas
- Mantém a estrutura de diretórios dentro do ZIP
- Ideal para backup ou envio dos arquivos organizados

### 3. Reorganizar e Compactar

- Executa ambas as operações em sequência
- Primeiro organiza os arquivos
- Em seguida, cria o arquivo ZIP com a estrutura organizada

## Interface

- Menu interativo com teclado
- Barra de progresso colorida durante a organização
- Feedback visual do processo em tempo real
- Mensagens claras de início e conclusão de cada operação

## Requisitos do Sistema

- Sistema operacional Windows
- Espaço em disco suficiente para organização
- Permissões de leitura/gravação na pasta de execução

## Como Usar

1. Copie o executável para a pasta que contém os arquivos XML
2. Execute o programa `DANFE_Org.exe`
3. Escolha a opção desejada no menu
4. Aguarde a conclusão do processo

## Tratamento de Erros

- Verifica existência de arquivos XML antes de iniciar
- Valida operações de movimentação de arquivos
- Fornece mensagens de erro claras quando necessário

## Feedback do Processo

O programa fornece feedback durante a execução:

- Mostra quantidade de arquivos encontrados
- Exibe barra de progresso em verde durante a organização
- Indica progresso da compactação
- Mostra mensagem de conclusão ao finalizar
