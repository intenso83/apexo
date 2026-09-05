import fs from "node:fs/promises";
import path from "node:path";
import { FileBlob, SpreadsheetFile, Workbook } from "@oai/artifact-tool";


const [reportPath, manifestPath, resultsDir, outputPath, previewDir] = process.argv.slice(2);
if (!reportPath || !manifestPath || !resultsDir || !outputPath || !previewDir) {
  throw new Error("Expected report, manifest, results directory, output workbook, and preview directory.");
}

const report = JSON.parse(await fs.readFile(reportPath, "utf8"));
const manifest = JSON.parse(await fs.readFile(manifestPath, "utf8"));
const safeText = (value) => {
  const text = value == null ? "" : String(value);
  return /^[=+\-@]/.test(text) ? `'${text}` : text;
};
const joinList = (items) => (items ?? []).map(safeText).join(" | ");
const confirmedCorrections = new Map([
  [15, { email: "mariagoniotaki@hotmail.com" }],
]);

const workbook = Workbook.create();
const review = workbook.worksheets.add("OCR Review");
const audit = workbook.worksheets.add("Block Audit");
const fontName = "Arial";

review.showGridLines = false;
review.getRange("A1:N1").format.borders = {
  bottom: { style: "thin", color: "#7F8C8D" },
};
review.getRange("A1").values = [["Dummy OCR batch"]];
review.getRange("A1").format.font = { name: fontName, size: 16, bold: true, color: "#1F2937" };
review.getRange("A2").values = [[
  `${report.summary.page_count} dummy forms from ${report.source_pdf}. OCR output only; not approved for import.`,
]];
review.getRange("A2:N2").merge(true);
review.getRange("A2:N2").format.font = { name: fontName, size: 10, italic: true, color: "#4B5563" };
review.getRange("A3:E3").values = [[
  "Pages", report.summary.page_count,
  "AI-flagged fields", report.summary.ai_flag_count,
  `Format failures: ${report.summary.format_issue_count}`,
]];
review.getRange("A3:E3").format.font = { name: fontName, size: 10, bold: true, color: "#374151" };

const reviewHeaders = [
  "Page",
  "OCR full name",
  "Reviewed full name",
  "OCR address",
  "Reviewed address",
  "OCR mobile",
  "Reviewed mobile",
  "OCR email",
  "Reviewed email",
  "OCR registration date",
  "Reviewed registration date",
  "AI flagged fields",
  "Format issues",
  "Review status",
];
review.getRange("A5:N5").values = [reviewHeaders];
const reviewRows = report.pages.map((page) => [
  page.page,
  safeText(page.fields.full_name.value), "",
  safeText(page.fields.address.value), "",
  safeText(page.fields.mobile.value), "",
  safeText(page.fields.email.value), safeText(confirmedCorrections.get(page.page)?.email ?? ""),
  safeText(page.fields.registration_date.value), "",
  joinList([
    ...page.ai_flagged_fields,
    ...(confirmedCorrections.has(page.page) ? ["email confirmed correction"] : []),
  ]),
  joinList(page.format_issues),
  page.human_review_status,
]);
review.getRange(`A6:N${5 + reviewRows.length}`).values = reviewRows;
review.getRange("A5:N5").format = {
  fill: "#1F4E78",
  font: { name: fontName, size: 10, bold: true, color: "#FFFFFF" },
  horizontalAlignment: "center",
  verticalAlignment: "center",
  wrapText: true,
  borders: { preset: "inside", style: "thin", color: "#FFFFFF" },
};
review.getRange(`A6:N${5 + reviewRows.length}`).format.font = { name: fontName, size: 10, color: "#1F2937" };
review.getRange(`A6:N${5 + reviewRows.length}`).format.verticalAlignment = "top";
review.getRange(`B6:N${5 + reviewRows.length}`).format.wrapText = true;
for (const column of ["C", "E", "G", "I", "K"]) {
  review.getRange(`${column}6:${column}${5 + reviewRows.length}`).format.fill = "#FFF2CC";
}
review.getRange(`A6:A${5 + reviewRows.length}`).format.horizontalAlignment = "center";
review.getRange(`N6:N${5 + reviewRows.length}`).dataValidation = {
  rule: { type: "list", values: ["ΧΡΕΙΑΖΕΤΑΙ ΕΛΕΓΧΟ", "ΕΛΕΓΧΘΗΚΕ"] },
};
review.getRange(`L6:L${5 + reviewRows.length}`).conditionalFormats.addCustom(
  "=LEN($L6)>0",
  { fill: "#FFF2CC", font: { color: "#9C6500" } },
);
review.getRange(`M6:M${5 + reviewRows.length}`).conditionalFormats.addCustom(
  "=LEN($M6)>0",
  { fill: "#FCE8E6", font: { color: "#B91C1C", bold: true } },
);
review.getRange(`N6:N${5 + reviewRows.length}`).conditionalFormats.add(
  "containsText",
  { text: "ΧΡΕΙΑΖΕΤΑΙ ΕΛΕΓΧΟ", format: { fill: "#FFF2CC", font: { color: "#9C6500", bold: true } } },
);
review.freezePanes.freezeRows(5);
review.freezePanes.freezeColumns(1);
const reviewWidths = [7, 25, 25, 27, 27, 16, 16, 31, 31, 20, 20, 22, 24, 22];
reviewWidths.forEach((width, index) => {
  review.getRangeByIndexes(0, index, 5 + reviewRows.length, 1).format.columnWidth = width;
});
review.getRange("A1:N3").format.rowHeight = 22;
review.getRange("A5:N5").format.rowHeight = 34;
review.getRange(`A6:N${5 + reviewRows.length}`).format.rowHeight = 44;

