import fs from "node:fs/promises";
import path from "node:path";
import { SpreadsheetFile, Workbook } from "@oai/artifact-tool";

const outDir = path.dirname(decodeURIComponent(new URL(import.meta.url).pathname).replace(/^\/([A-Za-z]:\/)/, "$1"));
const data = JSON.parse(await fs.readFile(path.join(outDir, "metrics.json"), "utf8"));

const workbook = Workbook.create();
const summarySheet = workbook.worksheets.add("IRT_Summary");
const thetaSheet = workbook.worksheets.add("Thetas");
const qualitySheet = workbook.worksheets.add("Quality");

const palette = {
  title: "#243746",
  group: "#D9E8F5",
  header: "#EEF3F7",
  subheader: "#F7FAFC",
  warning: "#FDE9D9",
  invalid: "#FCE4E4",
  missing: "#F3F4F6",
  border: "#B8C4CF",
  text: "#111827",
};

function valueOrNull(value) {
  return value === null || value === undefined || Number.isNaN(value) ? "NA" : value;
}

function writeTitle(sheet, title, subtitle, lastCol) {
  const titleRange = sheet.getRangeByIndexes(0, 0, 1, lastCol);
  titleRange.merge();
  titleRange.values = [[title]];
  titleRange.format = {
    fill: palette.title,
    font: { bold: true, color: "#FFFFFF", size: 14 },
    horizontalAlignment: "center",
  };
  const subtitleRange = sheet.getRangeByIndexes(1, 0, 1, lastCol);
  subtitleRange.merge();
  subtitleRange.values = [[subtitle]];
  subtitleRange.format = {
    fill: "#FFFFFF",
    font: { italic: true, color: "#374151", size: 10 },
    horizontalAlignment: "center",
    wrapText: true,
  };
}

function styleBlock(sheet, rowCount, colCount, headerRows = 1) {
  const used = sheet.getRangeByIndexes(0, 0, rowCount, colCount);
  used.format.font = { color: palette.text, name: "Aptos", size: 10 };
  used.format.borders = { preset: "outside", style: "thin", color: palette.border };
  if (rowCount > headerRows) {
    sheet.getRangeByIndexes(headerRows, 0, rowCount - headerRows, colCount).format.borders = {
      insideHorizontal: { style: "thin", color: "#E5E7EB" },
    };
  }
  sheet.showGridLines = false;
}

function setWidths(sheet, widths) {
  widths.forEach((width, idx) => {
    sheet.getRangeByIndexes(0, idx, 1, 1).format.columnWidth = width;
  });
}

function buildSummary() {
  writeTitle(
    summarySheet,
    "Comparison Classic vs Joint - CRM",
    "Aggregated RMSE and signed bias for theta and IRT parameters. NA indicates a theta file with invalid dimensions.",
    11,
  );
  summarySheet.getRange("A4:C5").values = [
    ["Scenario", "", ""],
    ["n", "p", "Method"],
  ];
  summarySheet.getRange("D4:G4").merge();
  summarySheet.getRange("H4:K4").merge();
  summarySheet.getRange("D4:K4").values = [["RMSE", null, null, null, "Bias", null, null, null]];
  summarySheet.getRange("D5:K5").values = [["theta", "a", "b", "alpha", "theta", "a", "b", "alpha"]];

  const rows = data.summary.map((row) => [
    row.n,
    row.p,
    row.method,
    valueOrNull(row.rmse_theta),
    valueOrNull(row.rmse_a),
    valueOrNull(row.rmse_b),
    valueOrNull(row.rmse_alpha),
    valueOrNull(row.bias_theta),
    valueOrNull(row.bias_a),
    valueOrNull(row.bias_b),
    valueOrNull(row.bias_alpha),
  ]);
  summarySheet.getRangeByIndexes(5, 0, rows.length, 11).values = rows;

  summarySheet.getRange("A4:K4").format = {
    fill: palette.group,
    font: { bold: true, color: palette.text },
    horizontalAlignment: "center",
  };
  summarySheet.getRange("A5:K5").format = {
    fill: palette.header,
    font: { bold: true, color: palette.text },
    horizontalAlignment: "center",
  };
  summarySheet.getRangeByIndexes(5, 3, rows.length, 8).format.numberFormat = "0.0000";
  summarySheet.getRangeByIndexes(5, 0, rows.length, 2).format.numberFormat = "0";
  summarySheet.getRangeByIndexes(5, 0, rows.length, 11).format.borders = {
    insideHorizontal: { style: "thin", color: "#E5E7EB" },
    insideVertical: { style: "thin", color: "#EEF2F7" },
  };
  summarySheet.freezePanes.freezeRows(5);
  setWidths(summarySheet, [8, 8, 14, 13, 11, 11, 13, 13, 11, 11, 13]);
  styleBlock(summarySheet, rows.length + 5, 11, 5);
}

