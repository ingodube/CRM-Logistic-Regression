#!/usr/bin/env python3
"""Build the English analytical tree from the reviewed PT-BR tree.

The localizer deliberately changes only paths, filenames, comments, messages,
and approved identifiers. Statistical expressions and numeric literals remain
unchanged. Run it from any directory; the repository root is derived from this
file.
"""

from __future__ import annotations

from pathlib import Path
import re
import shutil


ROOT = Path(__file__).resolve().parents[1]


DIRECTORY_TRANSLATIONS = {
    "TRI": "IRT",
    "Regressão Estrutural": "Structural Regression",
    "Regressão Logística": "Logistic Regression",
    "CRM - Normal (Wang e Zeng)": "CRM - Normal (Wang and Zeng)",
    "Analise_Classic_vs_Joint": "Classic_vs_Joint_Analysis",
}

CODE_FILE_TRANSLATIONS = {
    "grafico_thetas_crm.R": "plot_crm_thetas.R",
    "TRI Classic Reg. Log. n = 100 p = 10.R": "IRT Classic Logistic Regression n = 100 p = 10.R",
    "TRI Classic Reg. Log. n = 250 p = 10.R": "IRT Classic Logistic Regression n = 250 p = 10.R",
    "TRI Classic Reg. Log. n = 500 p = 10.R": "IRT Classic Logistic Regression n = 500 p = 10.R",
    "TRI Classic Reg. Log. n = 1000 p = 10.R": "IRT Classic Logistic Regression n = 1000 p = 10.R",
    "TRI Joint Reg. Log. n = 100 p = 10.R": "IRT Joint Logistic Regression n = 100 p = 10.R",
    "TRI Joint Reg. Log. n = 250 p = 10.R": "IRT Joint Logistic Regression n = 250 p = 10.R",
    "TRI Joint Reg. Log. n = 500 p = 10.R": "IRT Joint Logistic Regression n = 500 p = 10.R",
    "TRI Joint Reg. Log. n = 1000 p = 10.R": "IRT Joint Logistic Regression n = 1000 p = 10.R",
}

RESULT_FILE_TRANSLATIONS = {
    "Parametros_Qualidade.png": "Parameter_Quality.png",
    "Parametros_Resumo_TRI.png": "IRT_Parameter_Summary.png",
    "Qualidade.png": "Quality.png",
    "Resumo_TRI.png": "IRT_Summary.png",
    "comparacao_classic_joint.md": "classic_joint_comparison.md",
    "comparacao_parametros_tri.md": "irt_parameter_comparison.md",
    "grafico_thetas_estimados_crm.pdf": "crm_estimated_thetas_plot.pdf",
    "grafico_thetas_estimados_crm.png": "crm_estimated_thetas_plot.png",
    "inspect_parametros_tri.ndjson": "inspect_irt_parameters.ndjson",
    "inspect_parametros_tri_errors.ndjson": "inspect_irt_parameter_errors.ndjson",
    "inspect_resumo_tri.ndjson": "inspect_irt_summary.ndjson",
    "tabela_parametros_tri_crm.tex": "crm_item_parameter_table.tex",
    "Contador.txt": "Counter.txt",
    "a_estimados_EM.txt": "a_estimates_EM.txt",
    "alpha_estimados_EM.txt": "alpha_estimates_EM.txt",
    "b_estimados_EM.txt": "b_estimates_EM.txt",
    "beta_0_estimados_EM.txt": "beta_0_estimates_EM.txt",
    "beta_1_estimados_EM.txt": "beta_1_estimates_EM.txt",
    "theta_estimados_EM.txt": "theta_estimates_EM.txt",
    "a_estimados_mean.txt": "a_estimates_mean.txt",
    "alpha_estimados_mean.txt": "alpha_estimates_mean.txt",
    "b_estimados_mean.txt": "b_estimates_mean.txt",
    "beta_0_estimados_mean.txt": "beta_0_estimates_mean.txt",
    "beta_1_estimados_mean.txt": "beta_1_estimates_mean.txt",
    "thetas_estimados_mean.txt": "theta_estimates_mean.txt",
}

