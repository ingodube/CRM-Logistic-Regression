#!/usr/bin/env node
/** Build the three English workbooks from saved, validated analytical data. */

import fs from "node:fs/promises";
import path from "node:path";
import { SpreadsheetFile, Workbook } from "@oai/artifact-tool";

const args = Object.fromEntries(
  process.argv.slice(2).reduce((pairs, value, index, values) => {
    if (value.startsWith("--")) pairs.push([value.slice(2), values[index + 1]]);
    return pairs;
  }, []),
);
if (!args.repo || !args["preview-dir"]) throw new Error("Use --repo and --preview-dir.");

const repo = path.resolve(args.repo);
const previewDir = path.resolve(args["preview-dir"]);
const sheetsDir = path.join(repo, "Spreadsheets (EN)");
const resultsDir = path.join(repo, "Results (EN)", "IRT", "Structural Regression", "Logistic Regression", "CRM - Normal (Wang and Zeng)", "Classic_vs_Joint_Analysis");
await fs.mkdir(previewDir, { recursive: true });
const metrics = JSON.parse(await fs.readFile(path.join(resultsDir, "metrics.json"), "utf8"));
metrics.quality = csvObjects(parseCsv(await fs.readFile(path.join(repo, "Spreadsheets (PT-BR)", "qualidade.csv"), "utf8")));
metrics.manual_checks = csvObjects(parseCsv(await fs.readFile(path.join(repo, "Spreadsheets (PT-BR)", "checks.csv"), "utf8")));

const palette = {
  title: "#243746", group: "#D9E8F5", header: "#EEF3F7", warning: "#FDE9D9",
  invalid: "#FCE4E4", missing: "#F3F4F6", border: "#B8C4CF", text: "#111827",
};
const fileTranslations = new Map([
  ["a_estimados_EM.txt", "a_estimates_EM.txt"], ["alpha_estimados_EM.txt", "alpha_estimates_EM.txt"],
  ["b_estimados_EM.txt", "b_estimates_EM.txt"], ["beta_0_estimados_EM.txt", "beta_0_estimates_EM.txt"],
  ["beta_1_estimados_EM.txt", "beta_1_estimates_EM.txt"], ["theta_estimados_EM.txt", "theta_estimates_EM.txt"],
  ["a_estimados_mean.txt", "a_estimates_mean.txt"], ["alpha_estimados_mean.txt", "alpha_estimates_mean.txt"],
  ["b_estimados_mean.txt", "b_estimates_mean.txt"], ["beta_0_estimados_mean.txt", "beta_0_estimates_mean.txt"],
  ["beta_1_estimados_mean.txt", "beta_1_estimates_mean.txt"], ["thetas_estimados_mean.txt", "theta_estimates_mean.txt"],
]);

function translateText(value) {
  if (typeof value !== "string") return value;
  let text = value
    .replaceAll("Os scripts Classic inspecionados gravam alpha_estimados_EM em theta_estimados_EM.txt; por isso cenarios com theta fora de n x 1000 ficam como NA.", "The inspected Classic scripts write alpha_estimates_EM to theta_estimates_EM.txt; therefore, scenarios with theta dimensions other than n x 1,000 are reported as NA.");
  for (const [source, target] of fileTranslations) text = text.replaceAll(source, target);
  return text.replaceAll("Duas etapas", "Two-stage").replaceAll("Conjunto", "Joint")
    .replaceAll("TRI Classic Reg. Log. *.R", "IRT Classic Logistic Regression *.R")
    .replaceAll("Dimensao ou valores invalidos; metrica marcada como NA.", "Invalid dimensions or values; metric reported as NA.")
    .replaceAll("Arquivo ausente.", "Missing file.")
    .replaceAll("Cheque independente da orientacao: linha = item, coluna = replicacao.", "Independent orientation check: row = item, column = replication.");
}
function valueOrNA(value) { return value === null || value === undefined || Number.isNaN(value) ? "NA" : value; }
function writeTitle(sheet, title, subtitle, lastCol) {
  const titleRange = sheet.getRangeByIndexes(0, 0, 1, lastCol); titleRange.merge(); titleRange.values = [[title]];
  titleRange.format = { fill: palette.title, font: { bold: true, color: "#FFFFFF", size: 14 }, horizontalAlignment: "center" };
  titleRange.format.font.color = "#FFFFFF";
  const subtitleRange = sheet.getRangeByIndexes(1, 0, 1, lastCol); subtitleRange.merge(); subtitleRange.values = [[subtitle]];
  subtitleRange.format = { fill: "#FFFFFF", font: { italic: true, color: "#374151", size: 10 }, horizontalAlignment: "center", wrapText: true };
}
function styleUsed(sheet, rows, cols, headerRows) {
  const used = sheet.getRangeByIndexes(0, 0, rows, cols);
  used.format.font = { name: "Aptos", size: 10 };
  used.format.borders = { preset: "outside", style: "thin", color: palette.border };
  if (rows > headerRows) sheet.getRangeByIndexes(headerRows, 0, rows - headerRows, cols).format.borders = {
    insideHorizontal: { style: "thin", color: "#E5E7EB" }, insideVertical: { style: "thin", color: "#EEF2F7" },
  };
  sheet.showGridLines = false;
}
function setWidths(sheet, widths) { widths.forEach((width, index) => { sheet.getRangeByIndexes(0, index, 1, 1).format.columnWidth = width; }); }

