---
name: produzir-relatorio-tecnico
description: Produzir, revisar, renderizar, validar e publicar o relatório metodológico em R Markdown deste repositório. Usar ao alterar o conteúdo, o CSS, o template, as figuras, as tabelas, as referências cruzadas, o HTML publicado ou o fluxo de GitHub Pages do relatório técnico.
---

# Produzir Relatório Técnico

## Fluxo obrigatório

1. Ler `AGENTS.md`, `README.md`, `relatorio/relatorio_metodologico.Rmd`, `relatorio/estilo.css`, `relatorio/template.html` e os validadores antes de alterar o relatório.
2. Editar sempre a fonte R Markdown; não editar apenas `docs/index.html`.
3. Preservar `Dados Simulados/`, as matrizes das replicações e os demais resultados analíticos salvos.
4. Manter os blocos de simulação e estimação completa visíveis, mas desativados por padrão com `eval=FALSE`.
5. Executar somente blocos leves de leitura, tabelas e figuras durante a renderização.
6. Produzir figuras e tabelas a partir dos resultados já salvos; não reexecutar as 1.000 replicações nem sobrescrever resultados.
7. Executar, na raiz do repositório e nesta ordem:

```powershell
Rscript scripts/preparar_dados_relatorio.R
Rscript scripts/renderizar_relatorio.R
Rscript scripts/validar_relatorio.R
Rscript scripts/comparar_texto_relatorio.R
```

8. Executar `Rscript scripts/validar_reprodutibilidade.R`, `Rscript -e "renv::status()"` e `git diff --check` antes de publicar.
9. Confirmar que `docs/index.html` é autocontido, que o README mantém o link público e que as seções protegidas continuam idênticas ao PDF após normalização.
10. Fazer commit e push somente após todas as verificações; acompanhar os workflows e exigir HTTP 200 em `https://ingodube.github.io/CRM-Logistic-Regression/`.

## Caminhos e diretórios

Ler e aplicar `../auditar-caminhos-r/SKILL.md` sempre que a produção do relatório envolver caminhos, criação de diretórios ou novas saídas. Manter todos os caminhos relativos à raiz do repositório e construídos em R.

## Regras editoriais

- Preservar o conteúdo científico e as referências das seções protegidas.
- Manter títulos de figuras acima dos gráficos e, quando houver código visível de construção, usar a ordem código, título, gráfico, fonte e interpretação.
- Manter as equações centralizadas e sem barras de rolagem.
- Manter as referências bibliográficas justificadas com a última linha alinhada à esquerda.
- Manter as simulações pesadas desativadas durante a renderização.
