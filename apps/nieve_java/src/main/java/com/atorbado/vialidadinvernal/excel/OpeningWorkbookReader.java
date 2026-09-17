package com.atorbado.vialidadinvernal.excel;

import com.atorbado.vialidadinvernal.model.RoadOpening;
import java.io.IOException;
import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.time.format.DateTimeParseException;
import java.time.format.ResolverStyle;
import java.util.EnumMap;
import java.util.Locale;
import java.util.Map;
import org.apache.poi.ss.usermodel.Cell;
import org.apache.poi.ss.usermodel.CellType;
import org.apache.poi.ss.usermodel.Row;
import org.apache.poi.ss.usermodel.Sheet;
import org.apache.poi.ss.usermodel.Workbook;
import org.apache.poi.xssf.usermodel.XSSFWorkbook;

public final class OpeningWorkbookReader {
    private static final int FIRST_TEMPLATE_ROW = 15;
    private static final int LAST_TEMPLATE_ROW = 26;
    private static final DateTimeFormatter DATE_TIME_FORMAT = DateTimeFormatter
            .ofPattern("HH:mm (dd/MM/uuuu)", Locale.ROOT)
            .withResolverStyle(ResolverStyle.STRICT);

    private OpeningWorkbookReader() {
    }

    public static RoadOpening read(Path workbookPath, String sheetName) throws IOException {
        if (workbookPath == null) {
            throw new IllegalArgumentException("workbookPath");
        }
        if (sheetName == null || sheetName.isBlank()) {
            throw new IllegalArgumentException("sheetName");
        }
        if (!Files.isRegularFile(workbookPath)) {
            throw new IllegalArgumentException("workbookPath");
        }

        try (InputStream input = Files.newInputStream(workbookPath);
             Workbook workbook = new XSSFWorkbook(input)) {
            Sheet sheet = workbook.getSheet(sheetName);
            if (sheet == null) {
                throw new IllegalArgumentException("sheetName");
            }
            Map<Field, String> values = readFields(sheet);
            return new RoadOpening(
                    values.get(Field.ROAD),
                    parseStartedAt(values.get(Field.STARTED_AT)),
                    values.get(Field.START_PK),
                    values.get(Field.END_PK),
                    values.get(Field.SECTION),
                    values.get(Field.ROAD_TYPE));
        }
    }

    private static Map<Field, String> readFields(Sheet sheet) {
        Map<Field, String> values = new EnumMap<>(Field.class);
        for (int rowIndex = FIRST_TEMPLATE_ROW; rowIndex <= LAST_TEMPLATE_ROW; rowIndex++) {
            Row row = sheet.getRow(rowIndex);
            if (row == null) {
                continue;
            }
            int cellCount = Math.max(row.getLastCellNum(), 0);
            for (int column = 0; column < cellCount; column++) {
                Cell markerCell = row.getCell(column);
                if (markerCell == null || markerCell.getCellType() != CellType.STRING) {
                    continue;
                }
                Field field = Field.fromMarker(markerCell.getStringCellValue());
                if (field == null) {
                    continue;
                }
                if (values.containsKey(field)) {
                    throw new IllegalArgumentException(field.errorName + " duplicado");
                }
                values.put(field, readText(row, column + field.valueOffset, field.errorName));
            }
        }
        for (Field field : Field.values()) {
            if (!values.containsKey(field)) {
                throw new IllegalArgumentException(field.errorName + " ausente");
            }
        }
        return values;
    }

    private static String readText(Row row, int column, String fieldName) {
        Cell valueCell = row.getCell(column);
        if (valueCell == null || valueCell.getCellType() != CellType.STRING) {
            throw new IllegalArgumentException(fieldName + " no textual");
        }
        String value = valueCell.getStringCellValue().trim();
        if (value.isBlank()) {
            throw new IllegalArgumentException(fieldName + " vacio");
        }
        return value;
    }

    private static LocalDateTime parseStartedAt(String value) {
        try {
            return LocalDateTime.parse(value, DATE_TIME_FORMAT);
        } catch (DateTimeParseException error) {
            throw new IllegalArgumentException("startedAt invalido", error);
        }
    }

    private enum Field {
        SECTION("TRAMO:", 1, "section"),
        ROAD("CARRETERA:", 3, "road"),
        STARTED_AT("HORA INICIO:", 3, "startedAt"),
        START_PK("P.K. INICIAL:", 3, "startPk"),
        END_PK("P.K. FINAL:", 1, "endPk"),
        ROAD_TYPE("TIPO CARRETERA:", 3, "roadType");

        private final String marker;
        private final int valueOffset;
        private final String errorName;

        Field(String marker, int valueOffset, String errorName) {
            this.marker = marker;
            this.valueOffset = valueOffset;
            this.errorName = errorName;
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