async function renderAndExport(workbook, outputName, previewNames = {}) {
  const errors = await workbook.inspect({ kind: "match", searchTerm: "#REF!|#DIV/0!|#VALUE!|#NAME\\?|#N/A", options: { useRegex: true, maxResults: 300 }, summary: `formula error scan for ${outputName}` });
  if (/\"error\"/i.test(errors.ndjson)) throw new Error(errors.ndjson);
  for (const sheet of workbook.worksheets.items) {
    const renderOptions = sheet.name === "Plot_Data"
      ? { sheetName: sheet.name, range: "A1:E30", scale: 1, format: "png" }
      : { sheetName: sheet.name, autoCrop: "all", scale: 1, format: "png" };
    const preview = await workbook.render(renderOptions);
    const bytes = new Uint8Array(await preview.arrayBuffer());
    const previewName = previewNames[sheet.name] ?? `${path.parse(outputName).name}--${sheet.name}.png`;
    await fs.writeFile(path.join(previewDir, previewName), bytes);
    if (previewNames[sheet.name]) await fs.writeFile(path.join(resultsDir, previewName), bytes);
  }
  const output = await SpreadsheetFile.exportXlsx(workbook); await output.save(path.join(sheetsDir, outputName));
}

function buildComparisonWorkbook() {
  const workbook = Workbook.create();
  const summary = workbook.worksheets.add("IRT_Summary"); const thetas = workbook.worksheets.add("Thetas"); const quality = workbook.worksheets.add("Quality");
  writeTitle(summary, "Classic versus Joint Comparison — CRM", "Aggregated RMSE and signed bias for theta and IRT parameters. NA indicates a theta file with invalid dimensions.", 11);
  summary.getRange("A4:C5").values = [["Scenario", "", ""], ["n", "p", "Method"]]; summary.getRange("D4:G4").merge(); summary.getRange("H4:K4").merge();
  summary.getRange("D4:K4").values = [["RMSE", null, null, null, "Bias", null, null, null]]; summary.getRange("D5:K5").values = [["theta", "a", "b", "alpha", "theta", "a", "b", "alpha"]];
  const summaryRows = metrics.summary.map((row) => [row.n, row.p, row.method, valueOrNA(row.rmse_theta), valueOrNA(row.rmse_a), valueOrNA(row.rmse_b), valueOrNA(row.rmse_alpha), valueOrNA(row.bias_theta), valueOrNA(row.bias_a), valueOrNA(row.bias_b), valueOrNA(row.bias_alpha)]);
  summary.getRangeByIndexes(5, 0, summaryRows.length, 11).values = summaryRows; summary.getRange("A4:K4").format = { fill: palette.group, font: { bold: true, color: palette.text }, horizontalAlignment: "center" }; summary.getRange("A5:K5").format = { fill: palette.header, font: { bold: true, color: palette.text }, horizontalAlignment: "center" };
  summary.getRangeByIndexes(5, 3, summaryRows.length, 8).format.numberFormat = "0.0000"; summary.freezePanes.freezeRows(5); setWidths(summary, [8, 8, 14, 13, 11, 11, 13, 13, 11, 11, 13]); styleUsed(summary, summaryRows.length + 5, 11, 5);

  writeTitle(thetas, "Estimated Theta Statistics", "Statistics calculated from every valid value in each n × 1,000 matrix by method and scenario.", 8);
  thetas.getRange("A4:H4").values = [["n", "p", "Method", "Mean", "SD", "Min", "Max", "Range"]];
  const thetaRows = metrics.theta_stats.map((row) => [row.n, row.p, row.method, valueOrNA(row.mean), valueOrNA(row.sd), valueOrNA(row.min), valueOrNA(row.max), valueOrNA(row.range)]);
  thetas.getRangeByIndexes(4, 0, thetaRows.length, 8).values = thetaRows; thetas.getRange("A4:H4").format = { fill: palette.header, font: { bold: true, color: palette.text }, horizontalAlignment: "center" }; thetas.getRangeByIndexes(4, 3, thetaRows.length, 5).format.numberFormat = "0.0000"; thetas.freezePanes.freezeRows(4); setWidths(thetas, [8, 8, 14, 12, 12, 12, 12, 13]); styleUsed(thetas, thetaRows.length + 4, 8, 4);

  writeTitle(quality, "Data Quality", "Read dimensions, missing files, and warnings used to determine which metrics are reported as NA.", 11);
  quality.getRange("A4:K4").values = [["n", "p", "Method", "Parameter", "File", "Rows", "Columns", "Expected rows", "Expected columns", "Status", "Note"]];
  const qualityRows = metrics.quality.map((row) => [valueOrNA(row.n), valueOrNA(row.p), row.method, row.param, translateText(row.file), valueOrNA(row.rows), valueOrNA(row.cols), valueOrNA(row.expected_rows), valueOrNA(row.expected_cols), row.status, translateText(row.note)]);
  quality.getRangeByIndexes(4, 0, qualityRows.length, 11).values = qualityRows; quality.getRange("A4:K4").format = { fill: palette.header, font: { bold: true, color: palette.text }, horizontalAlignment: "center" }; quality.getRangeByIndexes(4, 10, qualityRows.length, 1).format.wrapText = true;
  qualityRows.forEach((row, index) => { const fill = row[9] === "invalid" ? palette.invalid : row[9] === "missing" ? palette.missing : row[9] === "warning" ? palette.warning : null; if (fill) quality.getRangeByIndexes(index + 4, 0, 1, 11).format.fill = fill; });
  const checkStart = qualityRows.length + 7; quality.getRangeByIndexes(checkStart, 0, 1, 7).merge(); quality.getRangeByIndexes(checkStart, 0, 1, 7).values = [["Independent Manual Check"]]; quality.getRangeByIndexes(checkStart, 0, 1, 7).format = { fill: palette.group, font: { bold: true, color: palette.text } };
  quality.getRangeByIndexes(checkStart + 1, 0, 1, 7).values = [["Scenario", "Method", "Parameter", "Entity", "Bias", "RMSE", "Note"]]; quality.getRangeByIndexes(checkStart + 1, 0, 1, 7).format = { fill: palette.header, font: { bold: true, color: palette.text } };
  const checks = metrics.manual_checks.map((row) => [row.scenario, row.method, row.param, row.entity, row.bias, row.rmse, translateText(row.note)]); if (checks.length) quality.getRangeByIndexes(checkStart + 2, 0, checks.length, 7).values = checks;
  quality.freezePanes.freezeRows(4); setWidths(quality, [8, 8, 12, 11, 28, 10, 10, 16, 18, 12, 80]); styleUsed(quality, checkStart + checks.length + 2, 11, 4); return workbook;
}

function buildParameterWorkbook() {
  const workbook = Workbook.create(); const summary = workbook.worksheets.add("IRT_Summary"); const quality = workbook.worksheets.add("Quality");
  writeTitle(summary, "Classic versus Joint Comparison — IRT Parameters", "Aggregated RMSE and signed bias for parameters a, b, and alpha.", 9);
  summary.getRange("A4:C5").values = [["Scenario", "", ""], ["n", "p", "Method"]]; summary.getRange("D4:F4").merge(); summary.getRange("G4:I4").merge(); summary.getRange("D4:I4").values = [["RMSE", null, null, "Bias", null, null]]; summary.getRange("D5:I5").values = [["a", "b", "alpha", "a", "b", "alpha"]];
  const rows = metrics.summary.map((row) => [row.n, row.p, row.method, row.rmse_a, row.rmse_b, row.rmse_alpha, row.bias_a, row.bias_b, row.bias_alpha]); summary.getRangeByIndexes(5, 0, rows.length, 9).values = rows; summary.getRange("A4:I4").format = { fill: palette.group, font: { bold: true, color: palette.text }, horizontalAlignment: "center" }; summary.getRange("A5:I5").format = { fill: palette.header, font: { bold: true, color: palette.text }, horizontalAlignment: "center" }; summary.getRangeByIndexes(5, 3, rows.length, 6).format.numberFormat = "0.0000"; summary.freezePanes.freezeRows(5); setWidths(summary, [8, 8, 14, 12, 12, 13, 12, 12, 13]); styleUsed(summary, rows.length + 5, 9, 5);
  writeTitle(quality, "Data Quality — IRT Parameters", "Read dimensions for a, b, and alpha. Theta files are excluded from this table.", 11); quality.getRange("A4:K4").values = [["n", "p", "Method", "Parameter", "File", "Rows", "Columns", "Expected rows", "Expected columns", "Status", "Note"]];
  const qRows = metrics.quality.filter((row) => ["a", "b", "alpha"].includes(row.param)).map((row) => [valueOrNA(row.n), valueOrNA(row.p), row.method, row.param, translateText(row.file), valueOrNA(row.rows), valueOrNA(row.cols), valueOrNA(row.expected_rows), valueOrNA(row.expected_cols), row.status, translateText(row.note)]); quality.getRangeByIndexes(4, 0, qRows.length, 11).values = qRows; quality.getRange("A4:K4").format = { fill: palette.header, font: { bold: true, color: palette.text }, horizontalAlignment: "center" }; quality.getRangeByIndexes(4, 10, qRows.length, 1).format.wrapText = true; qRows.forEach((row, index) => { if (row[9] === "missing") quality.getRangeByIndexes(index + 4, 0, 1, 11).format.fill = palette.missing; }); quality.freezePanes.freezeRows(4); setWidths(quality, [8, 8, 12, 11, 28, 10, 10, 16, 18, 12, 45]); styleUsed(quality, qRows.length + 4, 11, 4); return workbook;
}

function parseCsv(text) {
  const rows = []; let row = [], cell = "", quoted = false;
  for (let index = 0; index < text.length; index += 1) { const char = text[index]; if (quoted && char === '"' && text[index + 1] === '"') { cell += '"'; index += 1; } else if (char === '"') quoted = !quoted; else if (!quoted && char === ",") { row.push(cell); cell = ""; } else if (!quoted && (char === "\n" || char === "\r")) { if (char === "\r" && text[index + 1] === "\n") index += 1; row.push(cell); if (row.some((value) => value !== "")) rows.push(row); row = []; cell = ""; } else cell += char; }
  if (cell || row.length) { row.push(cell); rows.push(row); } return rows;
}
function csvObjects(rows) {
  const [headers, ...data] = rows;
  return data.map((row) => Object.fromEntries(headers.map((header, index) => {
    const cell = row[index] ?? "";
    const value = cell !== "" && Number.isFinite(Number(cell)) ? Number(cell) : cell || null;
    return [header, value];
  })));
}
function typed(rows) { return rows.map((row, rowIndex) => row.map((cell) => rowIndex === 0 || cell === "" || !Number.isFinite(Number(cell)) ? translateText(cell) : Number(cell))); }
async function buildThetaWorkbook() {
  const workbook = Workbook.create(); const statistics = workbook.worksheets.add("Statistics"); const plotData = workbook.worksheets.add("Plot_Data");
  const metricsRows = typed(parseCsv(await fs.readFile(path.join(repo, "Spreadsheets (PT-BR)", "metricas_theta.csv"), "utf8"))); const meansRows = typed(parseCsv(await fs.readFile(path.join(repo, "Spreadsheets (PT-BR)", "theta_medias.csv"), "utf8")));
  metricsRows[0] = ["n", "method", "bias", "rmse", "mean", "standard_deviation", "minimum", "maximum", "range"]; meansRows[0] = ["n", "method", "individual", "true_theta", "mean_theta_estimate"];
  statistics.getRangeByIndexes(0, 0, metricsRows.length, metricsRows[0].length).values = metricsRows; plotData.getRangeByIndexes(0, 0, meansRows.length, meansRows[0].length).values = meansRows;
  for (const [sheet, rows] of [[statistics, metricsRows], [plotData, meansRows]]) { sheet.getRangeByIndexes(0, 0, 1, rows[0].length).format = { fill: palette.header, font: { bold: true, color: palette.text }, horizontalAlignment: "center" }; sheet.freezePanes.freezeRows(1); sheet.getUsedRange().format.autofitColumns(); sheet.showGridLines = false; }
  return workbook;
}

await renderAndExport(buildComparisonWorkbook(), "classic_joint_crm_comparison.xlsx", { IRT_Summary: "IRT_Summary.png", Thetas: "Thetas.png", Quality: "Quality.png" });
await renderAndExport(buildParameterWorkbook(), "crm_item_parameter_comparison.xlsx", { IRT_Summary: "IRT_Parameter_Summary.png", Quality: "Parameter_Quality.png" });
await renderAndExport(await buildThetaWorkbook(), "estimated_theta_statistics.xlsx");
console.log(JSON.stringify({ workbooks: 3, sheets: 7, status: "PASS" }));