SPREADSHEET_FILE_TRANSLATIONS = {
    "checks.csv": "validation_checks.csv",
    "comparacao_classic_joint_crm.xlsx": "classic_joint_crm_comparison.xlsx",
    "comparacao_parametros_tri_crm.xlsx": "crm_item_parameter_comparison.xlsx",
    "estatisticas_thetas_estimados_crm.xlsx": "estimated_theta_statistics.xlsx",
    "qualidade.csv": "quality.csv",
    "resumo_tri.csv": "irt_summary.csv",
    "thetas.csv": "thetas.csv",
    "beta_1_estimativas.csv": "beta_1_estimates.csv",
    "metricas_theta.csv": "theta_metrics.csv",
    "tabela_parametros.csv": "item_parameter_table.csv",
    "theta_medias.csv": "theta_means.csv",
}

COMMON_PATH_REPLACEMENTS = {
    "'Dados Simulados', 'TRI', 'Modelo de Mensuração', 'CRM - Normal (Wang e Zeng)', 'Geral'":
        "'Simulated Data', 'IRT', 'Measurement Model', 'CRM - Normal (Wang and Zeng)', 'General'",
    "'Dados Simulados', 'Regressão', 'Regressão Logística'":
        "'Simulated Data', 'Regression', 'Logistic Regression'",
    '"dadosTRI_"': '"IRTData_"',
    '"DadosTRI_"': '"IRTData_"',
    '"Dados reg.log."': '"LogisticRegressionData_"',
    '"Dados reg.probit."': '"ProbitRegressionData_"',
    "'dadosTRI_'": "'IRTData_'",
    "'Dados reg.log.'": "'LogisticRegressionData_'",
    "'Dados reg.probit.'": "'ProbitRegressionData_'",
    "dadosTRI_": "IRTData_",
    "DadosTRI_": "IRTData_",
    "Dados reg.log.": "LogisticRegressionData_",
    "Dados reg.probit.": "ProbitRegressionData_",
}

PT_PATH_REPLACEMENTS = {
    "'Resultados', 'TRI', 'Regressão Estrutural', 'Regressão Logística', 'CRM - Normal (Wang e Zeng)'":
        "'Results (PT-BR)', 'TRI', 'Regressão Estrutural', 'Regressão Logística', 'CRM - Normal (Wang e Zeng)'",
}

EN_PATH_REPLACEMENTS = {
    "'Resultados', 'TRI', 'Regressão Estrutural', 'Regressão Logística', 'CRM - Normal (Wang e Zeng)'":
        "'Results (EN)', 'IRT', 'Structural Regression', 'Logistic Regression', 'CRM - Normal (Wang and Zeng)'",
    "'Results (PT-BR)', 'TRI', 'Regressão Estrutural', 'Regressão Logística', 'CRM - Normal (Wang e Zeng)'":
        "'Results (EN)', 'IRT', 'Structural Regression', 'Logistic Regression', 'CRM - Normal (Wang and Zeng)'",
    '"Results (PT-BR)"': '"Results (EN)"',
    '"Spreadsheets (PT-BR)"': '"Spreadsheets (EN)"',
    '"Regressão Estrutural"': '"Structural Regression"',
    '"Regressão Logística"': '"Logistic Regression"',
    '"CRM - Normal (Wang e Zeng)"': '"CRM - Normal (Wang and Zeng)"',
    '"Analise_Classic_vs_Joint"': '"Classic_vs_Joint_Analysis"',
}

