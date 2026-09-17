package com.atorbado.vialidadinvernal.storage;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.LinkOption;
import java.nio.file.Path;

public final class WorkspacePolicy {
    private final Path root;

    public WorkspacePolicy(Path requestedRoot) throws IOException {
        Path normalized = requestedRoot.toAbsolutePath().normalize();
        Files.createDirectories(normalized);
        root = normalized.toRealPath(LinkOption.NOFOLLOW_LINKS);
    }

    public Path root() {
        return root;
    }

    public Path resolveFile(String relativeName) {
        if (relativeName == null || relativeName.isBlank()) {
            throw new IllegalArgumentException("El nombre no puede estar vacío");
        }
        Path relative = Path.of(relativeName);
        if (relative.isAbsolute()) {
            throw new IllegalArgumentException("No se permiten rutas absolutas");
        }
        Path resolved = root.resolve(relative).normalize();
        if (!resolved.startsWith(root)) {
            throw new IllegalArgumentException("La ruta sale de la carpeta permitida");
        }
        return resolved;
    }

    public Path prepareDirectory(String relativeName) throws IOException {
        Path directory = resolveFile(relativeName);
        Files.createDirectories(directory);
        Path realDirectory = directory.toRealPath(LinkOption.NOFOLLOW_LINKS);
        if (!realDirectory.startsWith(root)) {
            throw new IOException("La carpeta resuelta sale del espacio permitido");
        }
        return realDirectory;
    }
}
