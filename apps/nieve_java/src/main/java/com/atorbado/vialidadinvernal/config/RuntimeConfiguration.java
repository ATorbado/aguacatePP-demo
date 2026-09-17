package com.atorbado.vialidadinvernal.config;

import java.nio.file.Path;

public record RuntimeConfiguration(Path workspaceRoot) {
    public RuntimeConfiguration {
        if (workspaceRoot == null) {
            throw new NullPointerException("workspaceRoot must not be null");
        }
        workspaceRoot = workspaceRoot.toAbsolutePath().normalize();
    }
}
