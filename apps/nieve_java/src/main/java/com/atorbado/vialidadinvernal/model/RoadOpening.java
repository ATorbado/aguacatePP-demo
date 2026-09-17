package com.atorbado.vialidadinvernal.model;

import java.time.LocalDateTime;

public record RoadOpening(String road, LocalDateTime startedAt, String startPk, String endPk, String section, String roadType) {
    public RoadOpening {
        if (startedAt == null) {
            throw new IllegalArgumentException("startedAt");
        }
        if (road == null || road.isBlank()) {
            throw new IllegalArgumentException("road");
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
