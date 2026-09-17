package com.atorbado.vialidadinvernal.model;

import java.time.LocalDateTime;

public record RoadClosure(RoadOpening opening, LocalDateTime endedAt, String closingNote) {
    public RoadClosure {
        if (opening == null) {
            throw new IllegalArgumentException("opening");
        }
        if (endedAt == null) {
            throw new IllegalArgumentException("endedAt");
        }
        if (closingNote == null || closingNote.isBlank()) {
            throw new IllegalArgumentException("closingNote");
        }
        if (endedAt.isBefore(opening.startedAt())) {
            throw new IllegalArgumentException("endedAt");
        }
    }

    public RoadOpening opening() {
        return opening;
    }

    public LocalDateTime endedAt() {
        return endedAt;
    }

    public String closingNote() {
        return closingNote;
    }
}
