package com.atorbado.vialidadinvernal.config;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;

import java.nio.file.Path;
import org.junit.jupiter.api.Test;

class RuntimeConfigurationLoaderTest {
    @Test
    void acceptsWorkspaceRoot() {
        Path workspace = Path.of(System.getProperty("user.home"), "VialidadInvernalDemo");
        RuntimeConfiguration config = new RuntimeConfiguration(workspace);

        assertEquals(workspace.normalize(), config.workspaceRoot());
    }

    @Test
    void rejectsNullWorkspaceRoot() {
        assertThrows(NullPointerException.class,
                () -> new RuntimeConfiguration(null));
    }

    @Test
    void demoSettingsReturnLocalPath() throws Exception {
        EditionSettings settings = new EditionSettings(AppEdition.DEMO, "Demo", false);
        RuntimeConfiguration config = RuntimeConfigurationLoader.load(settings);

        Path expected = Path.of(System.getProperty("user.home"), "VialidadInvernalDemo");
        assertEquals(expected.normalize(), config.workspaceRoot());
    }

    @Test
    void nullSettingsRejects() {
        assertThrows(NullPointerException.class,
                () -> RuntimeConfigurationLoader.load(null));
    }
}
