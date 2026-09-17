package com.atorbado.vialidadinvernal.delivery;

import com.atorbado.vialidadinvernal.storage.WorkspacePolicy;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardOpenOption;
import java.time.Clock;
import java.time.Instant;
import java.util.UUID;

public final class PreviewMessageDelivery implements MessageDelivery {
    private final WorkspacePolicy workspace;
    private final Clock clock;

    public PreviewMessageDelivery(WorkspacePolicy workspace) {
        this(workspace, Clock.systemUTC());
    }

    PreviewMessageDelivery(WorkspacePolicy workspace, Clock clock) {
        this.workspace = workspace;
        this.clock = clock;
    }

    @Override
    public DeliveryReceipt deliver(DeliveryRequest request) throws IOException {
        Path directory = workspace.prepareDirectory("previews");
        Path output = directory.resolve("mensaje-demo-" + UUID.randomUUID() + ".txt");
        StringBuilder content = new StringBuilder()
                .append("SIMULACIÓN LOCAL — NO ENVIADA\n\n")
                .append("Asunto: ").append(request.subject()).append("\n\n")
                .append(request.body()).append("\n\n")
                .append("Adjuntos:\n");
        request.attachments().stream()
                .map(Path::getFileName)
                .forEach(name -> content.append("- ").append(name).append('\n'));
        Files.writeString(
                output,
                content,
                StandardCharsets.UTF_8,
                StandardOpenOption.CREATE_NEW,
                StandardOpenOption.WRITE);
        return new DeliveryReceipt(output, Instant.now(clock));
    }
}
