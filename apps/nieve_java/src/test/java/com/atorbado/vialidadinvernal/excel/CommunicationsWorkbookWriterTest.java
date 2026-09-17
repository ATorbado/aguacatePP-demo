package com.atorbado.vialidadinvernal.excel;

import static org.junit.jupiter.api.Assertions.assertArrayEquals;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.List;
import org.apache.poi.ss.usermodel.CellStyle;
import org.apache.poi.ss.usermodel.Font;
import org.apache.poi.ss.usermodel.Sheet;
import org.apache.poi.ss.usermodel.Workbook;
import org.apache.poi.xssf.usermodel.XSSFWorkbook;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

class CommunicationsWorkbookWriterTest {
    @TempDir
    Path temporaryDirectory;

    @Test
    void writesExpectedCellsAndPreservesTheCompleteTemplate() throws IOException {
        Path template = createTemplate();
        byte[] originalTemplate = Files.readAllBytes(template);
        Path destination = temporaryDirectory.resolve("out").resolve("communication.xlsx");

        CommunicationsWorkbookWriter.write(
                template,
                destination,
                "V.I.",
                "Synthetic header",
                List.of("Closed", "---"));

        assertArrayEquals(originalTemplate, Files.readAllBytes(template));
        assertTrue(Files.isRegularFile(destination));

        try (InputStream input = Files.newInputStream(destination);
             Workbook workbook = new XSSFWorkbook(input)) {
            Sheet communication = workbook.getSheet("V.I.");
            assertEquals("Synthetic header", communication.getRow(0).getCell(2).getStringCellValue());
            for (int column = 3; column <= 5; column++) {
                assertEquals("Closed", communication.getRow(4).getCell(column).getStringCellValue());
                assertEquals("", communication.getRow(5).getCell(column).getStringCellValue());
            }
            assertEquals(2, workbook.getNumberOfSheets());
            assertEquals("1+1", workbook.getSheet("Metadata").getRow(0).getCell(0).getCellFormula());
            assertTrue(communication.getRow(0).getCell(0).getCellStyle().getFontIndex() > 0);
        }
    }

    @Test
    void rejectsMoreThanTenStatuses() throws IOException {
        Path template = createTemplate();
        List<String> statuses = List.of("1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11");

        assertThrows(IllegalArgumentException.class, () -> CommunicationsWorkbookWriter.write(
                template,
                temporaryDirectory.resolve("too-many.xlsx"),
                "V.I.",
                "Header",
                statuses));
    }

    @Test
    void rejectsAMissingSheetWithoutCreatingOutput() throws IOException {
        Path template = createTemplate();
        Path destination = temporaryDirectory.resolve("missing-sheet.xlsx");

        assertThrows(IllegalArgumentException.class, () -> CommunicationsWorkbookWriter.write(
                template,
                destination,
                "Unknown",
                "Header",
                List.of()));
        assertTrue(Files.notExists(destination));
    }

    @Test
    void neverOverwritesTheTemplateOrAnExistingOutput() throws IOException {
        Path template = createTemplate();
        Path existing = temporaryDirectory.resolve("existing.xlsx");
        Files.writeString(existing, "keep");

        assertThrows(IllegalArgumentException.class, () -> CommunicationsWorkbookWriter.write(
                template,
                template,
                "V.I.",
                "Header",
                List.of()));
        assertThrows(IOException.class, () -> CommunicationsWorkbookWriter.write(
                template,
                existing,
                "V.I.",
                "Header",
                List.of()));
        assertEquals("keep", Files.readString(existing));
    }

    private Path createTemplate() throws IOException {
        Path template = temporaryDirectory.resolve("template.xlsx");
        try (Workbook workbook = new XSSFWorkbook()) {
            Sheet communication = workbook.createSheet("V.I.");
            Font font = workbook.createFont();
            font.setBold(true);
            CellStyle style = workbook.createCellStyle();
            style.setFont(font);
            communication.createRow(0).createCell(0).setCellValue("Template marker");
            communication.getRow(0).getCell(0).setCellStyle(style);
            workbook.createSheet("Metadata").createRow(0).createCell(0).setCellFormula("1+1");
            try (OutputStream output = Files.newOutputStream(template)) {
                workbook.write(output);
            }
        }
        return template;
    }
}