const resultById = new Map();
for (const block of manifest.blocks) {
  const result = JSON.parse(await fs.readFile(path.join(resultsDir, `${block.block_id}.json`), "utf8"));
  resultById.set(block.block_id, result);
}
const resultHashById = new Map(report.integrity.results.map((item) => [item.block_id, item.result_sha256]));

audit.showGridLines = false;
audit.getRange("A1:I1").format.borders = {
  bottom: { style: "thin", color: "#7F8C8D" },
};
audit.getRange("A1").values = [["Block audit"]];
audit.getRange("A1").format.font = { name: fontName, size: 16, bold: true, color: "#1F2937" };
audit.getRange("A2").values = [[
  `Source: ${report.source_pdf}; SHA-256: ${report.source_pdf_sha256}`,
]];
audit.getRange("A2:I2").merge(true);
audit.getRange("A2:I2").format.font = { name: fontName, size: 9, color: "#4B5563" };
audit.getRange("A3").values = [[
  "Each random block ID was recognized in a separate request and mapped back locally.",
]];
audit.getRange("A3:I3").merge(true);
audit.getRange("A3:I3").format.font = { name: fontName, size: 9, italic: true, color: "#4B5563" };
const auditHeaders = [
  "Page", "Field", "Block ID", "OCR transcription", "AI needs review",
  "Alternatives", "Format issues", "Image SHA-256", "Result SHA-256",
];
audit.getRange("A5:I5").values = [auditHeaders];
const auditRows = manifest.blocks.map((block) => {
  const result = resultById.get(block.block_id);
  const page = report.pages.find((item) => item.page === block.page);
  const field = page.fields[block.field];
  return [
    block.page,
    block.field,
    block.block_id,
    safeText(result.transcription),
    result.needs_review ? "YES" : "NO",
    joinList(result.alternatives),
    joinList(field.format_issues),
    block.image_sha256,
    resultHashById.get(block.block_id),
  ];
});
audit.getRange(`A6:I${5 + auditRows.length}`).values = auditRows;
audit.getRange("A5:I5").format = {
  fill: "#374151",
  font: { name: fontName, size: 10, bold: true, color: "#FFFFFF" },
  horizontalAlignment: "center",
  verticalAlignment: "center",
  wrapText: true,
  borders: { preset: "inside", style: "thin", color: "#FFFFFF" },
};
audit.getRange(`A6:I${5 + auditRows.length}`).format.font = { name: fontName, size: 9, color: "#1F2937" };
audit.getRange(`A6:I${5 + auditRows.length}`).format.verticalAlignment = "top";
audit.getRange(`B6:G${5 + auditRows.length}`).format.wrapText = true;
audit.getRange(`E6:E${5 + auditRows.length}`).conditionalFormats.add(
  "containsText",
  { text: "YES", format: { fill: "#FFF2CC", font: { color: "#9C6500", bold: true } } },
);
audit.getRange(`G6:G${5 + auditRows.length}`).conditionalFormats.addCustom(
  "=LEN($G6)>0",
  { fill: "#FCE8E6", font: { color: "#B91C1C", bold: true } },
);
audit.freezePanes.freezeRows(5);
audit.freezePanes.freezeColumns(3);
const auditWidths = [7, 22, 29, 34, 17, 34, 24, 68, 68];
auditWidths.forEach((width, index) => {
  audit.getRangeByIndexes(0, index, 5 + auditRows.length, 1).format.columnWidth = width;
});
audit.getRange("A5:I5").format.rowHeight = 32;
audit.getRange(`A6:I${5 + auditRows.length}`).format.rowHeight = 34;

const reviewCheck = await workbook.inspect({
  kind: "table",
  range: `OCR Review!A1:N${5 + reviewRows.length}`,
  include: "values,formulas",
  tableMaxRows: 24,
  tableMaxCols: 14,
  maxChars: 12000,
});
console.log(reviewCheck.ndjson);
const errors = await workbook.inspect({
  kind: "match",
  searchTerm: "#REF!|#DIV/0!|#VALUE!|#NAME\\?|#N/A|#NUM!|#NULL!|#SPILL!|#CALC!",
  options: { useRegex: true, maxResults: 300 },
  summary: "final formula error scan",
});
console.log(errors.ndjson);

await fs.mkdir(previewDir, { recursive: true });
const reviewPreview = await workbook.render({ sheetName: "OCR Review", range: `A1:N${5 + reviewRows.length}`, scale: 1, format: "png" });
await fs.writeFile(path.join(previewDir, "ocr_review.png"), new Uint8Array(await reviewPreview.arrayBuffer()));
const auditPreview = await workbook.render({ sheetName: "Block Audit", range: "A1:I24", scale: 1, format: "png" });
await fs.writeFile(path.join(previewDir, "block_audit.png"), new Uint8Array(await auditPreview.arrayBuffer()));

await fs.mkdir(path.dirname(outputPath), { recursive: true });
const output = await SpreadsheetFile.exportXlsx(workbook);
await output.save(outputPath);
const saved = await FileBlob.load(outputPath);
const reopened = await SpreadsheetFile.importXlsx(saved);
const reopenedCheck = await reopened.inspect({
  kind: "table",
  range: `OCR Review!A1:N${5 + reviewRows.length}`,
  include: "values,formulas",
  tableMaxRows: 8,
  tableMaxCols: 14,
  maxChars: 5000,
});
console.log(reopenedCheck.ndjson);
console.log(outputPath);
