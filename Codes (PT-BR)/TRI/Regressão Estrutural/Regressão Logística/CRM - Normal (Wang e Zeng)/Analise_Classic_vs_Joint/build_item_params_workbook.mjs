import fs from "node:fs/promises";
import path from "node:path";
import { SpreadsheetFile, Workbook } from "@oai/artifact-tool";

const outDir = path.dirname(decodeURIComponent(new URL(import.meta.url).pathname).replace(/^\/([A-Za-z]:\/)/, "$1"));
const data = JSON.parse(await fs.readFile(path.join(outDir, "metrics.json"), "utf8"));

const workbook = Workbook.create();
const summarySheet = workbook.worksheets.add("Resumo_TRI");
const qualitySheet = workbook.worksheets.add("Qualidade");

const palette = {
  title: "#243746",
  group: "#D9E8F5",
  header: "#EEF3F7",
  missing: "#F3F4F6",
  border: "#B8C4CF",
  text: "#111827",
};

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
  };
}

function setWidths(sheet, widths) {
  widths.forEach((width, idx) => {
    sheet.getRangeByIndexes(0, idx, 1, 1).format.columnWidth = width;
  });
}

function styleUsed(sheet, rowCount, colCount, headerRows) {
  const used = sheet.getRangeByIndexes(0, 0, rowCount, colCount);
  used.format.font = { color: palette.text, name: "Aptos", size: 10 };
  used.format.borders = { preset: "outside", style: "thin", color: palette.border };
  if (rowCount > headerRows) {
    sheet.getRangeByIndexes(headerRows, 0, rowCount - headerRows, colCount).format.borders = {
      insideHorizontal: { style: "thin", color: "#E5E7EB" },
      insideVertical: { style: "thin", color: "#EEF2F7" },
    };
  }
  sheet.showGridLines = false;
}

function round4(value) {
  return value === null || value === undefined ? "NA" : value;
}

function buildSummary() {
  writeTitle(
    summarySheet,
    "Comparacao Classic vs Joint - Parametros da TRI",
    "Medias agregadas de RMSE e vicio assinado para os parametros a, b e alpha.",
    9,
  );

  summarySheet.getRange("A4:C5").values = [
    ["Cenario", "", ""],
    ["n", "p", "Metodo"],
  ];
  summarySheet.getRange("D4:F4").merge();
  summarySheet.getRange("G4:I4").merge();
  summarySheet.getRange("D4:I4").values = [["RMSE", null, null, "Vicio", null, null]];
  summarySheet.getRange("D5:I5").values = [["a", "b", "alpha", "a", "b", "alpha"]];

  const rows = data.summary.map((row) => [
    row.n,
    row.p,
    row.method,
    round4(row.rmse_a),
    round4(row.rmse_b),
    round4(row.rmse_alpha),
    round4(row.bias_a),
    round4(row.bias_b),
    round4(row.bias_alpha),
  ]);

  summarySheet.getRangeByIndexes(5, 0, rows.length, 9).values = rows;
  summarySheet.getRange("A4:I4").format = {
    fill: palette.group,
    font: { bold: true, color: palette.text },
    horizontalAlignment: "center",
  };
  summarySheet.getRange("A5:I5").format = {
    fill: palette.header,
    font: { bold: true, color: palette.text },
    horizontalAlignment: "center",
  };
  summarySheet.getRangeByIndexes(5, 3, rows.length, 6).format.numberFormat = "0.0000";
  summarySheet.getRangeByIndexes(5, 0, rows.length, 2).format.numberFormat = "0";
  summarySheet.freezePanes.freezeRows(5);
  setWidths(summarySheet, [8, 8, 14, 12, 12, 13, 12, 12, 13]);
  styleUsed(summarySheet, rows.length + 5, 9, 5);
}

function buildQuality() {
  writeTitle(
    qualitySheet,
    "Qualidade dos Dados - Parametros da TRI",
    "Dimensoes lidas para a, b e alpha. A tabela exclui os arquivos de theta.",
    11,
  );

  const headers = [
    "n",
    "p",
    "Metodo",
    "Parametro",
    "Arquivo",
    "Linhas",
    "Colunas",
    "Linhas esperadas",
    "Colunas esperadas",
    "Status",
    "Nota",
  ];
  const rows = data.quality
    .filter((row) => ["a", "b", "alpha"].includes(row.param))
    .map((row) => [
      row.n ?? "NA",
      row.p ?? "NA",
      row.method,
      row.param,
      row.file,
      row.rows ?? "NA",
      row.cols ?? "NA",
      row.expected_rows ?? "NA",
      row.expected_cols ?? "NA",
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
  rows.forEach((row, idx) => {
    if (row[9] === "missing") {
      qualitySheet.getRangeByIndexes(idx + 4, 0, 1, 11).format.fill = palette.missing;
    }
  });
  qualitySheet.freezePanes.freezeRows(4);
  setWidths(qualitySheet, [8, 8, 12, 11, 28, 10, 10, 16, 18, 12, 45]);
  styleUsed(qualitySheet, rows.length + 4, 11, 4);
}

function buildMarkdown() {
  const lines = [
    "# Comparacao Classic vs Joint - Parametros da TRI",
    "",
    "| n | p | Metodo | RMSE a | RMSE b | RMSE alpha | Vicio a | Vicio b | Vicio alpha |",
    "|---:|---:|---|---:|---:|---:|---:|---:|---:|",
  ];
  for (const row of data.summary) {
    lines.push(
      `| ${row.n} | ${row.p} | ${row.method} | ${row.rmse_a.toFixed(4)} | ${row.rmse_b.toFixed(4)} | ${row.rmse_alpha.toFixed(4)} | ${row.bias_a.toFixed(4)} | ${row.bias_b.toFixed(4)} | ${row.bias_alpha.toFixed(4)} |`,
    );
  }
  return `${lines.join("\n")}\n`;
}

buildSummary();
buildQuality();

const inspect = await workbook.inspect({
  kind: "region",
  sheetId: "Resumo_TRI",
  range: "A1:I13",
  maxChars: 4000,
});
await fs.writeFile(path.join(outDir, "inspect_parametros_tri.ndjson"), inspect.ndjson, "utf8");

const errors = await workbook.inspect({
  kind: "match",
  searchTerm: "#REF!|#DIV/0!|#VALUE!|#NAME\\?|#N/A",
  options: { useRegex: true, maxResults: 100 },
  summary: "final formula error scan",
});
await fs.writeFile(path.join(outDir, "inspect_parametros_tri_errors.ndjson"), errors.ndjson, "utf8");

for (const sheetName of ["Resumo_TRI", "Qualidade"]) {
  const preview = await workbook.render({ sheetName, autoCrop: "all", scale: 1, format: "png" });
  await fs.writeFile(path.join(outDir, `Parametros_${sheetName}.png`), new Uint8Array(await preview.arrayBuffer()));
}

await fs.writeFile(path.join(outDir, "comparacao_parametros_tri.md"), buildMarkdown(), "utf8");

const output = await SpreadsheetFile.exportXlsx(workbook);
await output.save(path.join(outDir, "comparacao_parametros_tri_crm.xlsx"));
