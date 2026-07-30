# CRM Logistic Regression

Este repositório reúne dados simulados, scripts R e resultados de modelos de regressão logística com TRI. O fluxo reproduzível oficial utiliza somente R; arquivos auxiliares legados em outras linguagens foram preservados, mas não são necessários para executar ou validar os scripts R.

## Relatório técnico

O relatório metodológico, com a formulação dos modelos, a explicação detalhada das duas estratégias de estimação e os resultados numéricos, está disponível em:

**[Acessar o relatório técnico em HTML](https://ingodube.github.io/CRM-Logistic-Regression/)**

Para gerar a mesma versão localmente, execute:

```powershell
Rscript scripts/preparar_dados_relatorio.R
Rscript scripts/renderizar_relatorio.R
Rscript scripts/validar_relatorio.R
Rscript scripts/comparar_texto_relatorio.R
```

Os blocos de simulação e estimação completa são exibidos no relatório, mas não são executados durante a renderização. As figuras e a tabela são produzidas a partir dos resultados já salvos.

## Estrutura

- `Dados Simulados/`: entradas das simulações. Trate esses arquivos como dados-fonte e não os sobrescreva.
- `Resultados/`: scripts R, resultados numéricos e artefatos de análise.
- `relatorio/`: fonte R Markdown, template Pandoc, estilo, figura extraída e dados derivados leves do relatório.
- `docs/index.html`: relatório técnico autocontido publicado pelo GitHub Pages.
- `scripts/validar_reprodutibilidade.R`: valida sintaxe, dependências e portabilidade dos caminhos sem executar as simulações.
- `scripts/renderizar_relatorio.R`: localiza o Pandoc e renderiza o relatório técnico.
- `scripts/validar_relatorio.R`: confere conteúdo, estrutura e incorporação das figuras no HTML.
- `scripts/comparar_texto_relatorio.R`: compara com o PDF, após normalização, as seções que devem ser preservadas literalmente.
- `renv.lock`: versões fixadas dos pacotes R.

## Pré-requisitos

1. Instale o R 4.6.1 ou uma versão compatível.
2. Instale o JAGS e confirme que ele pode ser carregado pelo pacote `rjags`.
3. Abra um terminal na raiz deste repositório.

## Restaurar o ambiente

Execute uma única vez:

```r
install.packages("renv")
renv::restore()
```

O pacote arquivado `mcmcplots` 0.4.3 é restaurado diretamente do arquivo oficial do CRAN registrado no `renv.lock`.

## Validar antes de executar

```powershell
Rscript scripts/validar_reprodutibilidade.R
```

A validação não altera dados nem resultados. Ela verifica a sintaxe das 15 fontes R do projeto e, nos códigos analíticos de `Resultados`, confere os seletores de cenário, a portabilidade dos caminhos, os diretórios esperados, os pacotes e a disponibilidade do JAGS.

## Executar um cenário

Execute o arquivo completo com `Rscript` ou `source()`, pois a raiz do repositório é calculada pela localização do próprio script. Exemplo:

```powershell
Rscript "Resultados/TRI/Regressão Estrutural/Regressão Logística/CRM - Normal (Wang e Zeng)/Classic/n = 100 p = 10/TRI Classic Reg. Log. n = 100 p = 10.R"
```

Não execute apenas linhas isoladas no console: nesse modo o R não informa o caminho do arquivo de origem. Os caminhos devem continuar sendo construídos com `file.path()` e relativos à raiz do repositório.

## Convenção durável de diretórios

- Nunca registrar caminhos pessoais, letras de unidade ou diretórios iniciados por `~`.
- Derivar a raiz a partir do arquivo em execução.
- Usar `file.path()` para entradas e saídas.
- Usar `dir.create(..., recursive = TRUE, showWarnings = FALSE)` antes de gravar em uma nova pasta.
- Preservar `Dados Simulados/` e evitar testes que sobrescrevam `Resultados/`.
