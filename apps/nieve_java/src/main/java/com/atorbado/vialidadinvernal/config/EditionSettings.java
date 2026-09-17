package com.atorbado.vialidadinvernal.config;

import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.nio.charset.StandardCharsets;
import java.util.Objects;
import java.util.Properties;

public record EditionSettings(
        AppEdition edition,
        String displayName,
        boolean networkEnabled) {

    public EditionSettings {
        Objects.requireNonNull(edition, "edition");
        if (displayName == null || displayName.isBlank()) {
            throw new IllegalArgumentException("Falta el nombre de la edición");
        }
        if (edition != AppEdition.DEMO) {
            throw new IllegalArgumentException("Solo se permite la edición DEMO para demos públicas");
        }
        if (networkEnabled) {
            throw new IllegalArgumentException("La demostración no puede habilitar la red");
        }
    }

    public static EditionSettings loadBundled() {
        try (InputStream input = EditionSettings.class
                .getResourceAsStream("/edition.properties")) {
            if (input == null) {
                throw new IllegalStateException("Falta edition.properties");
            }
            return load(input);
        } catch (IOException error) {
            throw new IllegalStateException("No se pudo leer la edición", error);
        }
    }

    static EditionSettings load(InputStream input) throws IOException {
        Properties properties = new Properties();
        properties.load(new InputStreamReader(input, StandardCharsets.UTF_8));
        return new EditionSettings(
                AppEdition.parse(properties.getProperty("edition")),
                properties.getProperty("displayName"),
                Boolean.parseBoolean(properties.getProperty("networkEnabled")));
    }
}
