import fs from "node:fs/promises";
import path from "node:path";
import { FileBlob, SpreadsheetFile, Workbook } from "@oai/artifact-tool";


const [blockReportPath, fullReportPath, outputPath, previewDir] = process.argv.slice(2);
if (!blockReportPath || !fullReportPath || !outputPath || !previewDir) {
  throw new Error("Expected block report, full-page report, output workbook, and preview directory.");
}

const blockReport = JSON.parse(await fs.readFile(blockReportPath, "utf8"));
const fullReport = JSON.parse(await fs.readFile(fullReportPath, "utf8"));
if (blockReport.source_pdf_sha256 !== fullReport.source_pdf_sha256) {
  throw new Error("The two OCR reports do not refer to the same source PDF.");
}
if (blockReport.pages.length !== fullReport.pages.length) {
  throw new Error("The two OCR reports have different page counts.");
}

const fields = ["full_name", "address", "mobile", "email", "registration_date"];
const safeText = (value) => {
  const text = value == null ? "" : String(value);
  return /^[=+\-@]/.test(text) ? `'${text}` : text;
};
const joinList = (items) => (items ?? []).map(safeText).join(" | ");
const normalize = (value) => String(value ?? "")
  .normalize("NFD")
  .replace(/\p{M}/gu, "")
  .toLocaleLowerCase("el")
  .replace(/[^\p{L}\p{N}]+/gu, "");
const displayNames = {
  full_name: "full name",
  address: "address",
  mobile: "mobile",
  email: "email",
  registration_date: "registration date",
};
const confirmedCorrections = new Map([
  [15, { email: "mariagoniotaki@hotmail.com" }],
]);

const comparisonRows = [];
let disagreementCount = 0;
for (let index = 0; index < blockReport.pages.length; index += 1) {
  const blockPage = blockReport.pages[index];
  const fullPage = fullReport.pages[index];
  if (blockPage.page !== fullPage.page) {
    throw new Error(`Page alignment mismatch at row ${index + 1}.`);
  }
  const differentFields = fields.filter((field) => (
    normalize(blockPage.fields[field].value) !== normalize(fullPage.fields[field].value)
  ));
  disagreementCount += differentFields.length;
  const reviewed = confirmedCorrections.get(blockPage.page) ?? {};
  comparisonRows.push([
    blockPage.page,
    safeText(blockPage.fields.full_name.value), safeText(fullPage.fields.full_name.value), safeText(reviewed.full_name ?? ""),
    safeText(blockPage.fields.address.value), safeText(fullPage.fields.address.value), safeText(reviewed.address ?? ""),
    safeText(blockPage.fields.mobile.value), safeText(fullPage.fields.mobile.value), safeText(reviewed.mobile ?? ""),
    safeText(blockPage.fields.email.value), safeText(fullPage.fields.email.value), safeText(reviewed.email ?? ""),
    safeText(blockPage.fields.registration_date.value), safeText(fullPage.fields.registration_date.value), safeText(reviewed.registration_date ?? ""),
    joinList(differentFields.map((field) => displayNames[field])),
    joinList(fullPage.ai_flagged_fields.map((field) => displayNames[field])),
    joinList(fullPage.format_issues),
    "ΧΡΕΙΑΖΕΤΑΙ ΕΛΕΓΧΟ",
  ]);
}

const workbook = Workbook.create();
const comparison = workbook.worksheets.add("Comparison");
const detail = workbook.worksheets.add("Full-page detail");
const fontName = "Arial";
const lastComparisonRow = 5 + comparisonRows.length;

comparison.showGridLines = false;
comparison.getRange("A1:T1").format.borders = {
  bottom: { style: "thin", color: "#7F8C8D" },
};
comparison.getRange("A1").values = [["Full-page OCR comparison"]];
comparison.getRange("A1").format.font = { name: fontName, size: 16, bold: true, color: "#1F2937" };
comparison.getRange("A2:T2").merge(true);
comparison.getRange("A2").values = [[
  `${fullReport.summary.page_count} dummy forms. Full-page AI result vs prior block result; neither result is approved for import.`,
]];
comparison.getRange("A2:T2").format.font = { name: fontName, size: 10, italic: true, color: "#4B5563" };
comparison.getRange("A3:H3").values = [[
  "Pages", fullReport.summary.page_count,
  "Full-page AI flags", fullReport.summary.ai_flag_count,
  "Format failures", fullReport.summary.format_issue_count,
  "Different fields", disagreementCount,
]];
comparison.getRange("A3:H3").format.font = { name: fontName, size: 10, bold: true, color: "#374151" };

