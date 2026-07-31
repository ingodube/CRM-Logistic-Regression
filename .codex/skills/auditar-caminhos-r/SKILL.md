---
name: auditar-caminhos-r
description: Auditar e corrigir caminhos de arquivos e diretórios em projetos R, preservando dados-fonte e a lógica estatística. Usar quando scripts R contiverem setwd com caminhos pessoais, separadores manuais, saídas dependentes da máquina, diretórios ausentes ou quando for necessário verificar reprodutibilidade de caminhos neste repositório.
---

# Auditar Caminhos R

## Fluxo

1. Ler `AGENTS.md` e `README.md` antes de alterar o projeto.
2. Inventariar arquivos R com `rg --files -g '*.R'`.
3. Procurar caminhos absolutos, `setwd()`, `getwd()`, `file.path()` e `dir.create()`.
4. Preservar `Dados Simulados/` e não executar simulações durante a auditoria.
5. Derivar a raiz pelo caminho do script e construir caminhos com `file.path()`.
6. Alterar somente linhas de diretório quando essa restrição fizer parte do pedido.
7. Executar `Rscript scripts/validar_reprodutibilidade.R` antes de concluir.

## Convenções deste repositório

- Nunca registrar caminhos pessoais, letras de unidade ou diretórios iniciados por `~`.
- Construir caminhos de entrada e saída com `file.path()`.
- Criar cada novo diretório com `dir.create(..., recursive = TRUE, showWarnings = FALSE)` antes de gravar arquivos.
- Considerar `Dados Simulados/` como entrada imutável.
- Considerar `Resultados/` como raiz dos scripts e artefatos estatísticos.
- Evitar testes que sobrescrevam arquivos existentes em `Resultados/`.
- Executar arquivos completos com `Rscript` ou `source()`; não depender de linhas executadas isoladamente.
- Manter dependências em `renv.lock` e testar a presença do JAGS separadamente.
- Preservar acentos e espaços nos nomes; não renomear a árvore sem autorização explícita.
- Não introduzir scripts auxiliares em outras linguagens no fluxo R oficial.

## Padrão de raiz

Preferir `normalizePath()` combinado com `dirname()` do arquivo em execução. Aceitar o ramo `--file=` para `Rscript` e `sys.frame(1)$ofile` para `source()`. Calcular a quantidade de níveis a partir da árvore real, confirmar que a raiz contém `Resultados/` e `Dados Simulados/` e então chamar `setwd(main.dir)` apenas quando o script existente exigir.

## Validação

Executar o validador em modo somente leitura. Se ele falhar:

- Corrigir primeiro sintaxe ou caminhos absolutos.
- Orientar `renv::restore()` quando faltarem pacotes.
- Orientar a instalação do JAGS quando `rjags` não localizar a biblioteca externa.
- Informar explicitamente quais validações passaram e que as simulações completas não foram executadas.
