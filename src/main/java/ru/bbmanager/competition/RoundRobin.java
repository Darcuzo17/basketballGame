package ru.bbmanager.competition;

import java.util.ArrayList;
import java.util.List;

/**
 * Круговой турнир по методу вращения. Для нечётного числа клубов в каждом туре один клуб свободен.
 * В двухкруговом турнире второй круг зеркален первому, поэтому у каждого клуба поровну домашних и гостевых матчей.
 */
public final class RoundRobin {

    private RoundRobin() {
    }

    /** Два круга: каждый клуб играет с каждым дома и в гостях. */
    public static List<List<Pairing>> doubleRoundRobin(List<Integer> clubIds) {
        List<List<Pairing>> first = singleRoundRobin(clubIds);
        List<List<Pairing>> all = new ArrayList<>(first);
        for (List<Pairing> round : first) {
            all.add(round.stream().map(p -> new Pairing(p.away(), p.home())).toList());
        }
        return all;
    }

    static List<List<Pairing>> singleRoundRobin(List<Integer> clubIds) {
        if (clubIds.size() < 2) {
            return List.of();
        }
        List<Integer> teams = new ArrayList<>(clubIds);
        if (teams.size() % 2 == 1) {
            teams.add(null); // «пустой» соперник: у напарника свободный тур
        }
        int n = teams.size();
        List<List<Pairing>> rounds = new ArrayList<>();
        for (int r = 0; r < n - 1; r++) {
            List<Pairing> round = new ArrayList<>();
            for (int i = 0; i < n / 2; i++) {
                Integer a = teams.get(i);
                Integer b = teams.get(n - 1 - i);
                if (a == null || b == null) {
                    continue;
                }
                round.add((r + i) % 2 == 0 ? new Pairing(a, b) : new Pairing(b, a));
            }
            rounds.add(List.copyOf(round));
            teams.add(1, teams.remove(n - 1)); // первый остаётся на месте, остальные вращаются
        }
        return rounds;
    }
}