IDENTIFIER_TRANSLATIONS = {
    "theta.est.médio": "mean_theta_estimate",
    "a.est.médio": "mean_a_estimate",
    "b.est.médio": "mean_b_estimate",
    "alpha.est.médio": "mean_alpha_estimate",
    "Vício": "Bias",
    "vício": "bias",
    "modelo": "model_specification",
    "Sementes": "Seeds",
    "data.logistico": "logistic_data",
    "fit_TRI": "irt_fit",
    "fit_theta": "theta_fit",
    "amostras_jags": "jags_samples",
    "amostras": "samples",
    "a_estimados": "a_estimates",
    "b_estimados": "b_estimates",
    "alpha_estimados": "alpha_estimates",
    "beta_0_estimados": "beta_0_estimates",
    "beta_1_estimados": "beta_1_estimates",
    "_geral": "_overall",
    "thetas_reais": "true_thetas",
    "param_itens_reais": "true_item_parameters",
    "param.itens": "item.parameters",
    "Dados.Tri.dir": "IRT.Data.dir",
    "Dados.dir.TRI": "IRT.Data.dir",
    "Dados.dir.Reg": "Regression.Data.dir",
    "resultados": "responses",
    "theta_estimados": "theta_estimates",
    "theta_estimados_EM": "theta_estimates_EM",
    "theta_estimados_mean": "theta_estimates_mean",
    "theta_estimado_medio": "mean_theta_estimate",
    "individuo": "individual",
    "metodo_label": "method_label",
    "metodo": "method",
    "valores": "values",
    "media_thetas_medios": "mean_of_mean_thetas",
    "desvio_padrao_thetas_medios": "sd_of_mean_thetas",
    "desvio_padrao": "standard_deviation",
    "amplitude": "range_value",
    "minimo": "minimum",
    "maximo": "maximum",
    "media": "mean_value",
    "vicio": "bias",
    "Vício": "Bias",
    "Contador": "Counter",
    "EQM": "MSE",
    "médio": "mean",
    "Erro": "Error",
}

