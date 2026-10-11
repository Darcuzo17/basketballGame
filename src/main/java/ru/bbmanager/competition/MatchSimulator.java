package ru.bbmanager.competition;

import java.util.ArrayList;
import java.util.List;
import java.util.Random;

/**
 * Расчёт матча без участия игрока: счёт зависит от разницы сил команд, домашнего поля и случайности.
 * Ничьих нет: при равенстве играются овертаймы. Параметры подберёте при балансировке.
 */
public final class MatchSimulator {

    private static final double BASE_POINTS = 80.0;
    private static final double HOME_BONUS = 1.5;      // итого около +3 очков к разнице в пользу хозяев
    private static final double STRENGTH_TO_POINTS = 1.0;
    private static final double QUARTER_SD = 4.3;
    private static final double MIN_MEAN = 55.0;
    private static final double MAX_MEAN = 110.0;
    private static final int MAX_OVERTIMES = 10;

    /**
     * Начальное значение генератора для матча. Результат повторяем (одинаковый матч даёт одинаковый счёт),
     * а соседние матчи не должны получать похожие числа: у java.util.Random с последовательными
     * seed первые значения почти совпадают, поэтому seed перемешивается (финализатор SplitMix64).
     */
    public static long seedFor(int saveId, int matchId) {
        long z = ((long) saveId << 32) ^ (matchId & 0xFFFFFFFFL);
        z += 0x9E3779B97F4A7C15L;
        z = (z ^ (z >>> 30)) * 0xBF58476D1CE4E5B9L;
        z = (z ^ (z >>> 27)) * 0x94D049BB133111EBL;
        return z ^ (z >>> 31);
    }

    public MatchResult simulate(double homeRating, double awayRating, Random random) {
        double margin = (homeRating - awayRating) * STRENGTH_TO_POINTS;
        double homeMean = clamp(BASE_POINTS + margin / 2 + HOME_BONUS);
        double awayMean = clamp(BASE_POINTS - margin / 2 - HOME_BONUS);

        List<int[]> periods = new ArrayList<>();
        int home = 0;
        int away = 0;
        for (int q = 0; q < 4; q++) {
            int h = points(homeMean / 4, QUARTER_SD, 8, random);
            int a = points(awayMean / 4, QUARTER_SD, 8, random);
            periods.add(new int[] {h, a});
            home += h;
            away += a;
        }
        int overtimes = 0;
        while (home == away && overtimes < MAX_OVERTIMES) {
            int h = points(10, 3.0, 3, random);
            int a = points(10, 3.0, 3, random);
            periods.add(new int[] {h, a});
            home += h;
            away += a;
            overtimes++;
        }
        if (home == away) { // крайне маловероятно: после десяти овертаймов решает последний бросок
            if (random.nextBoolean()) {
                home++;
            } else {
                away++;
            }
            int last = periods.size() - 1;
            periods.get(last)[home > away ? 0 : 1]++;
        }
        return new MatchResult(home, away, periods);
    }

    private static int points(double mean, double sd, int min, Random random) {
        return Math.max(min, (int) Math.round(mean + random.nextGaussian() * sd));
    }

    private static double clamp(double value) {
        return Math.max(MIN_MEAN, Math.min(MAX_MEAN, value));
    }
}
