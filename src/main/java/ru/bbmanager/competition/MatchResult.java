package ru.bbmanager.competition;

import java.util.List;

/** Итог матча. periods: счёт по периодам [хозяева, гости]; четыре четверти плюс овертаймы. */
public record MatchResult(int homeScore, int awayScore, List<int[]> periods) {

    public boolean homeWon() {
        return homeScore > awayScore;
    }

    public boolean overtime() {
        return periods.size() > 4;
    }

    /** Счёт по периодам в виде JSON: [[20,18],[22,25],...]. */
    public String periodsJson() {
        StringBuilder sb = new StringBuilder("[");
        for (int i = 0; i < periods.size(); i++) {
            if (i > 0) {
                sb.append(',');
            }
            sb.append('[').append(periods.get(i)[0]).append(',').append(periods.get(i)[1]).append(']');
        }
        return sb.append(']').toString();
    }
}
