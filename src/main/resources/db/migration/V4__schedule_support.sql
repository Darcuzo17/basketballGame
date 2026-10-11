-- ============================================================
-- V4. Поддержка расписания и расчёта дня
-- ============================================================

-- В сезоне у каждой лиги один чемпионат
CREATE UNIQUE INDEX ux_competition_league_per_season
    ON competition (season_id, league_id) WHERE league_id IS NOT NULL;

-- Поиск несыгранных матчей конкретного дня
CREATE INDEX idx_match_unplayed_date ON match (match_date) WHERE NOT played;

-- Проверка событий дня для остановки режима «до события»
CREATE INDEX idx_game_event_save_date ON game_event (save_id, event_date);
