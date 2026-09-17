package com.atorbado.vialidadinvernal.config;

import java.util.Locale;

public enum AppEdition {
    DEMO;

    public static AppEdition parse(String value) {
        if (value == null || value.isBlank()) {
            throw new IllegalArgumentException("La edición no está configurada");
        }
        try {
            return valueOf(value.trim().toUpperCase(Locale.ROOT));
        } catch (IllegalArgumentException error) {
            throw new IllegalArgumentException("Edición no reconocida", error);
        }
    }
}
