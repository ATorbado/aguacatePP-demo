package com.atorbado.vialidadinvernal.excel;

import static org.junit.jupiter.api.Assertions.assertArrayEquals;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;

import com.atorbado.vialidadinvernal.model.RoadOpening;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.LocalDateTime;
import org.apache.poi.ss.usermodel.CellType;
import org.apache.poi.ss.usermodel.Row;
import org.apache.poi.ss.usermodel.Sheet;
import org.apache.poi.ss.usermodel.Workbook;
import org.apache.poi.xssf.usermodel.XSSFWorkbook;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

class OpeningWorkbookReaderTest {
    @TempDir
    Path temporaryDirectory;

    @Test
    void readsSyntheticOpeningWithoutChangingTheFile() throws IOException {
        Path workbookPath = createValidWorkbook();
        byte[] before = Files.readAllBytes(workbookPath);

        RoadOpening result = OpeningWorkbookReader.read(workbookPath, "MODEL");

        assertEquals("R-1", result.road());
        assertEquals(LocalDateTime.of(2030, 2, 3, 4, 5), result.startedAt());
        assertEquals("001+000", result.startPk());
        assertEquals("002+000", result.endPk());
        assertEquals("Synthetic section", result.section());
        assertEquals("Synthetic network", result.roadType());
        assertArrayEquals(before, Files.readAllBytes(workbookPath));
    }

    @Test
    void rejectsMissingAndDuplicateMarkers() throws IOException {
        Path missing = createValidWorkbook();
        edit(missing, workbook -> workbook.getSheet("MODEL").getRow(15).removeCell(
                workbook.getSheet("MODEL").getRow(15).getCell(0)));
        assertThrows(IllegalArgumentException.class, () -> OpeningWorkbookReader.read(missing, "MODEL"));

        Path duplicate = temporaryDirectory.resolve("duplicate.xlsx");
        createValidWorkbookAt(duplicate);
        edit(duplicate, workbook -> {
            Row row = workbook.getSheet("MODEL").createRow(22);
            row.createCell(0).setCellValue("TRAMO:");
            row.createCell(1).setCellValue("Other section");
        });
        assertThrows(IllegalArgumentException.class, () -> OpeningWorkbookReader.read(duplicate, "MODEL"));
    }

    @Test
    void rejectsInvalidDateAndNonTextValues() throws IOException {
        Path invalidDate = createValidWorkbook();
        edit(invalidDate, workbook -> workbook.getSheet("MODEL").getRow(17).getCell(3)
                .setCellValue("99:99 (31/02/2030)"));
        assertThrows(IllegalArgumentException.class, () -> OpeningWorkbookReader.read(invalidDate, "MODEL"));

        Path numeric = temporaryDirectory.resolve("numeric.xlsx");
        createValidWorkbookAt(numeric);
        edit(numeric, workbook -> workbook.getSheet("MODEL").getRow(18).getCell(3)
                .setCellValue(1000));
        try (InputStream input = Files.newInputStream(numeric);
             Workbook workbook = new XSSFWorkbook(input)) {
            assertEquals(CellType.NUMERIC, workbook.getSheet("MODEL").getRow(18).getCell(3).getCellType());
        }
        assertThrows(IllegalArgumentException.class, () -> OpeningWorkbookReader.read(numeric, "MODEL"));
    }

    @Test
    void rejectsMissingSheetAndInvalidArguments() throws IOException {
        Path workbookPath = createValidWorkbook();
        assertThrows(IllegalArgumentException.class, () -> OpeningWorkbookReader.read(workbookPath, "UNKNOWN"));
        assertThrows(IllegalArgumentException.class, () -> OpeningWorkbookReader.read(workbookPath, " "));
        assertThrows(IllegalArgumentException.class, () -> OpeningWorkbookReader.read(null, "MODEL"));
        assertThrows(IllegalArgumentException.class, () -> OpeningWorkbookReader.read(
                temporaryDirectory.resolve("absent.xlsx"), "MODEL"));
    }

    private Path createValidWorkbook() throws IOException {
        Path path = temporaryDirectory.resolve("valid.xlsx");
        createValidWorkbookAt(path);
        return path;
    }

    private void createValidWorkbookAt(Path path) throws IOException {
        try (Workbook workbook = new XSSFWorkbook()) {
            Sheet sheet = workbook.createSheet("MODEL");
            marker(sheet, 15, "  tramo:  ", 1, "Synthetic section");
            marker(sheet, 16, "carretera:", 3, "R-1");
            marker(sheet, 17, "Hora Inicio:", 3, "04:05 (03/02/2030)");
            marker(sheet, 18, "p.k. inicial:", 3, "001+000");
            marker(sheet, 19, "P.K. FINAL:", 1, "002+000");
            marker(sheet, 20, "tipo carretera:", 3, "Synthetic network");
            workbook.createSheet("Metadata").createRow(0).createCell(0).setCellFormula("1+1");
            try (OutputStream output = Files.newOutputStream(path)) {
                workbook.write(output);
            }
        }
    }

    private void marker(Sheet sheet, int rowIndex, String marker, int offset, String value) {
        Row row = sheet.createRow(rowIndex);
        row.createCell(0).setCellValue(marker);
        row.createCell(offset).setCellValue(value);
    }

    private void edit(Path path, WorkbookEdit edit) throws IOException {
        try (InputStream input = Files.newInputStream(path);
             Workbook workbook = new XSSFWorkbook(input)) {
            edit.apply(workbook);
            try (OutputStream output = Files.newOutputStream(path)) {
                workbook.write(output);
            }
        }
    }

    @FunctionalInterface
    private interface WorkbookEdit {
        void apply(Workbook workbook);
    }
}
