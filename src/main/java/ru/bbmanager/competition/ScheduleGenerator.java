package ru.bbmanager.competition;

import java.time.DayOfWeek;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;
import java.time.temporal.TemporalAdjusters;

/**
 * Расписание чемпионата: двухкруговой турнир, один тур в неделю.
 * Первая половина матчей тура идёт в субботу, остальные в воскресенье
 * (выходные дают больший спрос на билеты, см. day_demand_factor).
 */
public final class ScheduleGenerator {

    private ScheduleGenerator() {
    }

    /** Первая суббота, начиная с 1 октября года начала сезона. */
    public static LocalDate firstLeagueSaturday(int seasonStartYear) {
        return LocalDate.of(seasonStartYear, 10, 1).with(TemporalAdjusters.nextOrSame(DayOfWeek.SATURDAY));
    }

    public static List<ScheduledMatch> generate(List<Integer> clubIds, LocalDate firstSaturday) {
        List<List<Pairing>> rounds = RoundRobin.doubleRoundRobin(clubIds);
        List<ScheduledMatch> result = new ArrayList<>();
        for (int r = 0; r < rounds.size(); r++) {
            List<Pairing> round = rounds.get(r);
            LocalDate saturday = firstSaturday.plusWeeks(r);
            int onSaturday = (round.size() + 1) / 2;
            for (int i = 0; i < round.size(); i++) {
                Pairing p = round.get(i);
                LocalDate date = i < onSaturday ? saturday : saturday.plusDays(1);
                result.add(new ScheduledMatch(r + 1, date, p.home(), p.away()));
            }
        }
        return result;
    }
}
