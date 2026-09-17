package com.atorbado.vialidadinvernal.excel;

import com.atorbado.vialidadinvernal.model.RoadRestriction;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardOpenOption;
import java.time.format.DateTimeFormatter;
import java.util.Locale;
import java.util.Objects;
import org.apache.poi.ss.usermodel.Cell;
import org.apache.poi.ss.usermodel.CellType;
import org.apache.poi.ss.usermodel.Row;
import org.apache.poi.ss.usermodel.Sheet;
import org.apache.poi.ss.usermodel.Workbook;
import org.apache.poi.xssf.usermodel.XSSFWorkbook;

public final class OpeningWorkbookWriter {
    private static final int FIRST_TEMPLATE_ROW = 15;
    private static final int LAST_TEMPLATE_ROW = 26;
    private static final DateTimeFormatter DATE_TIME_FORMAT =
            DateTimeFormatter.ofPattern("HH:mm (dd/MM/yyyy)", Locale.ROOT);

    private OpeningWorkbookWriter() {
    }

    public static void write(
            Path template,
            Path destination,
            String sheetName,
            RoadRestriction data) throws IOException {
        Objects.requireNonNull(template, "template");
        Objects.requireNonNull(destination, "destination");
        Objects.requireNonNull(sheetName, "sheetName");
        Objects.requireNonNull(data, "data");

        if (sheetName.isBlank()) {
            throw new IllegalArgumentException("El nombre de la hoja no puede estar vacio");
        }
        if (!Files.isRegularFile(template)) {
            throw new IllegalArgumentException("La plantilla no existe o no es un archivo");
        }
        if (template.toAbsolutePath().normalize().equals(destination.toAbsolutePath().normalize())) {
            throw new IllegalArgumentException("La salida debe ser distinta de la plantilla");
        }

        Path parent = destination.toAbsolutePath().normalize().getParent();
        if (parent != null) {
            Files.createDirectories(parent);
        }

        try (InputStream input = Files.newInputStream(template);
             Workbook workbook = new XSSFWorkbook(input)) {
            Sheet sheet = workbook.getSheet(sheetName);
            if (sheet == null) {
                throw new IllegalArgumentException("La hoja solicitada no existe en la plantilla");
            }

            fillTemplate(sheet, data);
            try (OutputStream output = Files.newOutputStream(
                    destination,
                    StandardOpenOption.CREATE_NEW,
                    StandardOpenOption.WRITE)) {
                workbook.write(output);
            }
        }
    }

    private static void fillTemplate(Sheet sheet, RoadRestriction data) {
        for (int rowIndex = FIRST_TEMPLATE_ROW; rowIndex <= LAST_TEMPLATE_ROW; rowIndex++) {
            Row row = sheet.getRow(rowIndex);
            if (row == null) {
                continue;
            }
            int cellsBeforeWriting = Math.max(row.getLastCellNum(), 0);
            for (int column = 0; column < cellsBeforeWriting; column++) {
                Cell markerCell = row.getCell(column);
                if (markerCell == null || markerCell.getCellType() != CellType.STRING) {
                    continue;
                }
                String marker = markerCell.getStringCellValue().trim().toUpperCase(Locale.ROOT);
                switch (marker) {
                    case "TRAMO:" -> set(row, column + 1, data.section());
                    case "CARRETERA:" -> set(row, column + 3, data.road());
                    case "HORA INICIO:" -> set(
                            row,
                            column + 3,
                            data.startedAt().format(DATE_TIME_FORMAT));
                    case "P.K. INICIAL:" -> set(row, column + 3, data.startPk());
                    case "P.K. FINAL:" -> set(row, column + 1, data.endPk());
                    case "TIPO CARRETERA:" -> set(row, column + 3, data.roadType());
                    case "CORTE DE CALZADA POR NIEVE" -> set(
                            row,
                            column,
                            data.restriction());
                    default -> {
                    }
                }
            }
        }
    }

    private static void set(Row row, int column, String value) {
        row.getCell(column, Row.MissingCellPolicy.CREATE_NULL_AS_BLANK)
                .setCellValue(value.toUpperCase(Locale.ROOT));
    }
}
