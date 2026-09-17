package com.atorbado.vialidadinvernal.storage;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;

import java.nio.file.Path;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

class WorkspacePolicyTest {
    @TempDir
    Path temporaryDirectory;

    @Test
    void resolvesFilesInsideWorkspace() throws Exception {
        WorkspacePolicy policy = new WorkspacePolicy(temporaryDirectory);
        assertEquals(policy.root().resolve("reports/demo.xlsx"),
                policy.resolveFile("reports/demo.xlsx"));
    }

    @Test
    void rejectsTraversalAndAbsolutePaths() throws Exception {
        WorkspacePolicy policy = new WorkspacePolicy(temporaryDirectory);
        assertThrows(IllegalArgumentException.class,
                () -> policy.resolveFile("../outside.txt"));
        assertThrows(IllegalArgumentException.class,
                () -> policy.resolveFile(temporaryDirectory.resolve("absolute.txt").toString()));
    }
}
