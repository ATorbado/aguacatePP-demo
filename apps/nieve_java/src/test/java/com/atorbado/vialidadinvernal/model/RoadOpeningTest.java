package com.atorbado.vialidadinvernal.model;

import org.junit.jupiter.api.Test;
import java.time.LocalDateTime;
import static org.junit.jupiter.api.Assertions.*;

class RoadOpeningTest {
    @Test
    void testValidConstruction() {
        LocalDateTime startedAt = LocalDateTime.of(2024, 1, 15, 8, 30);
        RoadOpening opening = new RoadOpening("Calle Principal", startedAt, "pk1", "pk2", "Seccion A", "Asfalto");
        assertEquals("Calle Principal", opening.road());
        assertEquals(startedAt, opening.startedAt());
        assertEquals("pk1", opening.startPk());
        assertEquals("pk2", opening.endPk());
        assertEquals("Seccion A", opening.section());
        assertEquals("Asfalto", opening.roadType());
    }

    @Test
    void testStartedAtNull() {
        assertThrows(IllegalArgumentException.class, () -> {
            new RoadOpening("Calle Principal", null, "pk1", "pk2", "Seccion A", "Asfalto");
        });
    }

    @Test
    void testRoadNull() {
        assertThrows(IllegalArgumentException.class, () -> {
            new RoadOpening(null, LocalDateTime.of(2024, 1, 15, 8, 30), "pk1", "pk2", "Seccion A", "Asfalto");
        });
    }

    @Test
    void testRoadBlank() {
        assertThrows(IllegalArgumentException.class, () -> {
            new RoadOpening(" ", LocalDateTime.of(2024, 1, 15, 8, 30), "pk1", "pk2", "Seccion A", "Asfalto");
        });
    }

    @Test
    void testStartPkNull() {
        assertThrows(IllegalArgumentException.class, () -> {
            new RoadOpening("Calle Principal", LocalDateTime.of(2024, 1, 15, 8, 30), null, "pk2", "Seccion A", "Asfalto");
        });
    }

    @Test
    void testStartPkBlank() {
        assertThrows(IllegalArgumentException.class, () -> {
            new RoadOpening("Calle Principal", LocalDateTime.of(2024, 1, 15, 8, 30), " ", "pk2", "Seccion A", "Asfalto");
        });
    }

    @Test
    void testEndPkNull() {
        assertThrows(IllegalArgumentException.class, () -> {
            new RoadOpening("Calle Principal", LocalDateTime.of(2024, 1, 15, 8, 30), "pk1", null, "Seccion A", "Asfalto");
        });
    }

    @Test
    void testEndPkBlank() {
        assertThrows(IllegalArgumentException.class, () -> {
            new RoadOpening("Calle Principal", LocalDateTime.of(2024, 1, 15, 8, 30), "pk1", " ", "Seccion A", "Asfalto");
        });
    }

    @Test
    void testSectionNull() {
        assertThrows(IllegalArgumentException.class, () -> {
            new RoadOpening("Calle Principal", LocalDateTime.of(2024, 1, 15, 8, 30), "pk1", "pk2", null, "Asfalto");
        });
    }

    @Test
    void testSectionBlank() {
        assertThrows(IllegalArgumentException.class, () -> {
            new RoadOpening("Calle Principal", LocalDateTime.of(2024, 1, 15, 8, 30), "pk1", "pk2", " ", "Asfalto");
        });
    }

    @Test
    void testRoadTypeNull() {
        assertThrows(IllegalArgumentException.class, () -> {
            new RoadOpening("Calle Principal", LocalDateTime.of(2024, 1, 15, 8, 30), "pk1", "pk2", "Seccion A", null);
        });
    }

    @Test
    void testRoadTypeBlank() {
        assertThrows(IllegalArgumentException.class, () -> {
            new RoadOpening("Calle Principal", LocalDateTime.of(2024, 1, 15, 8, 30), "pk1", "pk2", "Seccion A", " ");
        });
    }
}
