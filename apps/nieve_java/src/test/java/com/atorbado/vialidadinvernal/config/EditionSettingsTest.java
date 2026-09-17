package com.atorbado.vialidadinvernal.config;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;

import java.io.ByteArrayInputStream;
import java.nio.charset.StandardCharsets;
import org.junit.jupiter.api.Test;

class EditionSettingsTest {
    @Test
    void bundledEditionRespectsDemoNetworkRule() {
        EditionSettings settings = EditionSettings.loadBundled();
        assertEquals(AppEdition.DEMO, settings.edition());
        assertEquals("Vialidad Invernal — Demostración", settings.displayName());
        assertFalse(settings.networkEnabled());
    }

    @Test
    void rejectsDemoWithNetworkEnabled() {
        String properties = "edition=demo\ndisplayName=Demo\nnetworkEnabled=true\n";
        assertThrows(IllegalArgumentException.class, () -> EditionSettings.load(
                new ByteArrayInputStream(properties.getBytes(StandardCharsets.UTF_8))));
    }

    @Test
    void rejectsUnsupportedEdition() {
        String properties = "edition=OTHER\ndisplayName=Other\nnetworkEnabled=false\n";
        assertThrows(IllegalArgumentException.class, () -> EditionSettings.load(
                new ByteArrayInputStream(properties.getBytes(StandardCharsets.UTF_8))));
    }

    @Test
    void rejectsDemoWithNetworkEnabledUpperCase() {
        String properties = "edition=DEMO\ndisplayName=Demo\nnetworkEnabled=true\n";
        assertThrows(IllegalArgumentException.class, () -> EditionSettings.load(
                new ByteArrayInputStream(properties.getBytes(StandardCharsets.UTF_8))));
    }
}
