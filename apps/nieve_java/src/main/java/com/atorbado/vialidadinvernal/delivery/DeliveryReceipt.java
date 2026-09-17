package com.atorbado.vialidadinvernal.delivery;

import java.nio.file.Path;
import java.time.Instant;

public record DeliveryReceipt(Path previewFile, Instant createdAt) {
}
