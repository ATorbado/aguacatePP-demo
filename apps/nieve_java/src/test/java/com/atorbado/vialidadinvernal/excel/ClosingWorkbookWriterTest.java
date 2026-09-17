package com.atorbado.vialidadinvernal.excel;

import static org.junit.jupiter.api.Assertions.assertArrayEquals;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import com.atorbado.vialidadinvernal.model.RoadClosure;
import com.atorbado.vialidadinvernal.model.RoadOpening;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.LocalDateTime;
import org.apache.poi.ss.usermodel.CellStyle;
import org.apache.poi.ss.usermodel.Font;
import org.apache.poi.ss.usermodel.Row;
import org.apache.poi.ss.usermodel.Sheet;
import org.apache.poi.ss.usermodel.Workbook;
import org.apache.poi.xssf.usermodel.XSSFWorkbook;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

class ClosingWorkbookWriterTest {
    @TempDir
    Path temporaryDirectory;

    @Test
    void fillsEveryMarkerAndPreservesTheCompleteTemplate() throws IOException {
        Path template = createTemplate();
        byte[] templateBytes = Files.readAllBytes(template);
        Path destination = temporaryDirectory.resolve("generated").resolve("closing.xlsx");

        ClosingWorkbookWriter.write(template, destination, "MODEL", closure());

        assertArrayEquals(templateBytes, Files.readAllBytes(template));
        assertTrue(Files.isRegularFile(destination));
        try (InputStream input = Files.newInputStream(destination);
             Workbook workbook = new XSSFWorkbook(input)) {
            Sheet sheet = workbook.getSheet("MODEL");
            assertEquals("SYNTHETIC NOTE", text(sheet, 15, 0));
            assertEquals("SYNTHETIC SECTION", text(sheet, 16, 1));
            assertEquals("R-1", text(sheet, 17, 3));
            assertEquals("04:05 (03/02/2030)", text(sheet, 18, 3));
            assertEquals("001+000", text(sheet, 19, 3));
            assertEquals("002+000", text(sheet, 20, 1));
            assertEquals("SYNTHETIC NETWORK", text(sheet, 21, 3));
            assertEquals("06:07 (03/02/2030)", text(sheet, 22, 2));
            assertEquals(2, workbook.getNumberOfSheets());
            assertEquals("1+1", workbook.getSheet("Metadata").getRow(0).getCell(0).getCellFormula());
            assertTrue(sheet.getRow(16).getCell(0).getCellStyle().getFontIndex() > 0);
        }
    }

    @Test
    void rejectsMissingAndDuplicateMarkersWithoutCreatingOutput() throws IOException {
        Path missing = createTemplateAt(temporaryDirectory.resolve("missing.xlsx"), false);
        Path missingOutput = temporaryDirectory.resolve("missing-output.xlsx");
        assertThrows(IllegalArgumentException.class, () -> ClosingWorkbookWriter.write(
                missing, missingOutput, "MODEL", closure()));
        assertTrue(Files.notExists(missingOutput));

        Path duplicate = createTemplateAt(temporaryDirectory.resolve("duplicate.xlsx"), true);
        Path duplicateOutput = temporaryDirectory.resolve("duplicate-output.xlsx");
        assertThrows(IllegalArgumentException.class, () -> ClosingWorkbookWriter.write(
                duplicate, duplicateOutput, "MODEL", closure()));
        assertTrue(Files.notExists(duplicateOutput));
    }

    @Test
    void rejectsMissingSheetExistingOutputAndTemplateAsOutput() throws IOException {
        Path template = createTemplate();
        Path absentSheetOutput = temporaryDirectory.resolve("absent-sheet.xlsx");
        assertThrows(IllegalArgumentException.class, () -> ClosingWorkbookWriter.write(
                template, absentSheetOutput, "UNKNOWN", closure()));

        Path existing = temporaryDirectory.resolve("existing.xlsx");
        Files.writeString(existing, "keep");
        assertThrows(IOException.class, () -> ClosingWorkbookWriter.write(
                template, existing, "MODEL", closure()));
        assertEquals("keep", Files.readString(existing));

        assertThrows(IllegalArgumentException.class, () -> ClosingWorkbookWriter.write(
                template, template, "MODEL", closure()));
    }

    private Path createTemplate() throws IOException {
        return createTemplateAt(temporaryDirectory.resolve("template.xlsx"), false, true);
    }

    private Path createTemplateAt(Path path, boolean duplicate) throws IOException {
        return createTemplateAt(path, duplicate, false);
    }

    private Path createTemplateAt(Path path, boolean duplicate, boolean complete) throws IOException {
        try (Workbook workbook = new XSSFWorkbook()) {
            Sheet sheet = workbook.createSheet("MODEL");
            Font font = workbook.createFont();
            font.setBold(true);
            CellStyle style = workbook.createCellStyle();
            style.setFont(font);
            marker(sheet, 15, "cortado por nieve");
            marker(sheet, 16, " TRAMO: ");
            sheet.getRow(16).getCell(0).setCellStyle(style);
            marker(sheet, 17, "carretera:");
            marker(sheet, 18, "HORA INICIO:");
            marker(sheet, 19, "p.k. inicial:");
            marker(sheet, 20, "P.K. FINAL:");
            marker(sheet, 21, "tipo carretera:");
            if (complete) {
                marker(sheet, 22, "HORA FINAL:");
            }
            if (duplicate) {
                marker(sheet, 22, "TRAMO:");
            }
            workbook.createSheet("Metadata").createRow(0).createCell(0).setCellFormula("1+1");
            try (OutputStream output = Files.newOutputStream(path)) {
                workbook.write(output);
            }
        }
        return path;
    }

    private void marker(Sheet sheet, int rowIndex, String value) {
        sheet.createRow(rowIndex).createCell(0).setCellValue(value);
    }

    private RoadClosure closure() {
        RoadOpening opening = new RoadOpening(
                "r-1",
                LocalDateTime.of(2030, 2, 3, 4, 5),
                "001+000",
                "002+000",
                "synthetic section",
                "synthetic network");
        return new RoadClosure(
                opening,
                LocalDateTime.of(2030, 2, 3, 6, 7),
                "synthetic note");
    }

    private String text(Sheet sheet, int row, int column) {
        return sheet.getRow(row).getCell(column).getStringCellValue();
    }
}
