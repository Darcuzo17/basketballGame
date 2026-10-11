package ru.bbmanager.competition;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.time.DayOfWeek;
import java.time.LocalDate;
import java.util.List;
import org.junit.jupiter.api.Test;

class ScheduleGeneratorTest {

    @Test
    void firstSaturdayIsOnOrAfterFirstOfOctober() {
        assertEquals(LocalDate.of(2026, 10, 3), ScheduleGenerator.firstLeagueSaturday(2026));
        assertEquals(DayOfWeek.SATURDAY, ScheduleGenerator.firstLeagueSaturday(2027).getDayOfWeek());
        assertTrue(!ScheduleGenerator.firstLeagueSaturday(2027).isBefore(LocalDate.of(2027, 10, 1)));
    }

    @Test
    void matchesAreOnWeekendsOneRoundPerWeek() {
        LocalDate start = LocalDate.of(2026, 10, 3);
        List<ScheduledMatch> matches = ScheduleGenerator.generate(List.of(1, 2, 3, 4, 5, 6), start);

        assertEquals(6 * 5, matches.size());
        for (ScheduledMatch m : matches) {
            DayOfWeek day = m.date().getDayOfWeek();
            assertTrue(day == DayOfWeek.SATURDAY || day == DayOfWeek.SUNDAY, "матч в будний день: " + m.date());
            LocalDate saturday = start.plusWeeks(m.round() - 1);
            assertTrue(m.date().equals(saturday) || m.date().equals(saturday.plusDays(1)),
                    "матч тура " + m.round() + " вне своих выходных: " + m.date());
        }
        long saturdays = matches.stream().filter(m -> m.round() == 1 && m.date().getDayOfWeek() == DayOfWeek.SATURDAY).count();
        assertEquals(2, saturdays, "в субботу играется около половины матчей тура");
    }
}