const headers = [
  "Page",
  "Block full name", "Full-page full name", "Reviewed full name",
  "Block address", "Full-page address", "Reviewed address",
  "Block mobile", "Full-page mobile", "Reviewed mobile",
  "Block email", "Full-page email", "Reviewed email",
  "Block registration date", "Full-page registration date", "Reviewed registration date",
  "Different fields", "Full-page AI flags", "Full-page format issues", "Review status",
];
comparison.getRange("A5:T5").values = [headers];
comparison.getRange(`A6:T${lastComparisonRow}`).values = comparisonRows;
comparison.getRange("A5:T5").format = {
  fill: "#1F4E78",
  font: { name: fontName, size: 10, bold: true, color: "#FFFFFF" },
  horizontalAlignment: "center",
  verticalAlignment: "center",
  wrapText: true,
  borders: { preset: "inside", style: "thin", color: "#FFFFFF" },
};
comparison.getRange(`A6:T${lastComparisonRow}`).format.font = { name: fontName, size: 10, color: "#1F2937" };
comparison.getRange(`A6:T${lastComparisonRow}`).format.verticalAlignment = "top";
comparison.getRange(`B6:T${lastComparisonRow}`).format.wrapText = true;
for (const column of ["B", "E", "H", "K", "N"]) {
  comparison.getRange(`${column}6:${column}${lastComparisonRow}`).format.fill = "#F3F4F6";
}
for (const column of ["C", "F", "I", "L", "O"]) {
  comparison.getRange(`${column}6:${column}${lastComparisonRow}`).format.fill = "#EAF3F8";
}
for (const column of ["D", "G", "J", "M", "P"]) {
  comparison.getRange(`${column}6:${column}${lastComparisonRow}`).format.fill = "#FFF2CC";
}
comparison.getRange(`A6:A${lastComparisonRow}`).format.horizontalAlignment = "center";
comparison.getRange(`Q6:Q${lastComparisonRow}`).conditionalFormats.addCustom(
  "=LEN($Q6)>0",
  { fill: "#FCE8E6", font: { color: "#B91C1C", bold: true } },
);
comparison.getRange(`R6:R${lastComparisonRow}`).conditionalFormats.addCustom(
  "=LEN($R6)>0",
  { fill: "#FFF2CC", font: { color: "#9C6500" } },
);
comparison.getRange(`S6:S${lastComparisonRow}`).conditionalFormats.addCustom(
  "=LEN($S6)>0",
  { fill: "#FCE8E6", font: { color: "#B91C1C", bold: true } },
);
comparison.getRange(`T6:T${lastComparisonRow}`).dataValidation = {
  rule: { type: "list", values: ["ΧΡΕΙΑΖΕΤΑΙ ΕΛΕΓΧΟ", "ΕΛΕΓΧΘΗΚΕ"] },
};
comparison.getRange(`T6:T${lastComparisonRow}`).conditionalFormats.add(
  "containsText",
  { text: "ΧΡΕΙΑΖΕΤΑΙ ΕΛΕΓΧΟ", format: { fill: "#FFF2CC", font: { color: "#9C6500", bold: true } } },
);
comparison.freezePanes.freezeRows(5);
comparison.freezePanes.freezeColumns(1);
const comparisonWidths = [7, 23, 23, 23, 26, 26, 26, 16, 16, 16, 29, 29, 29, 19, 19, 19, 25, 25, 24, 22];
comparisonWidths.forEach((width, index) => {
  comparison.getRangeByIndexes(0, index, lastComparisonRow, 1).format.columnWidth = width;
});
comparison.getRange("A1:T3").format.rowHeight = 22;
comparison.getRange("A5:T5").format.rowHeight = 38;
comparison.getRange(`A6:T${lastComparisonRow}`).format.rowHeight = 48;