PHRASE_TRANSLATIONS = {
    'expression(theta~"verdadeiro")': 'expression("True"~theta)',
    'expression("media de "~theta~" estimado")': 'expression("Mean estimated "~theta)',
    "Salvamento incremental": "Incremental save",
    "Salvamento parcial": "Partial save",
    "Os scripts Classic inspecionados gravam alpha_estimados_EM em theta_estimados_EM.txt; por isso cenarios com theta fora de n x 1000 ficam como NA.":
        "The inspected Classic programs write alpha_estimates_EM to theta_estimates_EM.txt; therefore, theta scenarios outside n x 1000 are reported as NA.",
    "Dimensao ou valores invalidos; metrica marcada como NA.":
        "Invalid dimensions or values; metric reported as NA.",
    "Medias agregadas de RMSE e vicio assinado para theta e parametros da TRI. NA indica arquivo de theta com dimensao invalida.":
        "Aggregated RMSE and signed bias for theta and IRT parameters. NA indicates a theta file with invalid dimensions.",
    "Medias agregadas de RMSE e vicio assinado para os parametros a, b e alpha.":
        "Aggregated RMSE and signed bias for parameters a, b, and alpha.",
    "Comparison Classic vs Joint - CRM": "Classic versus Joint Comparison - CRM",
    "| n | p | Method | Mean | DP | Min | Max | Range |": "| n | p | Method | Mean | SD | Min | Max | Range |",
    "Comparison entre os metodos Classic e Joint para os parameters da IRT no CRM": "Comparison of Classic and Joint estimation for CRM item parameters",
    "tab:parameters-tri-crm": "tab:crm-item-parameters",
    "Dimensao ou values invalidos; metrica marcada como NA.": "Invalid dimensions or values; metric reported as NA.",
    "Mean values agregadas de RMSE e bias assinado para theta e parameters da IRT. NA indica arquivo de theta com dimensao invalida.": "Aggregated RMSE and signed bias for theta and IRT parameters. NA indicates a theta file with invalid dimensions.",
    "Estatisticas calculadas sobre todos os values validos da matriz n x 1000 de cada method e cenario.": "Statistics calculated from all valid values in each n x 1000 matrix by method and scenario.",
    "Quality dos Data - Parameters da IRT": "Data Quality - IRT Parameters",
    "Quality dos Data": "Data Quality",
    "Comparison Classic vs Joint - Parameters da IRT": "Classic versus Joint Comparison - IRT Parameters",
    "Mean values agregadas de RMSE e bias assinado para os parameters a, b e alpha.": "Aggregated RMSE and signed bias for parameters a, b, and alpha.",
    "Analise_Classic_vs_Joint": "Classic_vs_Joint_Analysis",
    "Comparacao": "Comparison",
    "Resumo_TRI": "IRT_Summary",
    "Resumo TRI": "IRT Summary",
    "Parametros": "Parameters",
    "parametros": "parameters",
    "TRI": "IRT",
    "Qualidade": "Quality",
    "Dados": "Data",
    "Medias": "Mean values",
    "medias": "mean values",
    "Estatisticas dos Thetas Estimados": "Estimated Theta Statistics",
    "Metodo": "Method",
    "Vicio": "Bias",
    "Media": "Mean",
    "Amplitude": "Range",
    "Cenario": "Scenario",
    "Parametro": "Parameter",
    "Entidade": "Entity",
    "Arquivo": "File",
    "Linhas esperadas": "Expected rows",
    "Colunas esperadas": "Expected columns",
    "Linhas": "Rows",
    "Colunas": "Columns",
    "Nota": "Note",
    "Cheque manual independente": "Independent Manual Check",
    "Dimensoes lidas, cenarios sem arquivos e avisos usados para decidir quais metricas entram como NA.": "Read dimensions, missing files, and warnings used to determine which metrics are reported as NA.",
    "Dimensoes lidas para a, b e alpha. A tabela exclui os arquivos de theta.": "Read dimensions for a, b, and alpha. The table excludes theta files.",
    "Arquivo ausente.": "Missing file.",
    "Os scripts Classic inspecionados gravam alpha_estimates_EM em theta_estimates_EM.txt; por isso cenarios com theta fora de n x 1000 ficam como NA.": "The inspected Classic programs write alpha_estimates_EM to theta_estimates_EM.txt; therefore, theta scenarios outside n x 1000 are reported as NA.",
    "Cheque independente da orientacao: linha = item, coluna = replicacao.": "Independent orientation check: row = item, column = replication.",
    "qualidade.csv": "quality.csv",
    "Run the 1,000 replications and MCMC estimation.": "Run the 1000 replications and MCMC estimation.",
    "Replicação": "Replication",
    "replicação": "replication",
    "concluída": "completed",
    "Calibrando os parâmetros da TRI": "Calibrate IRT parameters",
    "Lendo os salvamentos intermediários": "Read intermediate saved results",
    "Lendo os dados": "Read data",
    "Calibração da TRI via algoritmo EM": "IRT calibration using the EM algorithm",
    "Extração dos parâmetros da TRI": "Extract IRT parameters",
    "Implementando a regressão logística": "Fit logistic regression",
    "Variável resposta": "Response variable",
    "Covariável (theta estimado)": "Covariate (estimated theta)",
    "Ajuste do modelo logístico": "Fit the logistic model",
    "Regressão logística": "Logistic regression",
    "Para encontrar o viés \"geral\" de todos os thetas.": "Compute the overall bias across theta values.",
    "Para encontrar o vício \"geral\" de todos os thetas.": "Compute the overall bias across theta values.",
    "Para cada parâmetro individualizado": "For each item-specific parameter",
    "parâmetrosTRI_": "IRT_parameters_",
    "Ajuste do model_specification logístico": "Fit the logistic model",
    "Estimando os thetas à posteriori": "Estimate posterior theta values",
    "Para encontrar o bias \"geral\" de todos os thetas.": "Compute the overall bias across theta values.",
    "Instale-os ou defina install_if_missing <- TRUE.": "Install them or set install_if_missing <- TRUE.",
    "Invalid dimensions em ": "Invalid dimensions in ",
    "Carregando pacotes necessários": "Load required packages",
    "Determinando os diretórios": "Determine directories",
    "Mudar o diretório em caso de mudar de máquina": "Resolve the repository root from the program path",
    "Definindo o número de núcleos": "Define the number of cores",
    "Deixe um núcleo livre para outras tarefas": "Leave one core available for other tasks",
    "Criando um cluster com o número de núcleos": "Create a cluster with the selected number of cores",
    "Número de replicações totais": "Total number of replications",
    "Número de indivíduos": "Number of individuals",
    "Número de itens": "Number of items",
    "Gerando as habilidades reais": "Generate true latent traits",
    "Gerando parâmetros dos itens reais": "Generate true item parameters",
    "Fixando k": "Fix k",
    "Pegando parâmetros": "Select parameters",
    "discriminação": "discrimination",
    "dificuldade": "difficulty",
    "escala": "scale",
    "Inicializando matrizes": "Initialize matrices",
    "Realizando as 1000 replicatas e implementar o MCMC.": "Run the 1000 replications and MCMC estimation.",
    "Variando as seeds": "Vary random seeds",
    "Matrizes auxiliares": "Auxiliary matrices",
    "Média e desvio padrão": "Mean and standard deviation",
    "Gerando Z": "Generate Z",
    "Transformação": "Transformation",
    "Escore observado no teste": "Observed test score",
    "Salvando arquivo": "Save file",
    "Gerando os dados da regressão logística": "Generate logistic-regression data",
    "Escrevendo o Modelo": "Write the model",
    "Removendo a matriz Z para aplicá-la no algoritmo de estimação por replicata": "Remove Z before replication-level estimation",
    "Determinando o número de cadeias de Markov": "Set the number of Markov chains",
    "Apenas para as primeiras replicações": "Restrict to the first replications when requested",
    "Lendo os dados salvos": "Read saved data",
    "Lendo o contador": "Read the replication counter",
    "Carregando o modelo no JAGS": "Load the model in JAGS",
    "Período de burn-in": "Burn-in period",
    "Amostragem posterior": "Posterior sampling",
    "Converte para lista de simulações": "Convert to a simulation list",
    "Parâmetros da TRI": "IRT parameters",
    "Parâmetro": "Parameter",
    "Salvando o contador": "Save the replication counter",
    "Exibe progresso": "Display progress",
    "Diagnóstico das cadeias da última replicação processada": "Chain diagnostics for the last processed replication",
    "Avaliando theta": "Evaluate theta",
    "Avaliando os parâmetros da TRI": "Evaluate IRT parameters",
    "Duas etapas": "Two-stage",
    "Conjunto": "Joint",
    "Pacotes ausentes": "Missing packages",
    "Arquivo nao encontrado": "File not found",
    "Dimensao invalida": "Invalid dimensions",
    "Esperado": "Expected",
    "observado": "observed",
    "Valores nao finitos encontrados em": "Non-finite values found in",
    "Grafico dos thetas estimados vs. thetas verdadeiros": "Plot of estimated versus true theta values",
    "Grafico PNG salvo em": "PNG plot saved to",
    "Grafico PDF salvo em": "PDF plot saved to",
    "Planilha Excel salva em": "Excel workbook saved to",
    "Autor: script gerado para comparacao Classic vs Joint": "Generated for the Classic versus Joint comparison",
    "Saidas": "Outputs",
}


