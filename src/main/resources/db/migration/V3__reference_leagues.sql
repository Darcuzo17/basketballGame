-- ============================================================
-- V3. Лиги и их правила
-- ВНИМАНИЕ: значения примерные, их нужно уточнить по реальным регламентам:
--   * название и состав лиги ниже Суперлиги;
--   * число команд, лимиты зарплат и легионеров (пока не заданы);
--   * зоны таблицы, требования к арене, балансу и репутации.
-- ============================================================

INSERT INTO league (name, tier, teams_count) VALUES
    ('Лига ВТБ',              1, 12),
    ('Суперлига',             2, 12),
    ('Лига ниже Суперлиги',   3, 12);

INSERT INTO league_rule (league_id, playoff_spots, promotion_spots, relegation_spots, series_length)
SELECT id, 8, CASE WHEN tier = 1 THEN 0 ELSE 1 END, CASE WHEN tier = 3 THEN 0 ELSE 1 END, 3
  FROM league;

INSERT INTO league_requirement (league_id, min_arena_capacity, min_balance, min_roster, min_reputation)
SELECT id,
       CASE tier WHEN 1 THEN 3000 WHEN 2 THEN 1500 ELSE 500 END,
       0,
       12,
       CASE tier WHEN 1 THEN 50 WHEN 2 THEN 30 ELSE 0 END
  FROM league;
