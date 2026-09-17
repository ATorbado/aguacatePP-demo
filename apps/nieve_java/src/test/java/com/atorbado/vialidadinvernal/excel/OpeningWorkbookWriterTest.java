package com.atorbado.vialidadinvernal.excel;

import static org.junit.jupiter.api.Assertions.assertArrayEquals;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import com.atorbado.vialidadinvernal.model.RoadRestriction;
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

class OpeningWorkbookWriterTest {
    @TempDir
    Path temporaryDirectory;

    @Test
    void fillsEveryMarkerAndPreservesTheWorkbook() throws IOException {
        Path template = createTemplate();
        byte[] originalTemplate = Files.readAllBytes(template);
        Path destination = temporaryDirectory.resolve("generated").resolve("opening.xlsx");
        RoadRestriction restriction = new RoadRestriction(
                "r-1",
                LocalDateTime.of(2030, 2, 3, 4, 5),
                "synthetic closure",
                "001+000",
                "002+000",
                "synthetic section",
                "synthetic network");

        OpeningWorkbookWriter.write(template, destination, "MODEL", restriction);

        assertArrayEquals(originalTemplate, Files.readAllBytes(template));
        assertTrue(Files.isRegularFile(destination));
        try (InputStream input = Files.newInputStream(destination);
             Workbook workbook = new XSSFWorkbook(input)) {
            Sheet sheet = workbook.getSheet("MODEL");
            assertEquals("SYNTHETIC SECTION", value(sheet, 15, 1));
            assertEquals("R-1", value(sheet, 16, 3));
            assertEquals("04:05 (03/02/2030)", value(sheet, 17, 3));
            assertEquals("001+000", value(sheet, 18, 3));
            assertEquals("002+000", value(sheet, 19, 1));
            assertEquals("SYNTHETIC NETWORK", value(sheet, 20, 3));
            assertEquals("SYNTHETIC CLOSURE", value(sheet, 21, 0));
            assertEquals("TRAMO:", value(sheet, 14, 0));
            assertTrue(sheet.getRow(15).getCell(0).getCellStyle().getFontIndex() > 0);
            assertEquals(2, workbook.getNumberOfSheets());
            assertEquals("1+1", workbook.getSheet("Metadata").getRow(0).getCell(0).getCellFormula());
        }
    }

    @Test
    void rejectsMissingSheetAndExistingOutput() throws IOException {
        Path template = createTemplate();
        Path missingSheetOutput = temporaryDirectory.resolve("missing.xlsx");
        RoadRestriction restriction = restriction();

        assertThrows(IllegalArgumentException.class, () -> OpeningWorkbookWriter.write(
                template, missingSheetOutput, "UNKNOWN", restriction));
        assertTrue(Files.notExists(missingSheetOutput));

        Path existing = temporaryDirectory.resolve("existing.xlsx");
        Files.writeString(existing, "keep");
        assertThrows(IOException.class, () -> OpeningWorkbookWriter.write(
                template, existing, "MODEL", restriction));
        assertEquals("keep", Files.readString(existing));
    }

    @Test
    void rejectsUsingTheTemplateAsOutput() throws IOException {
        Path template = createTemplate();
        assertThrows(IllegalArgumentException.class, () -> OpeningWorkbookWriter.write(
                template, template, "MODEL", restriction()));
    }

    private Path createTemplate() throws IOException {
        Path template = temporaryDirectory.resolve("template.xlsx");
        try (Workbook workbook = new XSSFWorkbook()) {
            Sheet sheet = workbook.createSheet("MODEL");
            Font font = workbook.createFont();
            font.setBold(true);
            CellStyle style = workbook.createCellStyle();
            style.setFont(font);
            String[] markers = {
                "TRAMO:",
                "CARRETERA:",
                "HORA INICIO:",
                "P.K. INICIAL:",
                "P.K. FINAL:",
                "TIPO CARRETERA:",
                "CORTE DE CALZADA POR NIEVE"
            };
            sheet.createRow(14).createCell(0).setCellValue("TRAMO:");
            for (int index = 0; index < markers.length; index++) {
                Row row = sheet.createRow(15 + index);
                row.createCell(0).setCellValue(markers[index]);
            }
            sheet.getRow(15).getCell(0).setCellStyle(style);
            workbook.createSheet("Metadata").createRow(0).createCell(0).setCellFormula("1+1");
            try (OutputStream output = Files.newOutputStream(template)) {
                workbook.write(output);
            }
        }
        return template;
    }

    private RoadRestriction restriction() {
        return new RoadRestriction(
                "r-1",
                LocalDateTime.of(2030, 2, 3, 4, 5),
                "synthetic closure",
                "001+000",
                "002+000",
                "synthetic section",
                "synthetic network");
    }

    private String value(Sheet sheet, int row, int column) {
        return sheet.getRow(row).getCell(column).getStringCellValue();
    }
}
