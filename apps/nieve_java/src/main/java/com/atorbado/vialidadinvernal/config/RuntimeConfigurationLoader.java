package com.atorbado.vialidadinvernal.config;

import java.nio.file.Path;

public final class RuntimeConfigurationLoader {
    private RuntimeConfigurationLoader() {
    }

    public static RuntimeConfiguration load(EditionSettings settings) {
        if (settings == null) {
            throw new NullPointerException("settings must not be null");
        }
        if (settings.edition() == AppEdition.DEMO && !settings.networkEnabled()) {
            Path workspace = Path.of(System.getProperty("user.home"), "VialidadInvernalDemo");
            return new RuntimeConfiguration(workspace);
        }

        throw new IllegalArgumentException(
                "Solo se permite la configuración DEMO para el entorno público.");
    }
}
