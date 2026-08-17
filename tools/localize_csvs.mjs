#!/usr/bin/env node
/** Localize the eight analytical CSV artifacts without changing numeric tokens. */

import fs from "node:fs/promises";
import path from "node:path";

const repo = path.resolve(process.argv[2] ?? ".");
const sourceDir = path.join(repo, "Spreadsheets (PT-BR)");
const targetDir = path.join(repo, "Spreadsheets (EN)");
const files = new Map([
  ["beta_1_estimativas.csv", "beta_1_estimates.csv"],
  ["checks.csv", "validation_checks.csv"],
  ["metricas_theta.csv", "theta_metrics.csv"],
  ["qualidade.csv", "quality.csv"],
  ["resumo_tri.csv", "irt_summary.csv"],
  ["tabela_parametros.csv", "item_parameter_table.csv"],
  ["theta_medias.csv", "theta_means.csv"],
  ["thetas.csv", "thetas.csv"],
]);
const replacements = [
  ["theta_estimados_EM.txt", "theta_estimates_EM.txt"],
  ["alpha_estimados_EM.txt", "alpha_estimates_EM.txt"],
  ["beta_0_estimados_EM.txt", "beta_0_estimates_EM.txt"],
  ["beta_1_estimados_EM.txt", "beta_1_estimates_EM.txt"],
  ["a_estimados_EM.txt", "a_estimates_EM.txt"],
  ["b_estimados_EM.txt", "b_estimates_EM.txt"],
  ["thetas_estimados_mean.txt", "theta_estimates_mean.txt"],
  ["theta_estimados_mean.txt", "theta_estimates_mean.txt"],
  ["alpha_estimados_mean.txt", "alpha_estimates_mean.txt"],
  ["beta_0_estimados_mean.txt", "beta_0_estimates_mean.txt"],
  ["beta_1_estimados_mean.txt", "beta_1_estimates_mean.txt"],
  ["a_estimados_mean.txt", "a_estimates_mean.txt"],
  ["b_estimados_mean.txt", "b_estimates_mean.txt"],
  ["Duas etapas", "Two-stage"], ["Conjunto", "Joint"],
  ["metodo", "method"], ["replicacao", "replication"],
  ["vicio", "bias"], ["media", "mean"], ["desvio_padrao", "standard_deviation"],
  ["minimo", "minimum"], ["maximo", "maximum"], ["amplitude", "range"],
  ["individuo", "individual"], ["theta_verdadeiro", "true_theta"],
  ["theta_estimado_medio", "mean_theta_estimate"],
  ["Dimensao ou valores invalidos; metrica marcada como NA.", "Invalid dimensions or values; metric reported as NA."],
  ["Arquivo ausente.", "Missing file."],
  ["Os scripts Classic inspecionados gravam alpha_estimates_EM em theta_estimates_EM.txt; por isso cenarios com theta fora de n x 1000 ficam como NA.", "The inspected Classic scripts write alpha_estimates_EM to theta_estimates_EM.txt; therefore, scenarios with theta dimensions other than n x 1,000 are reported as NA."],
  ["Cheque independente da orientacao: linha = item, coluna = replicacao.", "Independent orientation check: row = item, column = replication."],
  ["TRI Classic Reg. Log. *.R", "IRT Classic Log. Reg. *.R"],
];

function numericTokens(text) {
  return text.match(/(?<![A-Za-z_])[-+]?(?:\d+\.\d*|\.\d+|\d+)(?:[eE][-+]?\d+)?/g) ?? [];
}

await fs.mkdir(targetDir, { recursive: true });
for (const [sourceName, targetName] of files) {
  const source = await fs.readFile(path.join(sourceDir, sourceName), "utf8");
  let target = source;
  for (const [from, to] of replacements) target = target.replaceAll(from, to);
  const before = numericTokens(source);
  const after = numericTokens(target);
  if (JSON.stringify(before) !== JSON.stringify(after)) {
    throw new Error(`Numeric parity failed for ${sourceName}`);
  }
  const sourceRows = source.trimEnd().split(/\r?\n/).length;
  const targetRows = target.trimEnd().split(/\r?\n/).length;
  if (sourceRows !== targetRows) throw new Error(`Row parity failed for ${sourceName}`);
  await fs.writeFile(path.join(targetDir, targetName), target.replace(/\r\n/g, "\n"), "utf8");
}
console.log(JSON.stringify({ csv_files: files.size, numeric_parity: "PASS", row_parity: "PASS" }));