def rename_tree(root: Path, file_map: dict[str, str]) -> None:
    for path in sorted(root.rglob("*"), key=lambda item: len(item.parts), reverse=True):
        if path.is_file() and path.name in file_map:
            path.rename(path.with_name(file_map[path.name]))
        elif path.is_dir() and path.name in DIRECTORY_TRANSLATIONS:
            path.rename(path.with_name(DIRECTORY_TRANSLATIONS[path.name]))


def replace_all(text: str, replacements: dict[str, str]) -> str:
    for source, target in replacements.items():
        text = text.replace(source, target)
    return text


def strip_trailing_whitespace(text: str) -> str:
    return re.sub(r"[ \t]+(?=\n|$)", "", text)


def replace_phrases(text: str) -> str:
    for source, target in sorted(PHRASE_TRANSLATIONS.items(), key=lambda item: len(item[0]), reverse=True):
        text = text.replace(source, target)
    return text


def localize_r_text(text: str) -> str:
    text = replace_all(text, COMMON_PATH_REPLACEMENTS)
    text = replace_all(text, EN_PATH_REPLACEMENTS)
    text = replace_phrases(text)
    for source, target in sorted(IDENTIFIER_TRANSLATIONS.items(), key=lambda item: len(item[0]), reverse=True):
        text = text.replace(source, target)
    text = text.replace("grafico_thetas_estimados_crm", "crm_estimated_thetas_plot")
    text = text.replace("estatisticas_thetas_estimados_crm.xlsx", "estimated_theta_statistics.xlsx")
    text = text.replace("comparacao_classic_joint_crm.xlsx", "classic_joint_crm_comparison.xlsx")
    text = text.replace("comparacao_parametros_tri_crm.xlsx", "crm_item_parameter_comparison.xlsx")
    text = text.replace("theta_estimados_EM.txt", "theta_estimates_EM.txt")
    text = text.replace("thetas_estimados_mean.txt", "theta_estimates_mean.txt")
    text = text.replace("a_estimados_EM.txt", "a_estimates_EM.txt")
    text = text.replace("alpha_estimados_EM.txt", "alpha_estimates_EM.txt")
    text = text.replace("b_estimados_EM.txt", "b_estimates_EM.txt")
    text = text.replace("beta_0_estimados_EM.txt", "beta_0_estimates_EM.txt")
    text = text.replace("beta_1_estimados_EM.txt", "beta_1_estimates_EM.txt")
    text = text.replace("a_estimados_mean.txt", "a_estimates_mean.txt")
    text = text.replace("alpha_estimados_mean.txt", "alpha_estimates_mean.txt")
    text = text.replace("b_estimados_mean.txt", "b_estimates_mean.txt")
    text = text.replace("beta_0_estimados_mean.txt", "beta_0_estimates_mean.txt")
    text = text.replace("beta_1_estimados_mean.txt", "beta_1_estimates_mean.txt")
    text = text.replace("Contador.txt", "Counter.txt")
    return text


