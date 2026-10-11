package ru.bbmanager.competition;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.List;
import java.util.Random;
import org.junit.jupiter.api.Test;

class MatchSimulatorTest {

    private final MatchSimulator simulator = new MatchSimulator();

    @Test
    void neverEndsInDrawAndPeriodsAddUp() {
        Random random = new Random(1);
        for (int i = 0; i < 3000; i++) {
            MatchResult r = simulator.simulate(55, 55, random);
            assertNotEquals(r.homeScore(), r.awayScore());
            assertTrue(r.periods().size() >= 4);
            assertEquals(r.homeScore(), r.periods().stream().mapToInt(p -> p[0]).sum());
            assertEquals(r.awayScore(), r.periods().stream().mapToInt(p -> p[1]).sum());
        }
    }

    @Test
    void strongerTeamWinsMostGamesAndHomeCourtHelps() {
        Random random = new Random(2);
        int strongWins = 0;
        int homeWinsEqual = 0;
        int games = 4000;
        for (int i = 0; i < games; i++) {
            if (simulator.simulate(65, 52, random).homeWon()) {
                strongWins++;
            }
            if (simulator.simulate(55, 55, random).homeWon()) {
                homeWinsEqual++;
            }
        }
        assertTrue(strongWins > games * 0.80, "сильный дома выиграл только " + strongWins + " из " + games);
        assertTrue(homeWinsEqual > games * 0.50 && homeWinsEqual < games * 0.70,
                "домашнее поле у равных: " + homeWinsEqual + " из " + games);
    }

    @Test
    void scoresLookLikeBasketball() {
        Random random = new Random(3);
        double total = 0;
        int games = 2000;
        for (int i = 0; i < games; i++) {
            MatchResult r = simulator.simulate(55, 55, random);
            total += r.homeScore() + r.awayScore();
        }
        double avgTeam = total / games / 2;
        assertTrue(avgTeam > 70 && avgTeam < 95, "средний счёт команды " + avgTeam);
    }

    @Test
    void sameSeedGivesSameResult() {
        MatchResult a = simulator.simulate(60, 50, new Random(42));
        MatchResult b = simulator.simulate(60, 50, new Random(42));
        assertEquals(a.homeScore(), b.homeScore());
        assertEquals(a.awayScore(), b.awayScore());
        assertEquals(a.periodsJson(), b.periodsJson());
    }

    @Test
    void resultsOfNeighbouringMatchesAreNotCorrelated() {
        int n = 20000;
        double[] margins = new double[n];
        for (int id = 1; id <= n; id++) {
            MatchResult r = simulator.simulate(55, 55, new Random(MatchSimulator.seedFor(7, id)));
            margins[id - 1] = r.homeScore() - r.awayScore();
        }
        double mean = 0;
        for (double v : margins) {
            mean += v;
        }
        mean /= n;
        double num = 0;
        double den = 0;
        for (int i = 0; i < n; i++) {
            den += (margins[i] - mean) * (margins[i] - mean);
            if (i > 0) {
                num += (margins[i] - mean) * (margins[i - 1] - mean);
            }
        }
        double lag1 = num / den;
        assertTrue(Math.abs(lag1) < 0.03, "корреляция соседних матчей " + lag1);
    }

    @Test
    void seedDependsOnSaveAndMatch() {
        assertEquals(MatchSimulator.seedFor(1, 5), MatchSimulator.seedFor(1, 5));
        assertNotEquals(MatchSimulator.seedFor(1, 5), MatchSimulator.seedFor(1, 6));
        assertNotEquals(MatchSimulator.seedFor(1, 5), MatchSimulator.seedFor(2, 5));
    }

    @Test
    void teamRatingUsesTopEightAndCoach() {
        List<Double> ten = List.of(70.0, 70.0, 70.0, 70.0, 70.0, 70.0, 70.0, 70.0, 10.0, 10.0);
        assertEquals(70.0, TeamRating.teamRating(ten, 50), 1e-9);
        assertEquals(75.0, TeamRating.teamRating(ten, 100), 1e-9);
        assertTrue(TeamRating.teamRating(List.of(70.0), 50) < 40, "неполный состав должен быть слабее");
        assertTrue(TeamRating.playerRating(60, 60, 60, 60, 50, 0) > TeamRating.playerRating(60, 60, 60, 60, 50, 80));
    }

    @Test
    void summaryMentionsWinnerAndScore() {
        MatchResult r = new MatchResult(90, 70, List.of(new int[] {20, 18}, new int[] {25, 15}, new int[] {22, 20}, new int[] {23, 17}));
        String text = MatchSummary.describe("Дома", "Гости", r);
        assertTrue(text.contains("Дома") && text.contains("90:70"), text);
        assertTrue(text.contains("2-й четверти"), text);
    }
}
