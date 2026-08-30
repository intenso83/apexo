import fs from "node:fs/promises";
import path from "node:path";
import { FileBlob, SpreadsheetFile } from "@oai/artifact-tool";

const workbookPath = path.join(
  process.cwd(),
  "outputs",
  "therapy-catalogue-audit-20260829",
  "Apexo_DentalWin_Therapy_Catalogue_Audit_Source_Colours_2026-08-30.xlsx",
);
const input = await FileBlob.load(workbookPath);
const workbook = await SpreadsheetFile.importXlsx(input);

const renderDir = path.join(process.cwd(), "tmp", "catalogue-audit-edit", "rendered-before");
await fs.mkdir(renderDir, { recursive: true });
const groupsPreview = await workbook.render({ sheetName: "Groups", autoCrop: "all", scale: 0.8, format: "png" });
await fs.writeFile(
  path.join(renderDir, "Groups_before.png"),
  new Uint8Array(await groupsPreview.arrayBuffer()),
);

for (const [sheetId, range] of [
  ["Summary", "A1:J14"],
  ["Catalogue Audit", "A1:V12"],
  ["Groups", "A1:J20"],
  ["Method", "A1:C15"],
]) {
  const result = await workbook.inspect({ kind: "region", sheetId, range, maxChars: 10000 });
  console.log(`${sheetId.toUpperCase()}\n${result.ndjson}`);
}

for (const searchTerm of ["#REF!", "#DIV/0!", "#VALUE!", "#NAME?", "#N/A"]) {
  const result = await workbook.inspect({
    kind: "match",
    searchTerm,
    maxChars: 3000,
    options: { maxResults: 50 },
  });
  console.log(`ERROR_SCAN ${searchTerm}\n${result.ndjson}`);
}
