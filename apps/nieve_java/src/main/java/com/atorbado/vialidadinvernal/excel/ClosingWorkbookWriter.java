package com.atorbado.vialidadinvernal.excel;

import com.atorbado.vialidadinvernal.model.RoadClosure;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardOpenOption;
import java.time.format.DateTimeFormatter;
import java.util.EnumMap;
import java.util.Locale;
import java.util.Map;
import org.apache.poi.ss.usermodel.Cell;
import org.apache.poi.ss.usermodel.CellType;
import org.apache.poi.ss.usermodel.Row;
import org.apache.poi.ss.usermodel.Sheet;
import org.apache.poi.ss.usermodel.Workbook;
import org.apache.poi.xssf.usermodel.XSSFWorkbook;

public final class ClosingWorkbookWriter {
    private static final int FIRST_TEMPLATE_ROW = 15;
    private static final int LAST_TEMPLATE_ROW = 26;
    private static final DateTimeFormatter DATE_TIME_FORMAT =
            DateTimeFormatter.ofPattern("HH:mm (dd/MM/yyyy)", Locale.ROOT);

    private ClosingWorkbookWriter() {
    }

    public static void write(
            Path template,
            Path destination,
            String sheetName,
            RoadClosure data) throws IOException {
        if (template == null) {
            throw new IllegalArgumentException("template");
        }
        if (destination == null) {
            throw new IllegalArgumentException("destination");
        }
        if (sheetName == null || sheetName.isBlank()) {
            throw new IllegalArgumentException("El nombre de la hoja no puede estar vacio");
        }
        if (data == null) {
            throw new IllegalArgumentException("data");
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

    private static void fillTemplate(Sheet sheet, RoadClosure data) {
        Map<Field, Cell> targets = new EnumMap<>(Field.class);
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
                Field field = Field.fromMarker(markerCell.getStringCellValue());
                if (field == null) {
                    continue;
                }
                if (targets.containsKey(field)) {
                    throw new IllegalArgumentException(field.errorName + " duplicado");
                }
                targets.put(
                        field,
                        row.getCell(
                                column + field.valueOffset,
                                Row.MissingCellPolicy.CREATE_NULL_AS_BLANK));
            }
        }
        for (Field field : Field.values()) {
            Cell target = targets.get(field);
            if (target == null) {
                throw new IllegalArgumentException(field.errorName + " ausente");
            }
            set(target, field.value(data));
        }
    }

    private static void set(Cell cell, String value) {
        cell.setCellValue(value.toUpperCase(Locale.ROOT));
    }

    private enum Field {
        CLOSING_NOTE("CORTADO POR NIEVE", 0, "closingNote"),
        SECTION("TRAMO:", 1, "section"),
        ROAD("CARRETERA:", 3, "road"),
        STARTED_AT("HORA INICIO:", 3, "startedAt"),
        START_PK("P.K. INICIAL:", 3, "startPk"),
        END_PK("P.K. FINAL:", 1, "endPk"),
        ROAD_TYPE("TIPO CARRETERA:", 3, "roadType"),
        ENDED_AT("HORA FINAL:", 2, "endedAt");

        private final String marker;
        private final int valueOffset;
        private final String errorName;

        Field(String marker, int valueOffset, String errorName) {
            this.marker = marker;
            this.valueOffset = valueOffset;
            this.errorName = errorName;
        }

        private String value(RoadClosure data) {
            return switch (this) {
                case CLOSING_NOTE -> data.closingNote();
                case SECTION -> data.opening().section();
                case ROAD -> data.opening().road();
                case STARTED_AT -> data.opening().startedAt().format(DATE_TIME_FORMAT);
                case START_PK -> data.opening().startPk();
                case END_PK -> data.opening().endPk();
                case ROAD_TYPE -> data.opening().roadType();
                case ENDED_AT -> data.endedAt().format(DATE_TIME_FORMAT);
            };
        }

        private static Field fromMarker(String value) {
            String normalized = value.trim().toUpperCase(Locale.ROOT);
            for (Field field : values()) {
                if (field.marker.equals(normalized)) {
                    return field;
                }
            }
            return null;
        }
    }
}
