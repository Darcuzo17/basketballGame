package ru.bbmanager.competition;

import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;

/** Сила игрока и команды. Тактику ведёт тренер, поэтому его навык входит в силу команды. */
public final class TeamRating {

    private static final int ROTATION_SIZE = 8;
    private static final double REPLACEMENT_LEVEL = 20.0; // если игроков меньше восьми, недостающие слабые

    private TeamRating() {
    }

    public static double playerRating(int attack, int defense, int physical, int basketballIq, int form, int fatigue) {
        double base = attack * 0.35 + defense * 0.30 + physical * 0.15 + basketballIq * 0.20;
        double formFactor = 0.95 + form * 0.001;        // форма 0..100 даёт от -5% до +5%
        double fatigueFactor = 1.0 - fatigue * 0.0015;  // усталость 100 снижает силу на 15%
        return base * formFactor * fatigueFactor;
    }

    public static double teamRating(List<Double> playerRatings, double coachTactics) {
        List<Double> sorted = new ArrayList<>(playerRatings);
        sorted.sort(Comparator.reverseOrder());
        double sum = 0;
        for (int i = 0; i < ROTATION_SIZE; i++) {
            sum += i < sorted.size() ? sorted.get(i) : REPLACEMENT_LEVEL;
        }
        return sum / ROTATION_SIZE + (coachTactics - 50) * 0.1;
    }
}
