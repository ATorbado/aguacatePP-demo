package com.atorbado.vialidadinvernal.delivery;

import java.nio.file.Path;
import java.util.List;

public record DeliveryRequest(String subject, String body, List<Path> attachments) {
    public DeliveryRequest {
        if (subject == null || subject.isBlank()) {
            throw new IllegalArgumentException("El asunto no puede estar vacío");
        }
        if (body == null || body.isBlank()) {
            throw new IllegalArgumentException("El cuerpo no puede estar vacío");
        }
        attachments = attachments == null ? List.of() : List.copyOf(attachments);
    }
}
