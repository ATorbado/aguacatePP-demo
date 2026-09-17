package com.atorbado.vialidadinvernal.model;

import org.junit.jupiter.api.Test;
import java.time.LocalDateTime;

import static org.junit.jupiter.api.Assertions.*;

class RoadClosureTest {

    @Test
    void testValidConstruction() {
        LocalDateTime startedAt = LocalDateTime.of(2024, 1, 15, 8, 0);
        LocalDateTime endedAt = LocalDateTime.of(2024, 1, 15, 9, 0);
        RoadOpening opening = new RoadOpening("Calle Principal", startedAt, "pk1", "pk2", "section", "type");

        assertDoesNotThrow(() -> new RoadClosure(opening, endedAt, "Nota de cierre"));
    }

    @Test
    void testSameHourValid() {
        LocalDateTime startedAt = LocalDateTime.of(2024, 1, 15, 8, 0);
        LocalDateTime endedAt = LocalDateTime.of(2024, 1, 15, 8, 0);
        RoadOpening opening = new RoadOpening("Calle Principal", startedAt, "pk1", "pk2", "section", "type");

        assertDoesNotThrow(() -> new RoadClosure(opening, endedAt, "Nota de cierre"));
    }

    @Test
    void testNullOpening() {
        LocalDateTime endedAt = LocalDateTime.of(2024, 1, 15, 9, 0);
        assertThrows(IllegalArgumentException.class, () -> new RoadClosure(null, endedAt, "Nota"), "opening");
    }

    @Test
    void testNullEndedAt() {
        LocalDateTime startedAt = LocalDateTime.of(2024, 1, 15, 8, 0);
        RoadOpening opening = new RoadOpening("Calle Principal", startedAt, "pk1", "pk2", "section", "type");
        assertThrows(IllegalArgumentException.class, () -> new RoadClosure(opening, null, "Nota"), "endedAt");
    }

    @Test
    void testNullClosingNote() {
        LocalDateTime startedAt = LocalDateTime.of(2024, 1, 15, 8, 0);
        RoadOpening opening = new RoadOpening("Calle Principal", startedAt, "pk1", "pk2", "section", "type");
        assertThrows(IllegalArgumentException.class, () -> new RoadClosure(opening, LocalDateTime.of(2024, 1, 15, 9, 0), null), "closingNote");
    }

    @Test
    void testBlankClosingNote() {
        LocalDateTime startedAt = LocalDateTime.of(2024, 1, 15, 8, 0);
        RoadOpening opening = new RoadOpening("Calle Principal", startedAt, "pk1", "pk2", "section", "type");
        assertThrows(IllegalArgumentException.class, () -> new RoadClosure(opening, LocalDateTime.of(2024, 1, 15, 9, 0), " "), "closingNote");
    }

    @Test
    void testEndedAtBeforeStartedAt() {
        LocalDateTime startedAt = LocalDateTime.of(2024, 1, 15, 9, 0);
        RoadOpening opening = new RoadOpening("Calle Principal", startedAt, "pk1", "pk2", "section", "type");
        assertThrows(IllegalArgumentException.class, () -> new RoadClosure(opening, LocalDateTime.of(2024, 1, 15, 8, 0), "Nota"), "endedAt");
    }
}
