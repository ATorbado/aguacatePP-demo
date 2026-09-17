package com.atorbado.vialidadinvernal.model;

import java.time.LocalDateTime;

public record RoadRestriction(String road, LocalDateTime startedAt, String restriction,
                               String startPk, String endPk, String section, String roadType) {
    public RoadRestriction {
        if (road == null || road.isBlank()) {
            throw new IllegalArgumentException("road");
        }
        if (startedAt == null) {
            throw new IllegalArgumentException("startedAt");
        }
        if (restriction == null || restriction.isBlank()) {
            throw new IllegalArgumentException("restriction");
        }
        if (startPk == null || startPk.isBlank()) {
            throw new IllegalArgumentException("startPk");
        }
        if (endPk == null || endPk.isBlank()) {
            throw new IllegalArgumentException("endPk");
        }
        if (section == null || section.isBlank()) {
            throw new IllegalArgumentException("section");
        }
        if (roadType == null || roadType.isBlank()) {
            throw new IllegalArgumentException("roadType");
        }
    }
}
