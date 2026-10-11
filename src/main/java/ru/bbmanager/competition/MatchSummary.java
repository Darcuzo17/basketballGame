package ru.bbmanager.competition;

/** Короткая текстовая хроника матча для ленты и карточки матча. */
public final class MatchSummary {

    private MatchSummary() {
    }

    public static String describe(String homeName, String awayName, MatchResult result) {
        boolean homeWon = result.homeWon();
        String winner = homeWon ? homeName : awayName;
        int margin = Math.abs(result.homeScore() - result.awayScore());
        String score = result.homeScore() + ":" + result.awayScore();

        String character;
        if (result.overtime()) {
            character = "Победа в овертайме";
        } else if (margin <= 3) {
            character = "Упорная борьба до конца";
        } else if (margin <= 10) {
            character = "Уверенная победа";
        } else if (margin <= 20) {
            character = "Победа с заметным преимуществом";
        } else {
            character = "Разгром";
        }

        StringBuilder text = new StringBuilder(character).append(": ").append(winner).append(" (").append(score).append(").");
        if (!result.overtime() && margin > 3) {
            int bestQuarter = 0;
            int bestMargin = Integer.MIN_VALUE;
            for (int q = 0; q < 4; q++) {
                int[] p = result.periods().get(q);
                int m = homeWon ? p[0] - p[1] : p[1] - p[0];
                if (m > bestMargin) {
                    bestMargin = m;
                    bestQuarter = q;
                }
            }
            text.append(" Решающий отрыв в ").append(bestQuarter + 1).append("-й четверти.");
        }
        return text.toString();
    }
}