def update_pt_code() -> None:
    for path in (ROOT / "Codes (PT-BR)").rglob("*.R"):
        text = path.read_text(encoding="utf-8")
        text = replace_all(text, COMMON_PATH_REPLACEMENTS)
        text = replace_all(text, PT_PATH_REPLACEMENTS)
        path.write_text(strip_trailing_whitespace(text), encoding="utf-8", newline="\n")


def rebuild_en_code() -> None:
    source = ROOT / "Codes (PT-BR)"
    target = ROOT / "Codes (EN)"
    if not source.is_dir():
        raise FileNotFoundError(f"Reviewed PT-BR code tree is missing: {source}")
    if target.parent.resolve() != ROOT.resolve() or target.name != "Codes (EN)":
        raise RuntimeError(f"Refusing to replace unexpected target: {target}")
    if target.exists():
        shutil.rmtree(target)
    shutil.copytree(source, target)
    rename_tree(target, CODE_FILE_TRANSLATIONS)
    for path in (ROOT / "Codes (EN)").rglob("*"):
        if path.is_file() and path.suffix.lower() in {".r", ".py", ".mjs"}:
            text = path.read_text(encoding="utf-8")
            path.write_text(strip_trailing_whitespace(localize_r_text(text)), encoding="utf-8", newline="\n")


def localize_text_results() -> None:
    root = ROOT / "Results (EN)"
    for path in root.rglob("*"):
        if path.is_file() and path.suffix.lower() in {".md", ".tex", ".json", ".ndjson"}:
            text = path.read_text(encoding="utf-8")
            text = replace_phrases(text)
            text = text.replace("Duas etapas", "Two-stage").replace("Conjunto", "Joint")
            text = text.replace("Qualidade", "Quality").replace("Resumo", "Summary")
            path.write_text(text, encoding="utf-8", newline="\n")


def main() -> None:
    rename_tree(ROOT / "Results (EN)", RESULT_FILE_TRANSLATIONS)
    rename_tree(ROOT / "Spreadsheets (EN)", SPREADSHEET_FILE_TRANSLATIONS)
    update_pt_code()
    rebuild_en_code()
    localize_text_results()
    print("English analytical tree localized from PT-BR sources.")


if __name__ == "__main__":
    main()
