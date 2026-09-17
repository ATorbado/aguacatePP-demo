package com.atorbado.vialidadinvernal.delivery;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import com.atorbado.vialidadinvernal.storage.WorkspacePolicy;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.List;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

class PreviewMessageDeliveryTest {
    @TempDir
    Path temporaryDirectory;

    @Test
    void writesLocalPreviewWithoutRecipientsOrNetwork() throws Exception {
        WorkspacePolicy workspace = new WorkspacePolicy(temporaryDirectory);
        Instant now = Instant.parse("2026-08-31T12:00:00Z");
        PreviewMessageDelivery delivery = new PreviewMessageDelivery(
                workspace,
                Clock.fixed(now, ZoneOffset.UTC));

        DeliveryReceipt receipt = delivery.deliver(new DeliveryRequest(
                "Aviso ficticio",
                "Contenido de demostración",
                List.of(Path.of("documento-sintetico.xlsx"))));

        String content = Files.readString(receipt.previewFile());
        assertEqualsInstant(now, receipt.createdAt());
        assertTrue(content.contains("SIMULACIÓN LOCAL — NO ENVIADA"));
        assertTrue(content.contains("documento-sintetico.xlsx"));
        assertFalse(content.contains("@"));
    }

    private static void assertEqualsInstant(Instant expected, Instant actual) {
        assertTrue(expected.equals(actual));
    }
}
