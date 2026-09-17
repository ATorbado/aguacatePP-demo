package com.atorbado.vialidadinvernal.excel;

import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardOpenOption;
import java.util.List;
import java.util.Objects;
import org.apache.poi.ss.usermodel.Cell;
import org.apache.poi.ss.usermodel.Row;
import org.apache.poi.ss.usermodel.Sheet;
import org.apache.poi.ss.usermodel.Workbook;
import org.apache.poi.xssf.usermodel.XSSFWorkbook;

public final class CommunicationsWorkbookWriter {
    private static final int MAX_STATUSES = 10;
    private static final int HEADER_ROW = 0;
    private static final int HEADER_COLUMN = 2;
    private static final int FIRST_STATUS_ROW = 4;
    private static final int FIRST_STATUS_COLUMN = 3;
    private static final int LAST_STATUS_COLUMN = 5;

    private CommunicationsWorkbookWriter() {
    }

    public static void write(
            Path template,
            Path destination,
            String sheetName,
            String header,
            List<String> statuses) throws IOException {
        Objects.requireNonNull(template, "template");
        Objects.requireNonNull(destination, "destination");
        Objects.requireNonNull(sheetName, "sheetName");
        Objects.requireNonNull(header, "header");
        Objects.requireNonNull(statuses, "statuses");

        if (sheetName.isBlank()) {
            throw new IllegalArgumentException("El nombre de la hoja no puede estar vacio");
        }
        if (!Files.isRegularFile(template)) {
            throw new IllegalArgumentException("La plantilla no existe o no es un archivo");
        }
        if (template.toAbsolutePath().normalize().equals(destination.toAbsolutePath().normalize())) {
            throw new IllegalArgumentException("La salida debe ser distinta de la plantilla");
        }
        if (statuses.size() > MAX_STATUSES) {
            throw new IllegalArgumentException("Solo se permiten hasta diez estados");
        }
        if (statuses.stream().anyMatch(Objects::isNull)) {
            throw new IllegalArgumentException("Los estados no pueden contener valores nulos");
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

            cell(sheet, HEADER_ROW, HEADER_COLUMN).setCellValue(header);
            for (int index = 0; index < statuses.size(); index++) {
                String value = "---".equals(statuses.get(index)) ? "" : statuses.get(index);
                int rowIndex = FIRST_STATUS_ROW + index;
                for (int column = FIRST_STATUS_COLUMN; column <= LAST_STATUS_COLUMN; column++) {
                    cell(sheet, rowIndex, column).setCellValue(value);
                }
            }

            try (OutputStream output = Files.newOutputStream(
                    destination,
                    StandardOpenOption.CREATE_NEW,
                    StandardOpenOption.WRITE)) {
                workbook.write(output);
            }
        }
    }

    private static Cell cell(Sheet sheet, int rowIndex, int columnIndex) {
        Row row = sheet.getRow(rowIndex);
        if (row == null) {
            row = sheet.createRow(rowIndex);
        }
        return row.getCell(columnIndex, Row.MissingCellPolicy.CREATE_NULL_AS_BLANK);
    }
}
