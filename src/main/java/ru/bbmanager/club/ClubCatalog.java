package ru.bbmanager.club;

import java.util.List;
import java.util.Map;

/** Источник клубов для экрана выбора. Позже заменится реализацией на базе шаблона мира в БД. */
public interface ClubCatalog {

    List<MapClub> findAll();

    /** Названия лиг по уровню: 1 — высшая. */
    Map<Integer, String> leagueNames();
}
