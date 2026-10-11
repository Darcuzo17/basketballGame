package ru.bbmanager.competition;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import org.junit.jupiter.api.Test;

class RoundRobinTest {

    @Test
    void evenNumberOfClubsPlaysEveryPairHomeAndAway() {
        check(List.of(1, 2, 3, 4, 5, 6), 10);
    }

    @Test
    void oddNumberOfClubsGivesEachClubOneFreeRoundPerCircle() {
        check(List.of(1, 2, 3, 4, 5), 10);
    }

    @Test
    void twelveClubsAreAlsoCorrect() {
        check(List.of(1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12), 22);
    }

    @Test
    void fewerThanTwoClubsHaveNoMatches() {
        assertTrue(RoundRobin.doubleRoundRobin(List.of(1)).isEmpty());
        assertTrue(RoundRobin.doubleRoundRobin(List.of()).isEmpty());
    }

    private static void check(List<Integer> clubs, int expectedRounds) {
        List<List<Pairing>> rounds = RoundRobin.doubleRoundRobin(clubs);
        assertEquals(expectedRounds, rounds.size(), "число туров");

        Set<String> directed = new HashSet<>();
        Map<Integer, Integer> home = new HashMap<>();
        Map<Integer, Integer> away = new HashMap<>();
        for (List<Pairing> round : rounds) {
            Set<Integer> busy = new HashSet<>();
            for (Pairing p : round) {
                assertTrue(busy.add(p.home()), "клуб " + p.home() + " дважды в одном туре");
                assertTrue(busy.add(p.away()), "клуб " + p.away() + " дважды в одном туре");
                assertTrue(directed.add(p.home() + ">" + p.away()), "повтор пары " + p.home() + ">" + p.away());
                home.merge(p.home(), 1, Integer::sum);
                away.merge(p.away(), 1, Integer::sum);
            }
        }
        int n = clubs.size();
        assertEquals(n * (n - 1), directed.size(), "каждая пара дома и в гостях");
        for (int club : clubs) {
            assertEquals(n - 1, home.get(club), "домашних матчей у " + club);
            assertEquals(n - 1, away.get(club), "гостевых матчей у " + club);
        }
    }
}
