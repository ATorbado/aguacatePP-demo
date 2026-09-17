package com.atorbado.vialidadinvernal.model;

import org.junit.jupiter.api.Test;
import java.time.LocalDateTime;
import static org.junit.jupiter.api.Assertions.*;

class RoadRestrictionTest {

    @Test
    void testConstructionValida() {
        LocalDateTime startedAt = LocalDateTime.now();
        RoadRestriction rr = new RoadRestriction("Calle Principal", startedAt, "Cerrado por nieve", "100", "200", "Seccion A", "Asfalto");
        assertEquals("Calle Principal", rr.road());
        assertEquals(startedAt, rr.startedAt());
        assertEquals("Cerrado por nieve", rr.restriction());
        assertEquals("100", rr.startPk());
        assertEquals("200", rr.endPk());
        assertEquals("Seccion A", rr.section());
        assertEquals("Asfalto", rr.roadType());
    }

    @Test
    void testRoadNull() {
        assertThrows(IllegalArgumentException.class, () -> new RoadRestriction(null, LocalDateTime.now(), "test", "100", "200", "A", "P"));
    }

    @Test
    void testRoadBlank() {
        assertThrows(IllegalArgumentException.class, () -> new RoadRestriction("  ", LocalDateTime.now(), "test", "100", "200", "A", "P"));
    }

    @Test
    void testStartedAtNull() {
        assertThrows(IllegalArgumentException.class, () -> new RoadRestriction("Calle", null, "test", "100", "200", "A", "P"));
    }

    @Test
    void testRestrictionNull() {
        assertThrows(IllegalArgumentException.class, () -> new RoadRestriction("Calle", LocalDateTime.now(), null, "100", "200", "A", "P"));
    }

    @Test
    void testStartPkNull() {
        assertThrows(IllegalArgumentException.class, () -> new RoadRestriction("Calle", LocalDateTime.now(), "test", null, "200", "A", "P"));
    }

    @Test
    void testEndPkNull() {
        assertThrows(IllegalArgumentException.class, () -> new RoadRestriction("Calle", LocalDateTime.now(), "test", "100", null, "A", "P"));
    }

    @Test
    void testSectionNull() {
        assertThrows(IllegalArgumentException.class, () -> new RoadRestriction("Calle", LocalDateTime.now(), "test", "100", "200", null, "P"));
    }

    @Test
    void testRoadTypeNull() {
        assertThrows(IllegalArgumentException.class, () -> new RoadRestriction("Calle", LocalDateTime.now(), "test", "100", "200", "A", null));
    }
}