function buildThetaStats() {
  writeTitle(
    thetaSheet,
    "Estimated Theta Statistics",
    "Estatisticas calculadas sobre todos os values validos da matriz n x 1000 de cada method e cenario.",
    8,
  );
  const header = [["n", "p", "Method", "Mean", "DP", "Min", "Max", "Range"]];
  const rows = data.theta_stats.map((row) => [
    row.n,
    row.p,
    row.method,
    valueOrNull(row.mean),
    valueOrNull(row.sd),
    valueOrNull(row.min),
    valueOrNull(row.max),
    valueOrNull(row.range),
  ]);
  thetaSheet.getRange("A4:H4").values = header;
  thetaSheet.getRangeByIndexes(4, 0, rows.length, 8).values = rows;
  thetaSheet.getRange("A4:H4").format = {
    fill: palette.header,
    font: { bold: true, color: palette.text },
    horizontalAlignment: "center",
  };
  thetaSheet.getRangeByIndexes(4, 3, rows.length, 5).format.numberFormat = "0.0000";
  thetaSheet.getRangeByIndexes(4, 0, rows.length, 2).format.numberFormat = "0";
  thetaSheet.freezePanes.freezeRows(4);
  setWidths(thetaSheet, [8, 8, 14, 12, 12, 12, 12, 13]);
  styleBlock(thetaSheet, rows.length + 4, 8, 4);
}

function buildQuality() {
  writeTitle(
    qualitySheet,
    "Quality dos Data",
    "Read dimensions, missing files, and warnings used to determine which metrics are reported as NA.",
    11,
  );
  const headers = [
    "n",
    "p",
    "Method",
    "Parameter",
    "File",
    "Rows",
    "Columns",
    "Expected rows",
    "Expected columns",
    "Status",
    "Note",
  ];
  const rows = data.quality.map((row) => [
    valueOrNull(row.n),
    valueOrNull(row.p),
    row.method,
    row.param,
    row.file,
    valueOrNull(row.rows),
    valueOrNull(row.cols),
    valueOrNull(row.expected_rows),
    valueOrNull(row.expected_cols),
    row.status,
    row.note,
  ]);
  qualitySheet.getRange("A4:K4").values = [headers];
  qualitySheet.getRangeByIndexes(4, 0, rows.length, 11).values = rows;
  qualitySheet.getRange("A4:K4").format = {
    fill: palette.header,
    font: { bold: true, color: palette.text },
    horizontalAlignment: "center",
  };
  qualitySheet.getRangeByIndexes(4, 0, rows.length, 9).format.numberFormat = "0";
  qualitySheet.getRangeByIndexes(4, 10, rows.length, 1).format.wrapText = true;
  qualitySheet.freezePanes.freezeRows(4);
  setWidths(qualitySheet, [8, 8, 12, 11, 28, 10, 10, 16, 18, 12, 80]);
  styleBlock(qualitySheet, rows.length + 4, 11, 4);

  rows.forEach((row, idx) => {
    const status = row[9];
    if (status === "invalid") {
      qualitySheet.getRangeByIndexes(idx + 4, 0, 1, 11).format.fill = palette.invalid;
    } else if (status === "missing") {
      qualitySheet.getRangeByIndexes(idx + 4, 0, 1, 11).format.fill = palette.missing;
    } else if (status === "warning") {
      qualitySheet.getRangeByIndexes(idx + 4, 0, 1, 11).format.fill = palette.warning;
    }
  });

  const checkStart = rows.length + 7;
  qualitySheet.getRangeByIndexes(checkStart, 0, 1, 7).merge();
  qualitySheet.getRangeByIndexes(checkStart, 0, 1, 7).values = [["Independent Manual Check"]];
  qualitySheet.getRangeByIndexes(checkStart, 0, 1, 7).format = {
    fill: palette.group,
    font: { bold: true, color: palette.text },
  };
  qualitySheet.getRangeByIndexes(checkStart + 1, 0, 1, 7).values = [
    ["Scenario", "Method", "Parameter", "Entity", "Bias", "RMSE", "Note"],
  ];
  qualitySheet.getRangeByIndexes(checkStart + 1, 0, 1, 7).format = {
    fill: palette.header,
    font: { bold: true, color: palette.text },
  };
  const checks = data.manual_checks.map((row) => [
    row.scenario,
    row.method,
    row.param,
    row.entity,
    row.bias,
    row.rmse,
    row.note,
  ]);
  if (checks.length) {
    qualitySheet.getRangeByIndexes(checkStart + 2, 0, checks.length, 7).values = checks;
    qualitySheet.getRangeByIndexes(checkStart + 2, 4, checks.length, 2).format.numberFormat = "0.0000";
  }
}

buildSummary();
buildThetaStats();
buildQuality();

const summaryInspect = await workbook.inspect({
  kind: "region",
  sheetId: "IRT_Summary",
  range: "A1:K13",
  maxChars: 5000,
});
await fs.writeFile(path.join(outDir, "inspect_resumo_tri.ndjson"), summaryInspect.ndjson, "utf8");

const errorScan = await workbook.inspect({
  kind: "match",
  searchTerm: "#REF!|#DIV/0!|#VALUE!|#NAME\\?|#N/A",
  options: { useRegex: true, maxResults: 100 },
  summary: "final formula error scan",
});
await fs.writeFile(path.join(outDir, "inspect_errors.ndjson"), errorScan.ndjson, "utf8");

for (const sheetName of ["IRT_Summary", "Thetas", "Quality"]) {
  const preview = await workbook.render({ sheetName, autoCrop: "all", scale: 1, format: "png" });
  await fs.writeFile(path.join(outDir, `${sheetName}.png`), new Uint8Array(await preview.arrayBuffer()));
}

const output = await SpreadsheetFile.exportXlsx(workbook);
await output.save(path.join(outDir, "classic_joint_crm_comparison.xlsx"));