detail.showGridLines = false;
detail.getRange("A1:G1").format.borders = {
  bottom: { style: "thin", color: "#7F8C8D" },
};
detail.getRange("A1").values = [["Full-page OCR detail"]];
detail.getRange("A1").format.font = { name: fontName, size: 16, bold: true, color: "#1F2937" };
detail.getRange("A2:G2").merge(true);
detail.getRange("A2").values = [[
  `Source: ${fullReport.source_pdf}; one complete-page image per AI request; no block crops or hidden identifiers.`,
]];
detail.getRange("A2:G2").format.font = { name: fontName, size: 9, color: "#4B5563" };
detail.getRange("A3:G3").merge(true);
detail.getRange("A3").values = [[
  `Source SHA-256: ${fullReport.source_pdf_sha256}`,
]];
detail.getRange("A3:G3").format.font = { name: fontName, size: 9, italic: true, color: "#4B5563" };
detail.getRange("A5:G5").values = [[
  "Page", "Field", "Full-page transcription", "AI needs review", "Alternatives", "Format issues", "Result SHA-256",
]];
const hashByPage = new Map(fullReport.integrity.results.map((item) => [item.page, item.result_sha256]));
const detailRows = [];
for (const page of fullReport.pages) {
  for (const field of fields) {
    const result = page.fields[field];
    detailRows.push([
      page.page,
      displayNames[field],
      safeText(result.value),
      result.ai_needs_review ? "YES" : "NO",
      joinList(result.alternatives),
      joinList(result.format_issues),
      hashByPage.get(page.page),
    ]);
  }
}
const lastDetailRow = 5 + detailRows.length;
detail.getRange(`A6:G${lastDetailRow}`).values = detailRows;
detail.getRange("A5:G5").format = {
  fill: "#374151",
  font: { name: fontName, size: 10, bold: true, color: "#FFFFFF" },
  horizontalAlignment: "center",
  verticalAlignment: "center",
  wrapText: true,
  borders: { preset: "inside", style: "thin", color: "#FFFFFF" },
};
detail.getRange(`A6:G${lastDetailRow}`).format.font = { name: fontName, size: 9, color: "#1F2937" };
detail.getRange(`A6:G${lastDetailRow}`).format.verticalAlignment = "top";
detail.getRange(`B6:F${lastDetailRow}`).format.wrapText = true;
detail.getRange(`D6:D${lastDetailRow}`).conditionalFormats.add(
  "containsText",
  { text: "YES", format: { fill: "#FFF2CC", font: { color: "#9C6500", bold: true } } },
);
detail.getRange(`F6:F${lastDetailRow}`).conditionalFormats.addCustom(
  "=LEN($F6)>0",
  { fill: "#FCE8E6", font: { color: "#B91C1C", bold: true } },
);
detail.freezePanes.freezeRows(5);
detail.freezePanes.freezeColumns(2);
const detailWidths = [7, 22, 38, 17, 38, 24, 68];
detailWidths.forEach((width, index) => {
  detail.getRangeByIndexes(0, index, lastDetailRow, 1).format.columnWidth = width;
});
detail.getRange("A5:G5").format.rowHeight = 34;
detail.getRange(`A6:G${lastDetailRow}`).format.rowHeight = 34;

const comparisonCheck = await workbook.inspect({
  kind: "table",
  range: `Comparison!A1:T${lastComparisonRow}`,
  include: "values,formulas",
  tableMaxRows: 24,
  tableMaxCols: 20,
  maxChars: 16000,
});
console.log(comparisonCheck.ndjson);
const detailCheck = await workbook.inspect({
  kind: "table",
  range: "Full-page detail!A1:G20",
  include: "values,formulas",
  tableMaxRows: 20,
  tableMaxCols: 7,
  maxChars: 8000,
});
console.log(detailCheck.ndjson);
const errors = await workbook.inspect({
  kind: "match",
  searchTerm: "#REF!|#DIV/0!|#VALUE!|#NAME\\?|#N/A|#NUM!|#NULL!|#SPILL!|#CALC!",
  options: { useRegex: true, maxResults: 300 },
  summary: "final formula error scan",
});
console.log(errors.ndjson);

await fs.mkdir(previewDir, { recursive: true });
const comparisonPreview = await workbook.render({
  sheetName: "Comparison",
  range: `A1:T${lastComparisonRow}`,
  scale: 1,
  format: "png",
});
await fs.writeFile(path.join(previewDir, "comparison.png"), new Uint8Array(await comparisonPreview.arrayBuffer()));
const detailPreview = await workbook.render({
  sheetName: "Full-page detail",
  range: "A1:G30",
  scale: 1,
  format: "png",
});
await fs.writeFile(path.join(previewDir, "fullpage_detail.png"), new Uint8Array(await detailPreview.arrayBuffer()));

await fs.mkdir(path.dirname(outputPath), { recursive: true });
const output = await SpreadsheetFile.exportXlsx(workbook);
await output.save(outputPath);
const saved = await FileBlob.load(outputPath);
const reopened = await SpreadsheetFile.importXlsx(saved);
const reopenedCheck = await reopened.inspect({
  kind: "table",
  range: "Comparison!A1:T10",
  include: "values,formulas",
  tableMaxRows: 10,
  tableMaxCols: 20,
  maxChars: 8000,
});
console.log(reopenedCheck.ndjson);
console.log(outputPath);
