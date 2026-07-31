# CRM Logistic Regression

<p align="justify">Este repositório reúne dados simulados, scripts R e resultados de modelos de regressão logística com TRI. O fluxo reproduzível oficial utiliza somente R; arquivos auxiliares legados em outras linguagens foram preservados, mas não são necessários para executar ou validar os scripts R.</p>

## Relatório técnico

<p align="justify">O relatório metodológico apresenta:</p>

- a especificação do Modelo de Respostas Contínuas e da regressão logística para o desfecho distal;
- a interpretação dos parâmetros dos itens por meio das curvas características acumuladas;
- os métodos de estimação em duas etapas e de estimação bayesiana conjunta;
- o estudo com dados simulados, a verificação do ajuste e a comparação dos resultados numéricos.

**[Acessar o relatório técnico em HTML](https://ingodube.github.io/CRM-Logistic-Regression/)**

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

<p align="justify">Execute uma única vez:</p>

```r
install.packages("renv")
renv::restore()
```

<p align="justify">O pacote arquivado `mcmcplots` 0.4.3 é restaurado diretamente do arquivo oficial do CRAN registrado no `renv.lock`.</p>

## Validar antes de executar

```powershell
Rscript scripts/validar_reprodutibilidade.R
```

<p align="justify">A validação não altera dados nem resultados. Ela verifica a sintaxe das 15 fontes R do projeto e, nos códigos analíticos de `Resultados`, confere os seletores de cenário, a portabilidade dos caminhos, os diretórios esperados, os pacotes e a disponibilidade do JAGS.</p>

## Executar um cenário

<p align="justify">Execute o arquivo completo com `Rscript` ou `source()`, pois a raiz do repositório é calculada pela localização do próprio script. Exemplo:</p>

```powershell
Rscript "Resultados/TRI/Regressão Estrutural/Regressão Logística/CRM - Normal (Wang e Zeng)/Classic/n = 100 p = 10/TRI Classic Reg. Log. n = 100 p = 10.R"
```

<p align="justify">Não execute apenas linhas isoladas no console: nesse modo o R não informa o caminho do arquivo de origem. Os caminhos devem continuar sendo construídos com `file.path()` e relativos à raiz do repositório.</p>
