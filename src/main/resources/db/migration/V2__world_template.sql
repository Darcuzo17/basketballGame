-- ============================================================
-- V2. Шаблон мира и копирование мира в новую партию
--
-- Шаблон мира — это особое сохранение (is_template = TRUE) без владельца.
-- В нём лежат города, клубы, игроки, тренеры, спонсоры и т.д. в исходном состоянии.
-- При старте новой игры функция clone_world копирует весь шаблон в сохранение игрока.
-- ============================================================

ALTER TABLE game_save ALTER COLUMN user_id DROP NOT NULL;
ALTER TABLE game_save ADD COLUMN is_template BOOLEAN NOT NULL DEFAULT FALSE;

ALTER TABLE game_save ADD CONSTRAINT chk_save_template_owner
    CHECK ((is_template AND user_id IS NULL) OR (NOT is_template AND user_id IS NOT NULL));

-- Шаблон мира может быть только один
CREATE UNIQUE INDEX ux_game_save_single_template ON game_save (is_template) WHERE is_template;

COMMENT ON COLUMN game_save.user_id     IS 'владелец сохранения (пусто только у шаблона мира)';
COMMENT ON COLUMN game_save.is_template IS 'шаблон мира: из него копируется мир при старте новой игры';


-- Копирует мир из шаблона в сохранение игрока и возвращает id его клуба в новом сохранении.
-- Копируются: сезоны и трансферные окна, города, владельцы, клубы, арены и секторы, болельщики,
-- цены билетов, академии, слоты штаба, тренеры, игроки, штаб, контракты, спонсоры и их договоры.
-- Расписание, таблицы и матчи создаёт генератор расписания, они в шаблон не входят.
CREATE OR REPLACE FUNCTION clone_world(p_template INT, p_save INT, p_template_club INT)
RETURNS INT AS $$
DECLARE
    v_new_club INT;
BEGIN
    IF NOT EXISTS (SELECT 1 FROM game_save WHERE id = p_template AND is_template) THEN
        RAISE EXCEPTION 'Сохранение % не является шаблоном мира', p_template;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM game_save WHERE id = p_save AND NOT is_template) THEN
        RAISE EXCEPTION 'Сохранение % не найдено или само является шаблоном', p_save;
    END IF;
    IF EXISTS (SELECT 1 FROM club WHERE save_id = p_save) THEN
        RAISE EXCEPTION 'В сохранении % мир уже создан', p_save;
    END IF;

    -- соответствие старых и новых id; новые id берём из последовательностей заранее
    CREATE TEMP TABLE IF NOT EXISTS world_id_map (
        kind    TEXT NOT NULL,
        old_id  INT  NOT NULL,
        new_id  INT  NOT NULL,
        PRIMARY KEY (kind, old_id)
    ) ON COMMIT DROP;
    TRUNCATE world_id_map;

    INSERT INTO world_id_map SELECT 'season',  id, nextval(pg_get_serial_sequence('season',  'id')) FROM season  WHERE save_id = p_template;
    INSERT INTO world_id_map SELECT 'city',    id, nextval(pg_get_serial_sequence('city',    'id')) FROM city    WHERE save_id = p_template;
    INSERT INTO world_id_map SELECT 'owner',   id, nextval(pg_get_serial_sequence('owner',   'id')) FROM owner   WHERE save_id = p_template;
    INSERT INTO world_id_map SELECT 'club',    id, nextval(pg_get_serial_sequence('club',    'id')) FROM club    WHERE save_id = p_template;
    INSERT INTO world_id_map SELECT 'player',  id, nextval(pg_get_serial_sequence('player',  'id')) FROM player  WHERE save_id = p_template;
    INSERT INTO world_id_map SELECT 'coach',   id, nextval(pg_get_serial_sequence('coach',   'id')) FROM coach   WHERE save_id = p_template;
    INSERT INTO world_id_map SELECT 'staff',   id, nextval(pg_get_serial_sequence('staff',   'id')) FROM staff   WHERE save_id = p_template;
    INSERT INTO world_id_map SELECT 'sponsor', id, nextval(pg_get_serial_sequence('sponsor', 'id')) FROM sponsor WHERE save_id = p_template;
    INSERT INTO world_id_map SELECT 'arena',   a.id, nextval(pg_get_serial_sequence('arena', 'id'))
        FROM arena a JOIN club c ON c.id = a.club_id WHERE c.save_id = p_template;

    INSERT INTO season (id, save_id, year_start, phase, league_application_deadline)
    SELECT m.new_id, p_save, s.year_start, s.phase, s.league_application_deadline
      FROM season s JOIN world_id_map m ON m.kind = 'season' AND m.old_id = s.id
     WHERE s.save_id = p_template;

    INSERT INTO transfer_window (season_id, kind, start_date, end_date)
    SELECT m.new_id, w.kind, w.start_date, w.end_date
      FROM transfer_window w JOIN world_id_map m ON m.kind = 'season' AND m.old_id = w.season_id;

    INSERT INTO city (id, save_id, region_id, name, population, basketball_culture,
                      sport_competition, has_arena, latitude, longitude)
    SELECT m.new_id, p_save, c.region_id, c.name, c.population, c.basketball_culture,
           c.sport_competition, c.has_arena, c.latitude, c.longitude
      FROM city c JOIN world_id_map m ON m.kind = 'city' AND m.old_id = c.id
     WHERE c.save_id = p_template;

    INSERT INTO owner (id, save_id, type, name, expectation_rank, expectation_profit, patience)
    SELECT m.new_id, p_save, o.type, o.name, o.expectation_rank, o.expectation_profit, o.patience
      FROM owner o JOIN world_id_map m ON m.kind = 'owner' AND m.old_id = o.id
     WHERE o.save_id = p_template;

    INSERT INTO club (id, save_id, city_id, league_id, owner_id, name, founded_year, budget, annual_budget,
                      reputation, primary_color, secondary_color, is_real, is_user_created,
                      access_tier, is_top_draw, status)
    SELECT m.new_id, p_save, mc.new_id, c.league_id, mo.new_id, c.name, c.founded_year, c.budget, c.annual_budget,
           c.reputation, c.primary_color, c.secondary_color, c.is_real, c.is_user_created,
           c.access_tier, c.is_top_draw, c.status
      FROM club c
      JOIN world_id_map m  ON m.kind  = 'club' AND m.old_id  = c.id
      JOIN world_id_map mc ON mc.kind = 'city' AND mc.old_id = c.city_id
      LEFT JOIN world_id_map mo ON mo.kind = 'owner' AND mo.old_id = c.owner_id
     WHERE c.save_id = p_template;

    INSERT INTO arena (id, club_id, name, kind, capacity, condition, upkeep_cost, guest_quota_pct)
    SELECT ma.new_id, mc.new_id, a.name, a.kind, a.capacity, a.condition, a.upkeep_cost, a.guest_quota_pct
      FROM arena a
      JOIN world_id_map ma ON ma.kind = 'arena' AND ma.old_id = a.id
      JOIN world_id_map mc ON mc.kind = 'club'  AND mc.old_id = a.club_id;

    INSERT INTO arena_sector (arena_id, name, kind, tier, rows_count, seats_per_row, geometry)
    SELECT ma.new_id, s.name, s.kind, s.tier, s.rows_count, s.seats_per_row, s.geometry
      FROM arena_sector s JOIN world_id_map ma ON ma.kind = 'arena' AND ma.old_id = s.arena_id;

    INSERT INTO fan_base (club_id, size, loyalty, hype, city_share, avg_attendance)
    SELECT mc.new_id, f.size, f.loyalty, f.hype, f.city_share, f.avg_attendance
      FROM fan_base f JOIN world_id_map mc ON mc.kind = 'club' AND mc.old_id = f.club_id;

    INSERT INTO sector_price (club_id, kind, price)
    SELECT mc.new_id, p.kind, p.price
      FROM sector_price p JOIN world_id_map mc ON mc.kind = 'club' AND mc.old_id = p.club_id;

    INSERT INTO youth_academy (club_id, type, level, talent_ceiling, yearly_cost)
    SELECT mc.new_id, y.type, y.level, y.talent_ceiling, y.yearly_cost
      FROM youth_academy y JOIN world_id_map mc ON mc.kind = 'club' AND mc.old_id = y.club_id;

    INSERT INTO club_staff_slot (club_id, role, slots_open)
    SELECT mc.new_id, s.role, s.slots_open
      FROM club_staff_slot s JOIN world_id_map mc ON mc.kind = 'club' AND mc.old_id = s.club_id;

    INSERT INTO club_league_membership (club_id, season_id, league_id)
    SELECT mc.new_id, ms.new_id, k.league_id
      FROM club_league_membership k
      JOIN world_id_map mc ON mc.kind = 'club'   AND mc.old_id = k.club_id
      JOIN world_id_map ms ON ms.kind = 'season' AND ms.old_id = k.season_id;

    INSERT INTO coach (id, save_id, club_id, full_name, birth_date, tactics_skill, youth_skill,
                       motivation_skill, reputation, preferred_style)
    SELECT m.new_id, p_save, mc.new_id, c.full_name, c.birth_date, c.tactics_skill, c.youth_skill,
           c.motivation_skill, c.reputation, c.preferred_style
      FROM coach c
      JOIN world_id_map m ON m.kind = 'coach' AND m.old_id = c.id
      LEFT JOIN world_id_map mc ON mc.kind = 'club' AND mc.old_id = c.club_id
     WHERE c.save_id = p_template;

    INSERT INTO player (id, save_id, club_id, full_name, birth_date, nationality, height_cm, position,
                        attack, defense, physical, basketball_iq, potential, form, fatigue, morale,
                        injury_until, is_foreign, is_youth, source, academy_status)
    SELECT m.new_id, p_save, mc.new_id, p.full_name, p.birth_date, p.nationality, p.height_cm, p.position,
           p.attack, p.defense, p.physical, p.basketball_iq, p.potential, p.form, p.fatigue, p.morale,
           p.injury_until, p.is_foreign, p.is_youth, p.source, p.academy_status
      FROM player p
      JOIN world_id_map m ON m.kind = 'player' AND m.old_id = p.id
      LEFT JOIN world_id_map mc ON mc.kind = 'club' AND mc.old_id = p.club_id
     WHERE p.save_id = p_template;

    INSERT INTO staff (id, save_id, club_id, role, full_name, skill, salary)
    SELECT m.new_id, p_save, mc.new_id, s.role, s.full_name, s.skill, s.salary
      FROM staff s
      JOIN world_id_map m ON m.kind = 'staff' AND m.old_id = s.id
      LEFT JOIN world_id_map mc ON mc.kind = 'club' AND mc.old_id = s.club_id
     WHERE s.save_id = p_template;

    INSERT INTO contract (save_id, club_id, player_id, coach_id, staff_id, salary, start_date, end_date,
                          bonus_per_win, release_clause)
    SELECT p_save, mc.new_id, mp.new_id, mco.new_id, ms.new_id, k.salary, k.start_date, k.end_date,
           k.bonus_per_win, k.release_clause
      FROM contract k
      JOIN world_id_map mc ON mc.kind = 'club' AND mc.old_id = k.club_id
      LEFT JOIN world_id_map mp  ON mp.kind  = 'player' AND mp.old_id  = k.player_id
      LEFT JOIN world_id_map mco ON mco.kind = 'coach'  AND mco.old_id = k.coach_id
      LEFT JOIN world_id_map ms  ON ms.kind  = 'staff'  AND ms.old_id  = k.staff_id
     WHERE k.save_id = p_template;

    INSERT INTO sponsor (id, save_id, name, kind, category, min_reputation, min_city_population, base_amount)
    SELECT m.new_id, p_save, s.name, s.kind, s.category, s.min_reputation, s.min_city_population, s.base_amount
      FROM sponsor s JOIN world_id_map m ON m.kind = 'sponsor' AND m.old_id = s.id
     WHERE s.save_id = p_template;

    INSERT INTO sponsor_deal (club_id, sponsor_id, slot, amount_per_year, bonus_amount, penalty_amount,
                              start_date, end_date, min_rank, min_attendance, is_mandatory, status,
                              offer_expires_on)
    SELECT mc.new_id, msp.new_id, d.slot, d.amount_per_year, d.bonus_amount, d.penalty_amount,
           d.start_date, d.end_date, d.min_rank, d.min_attendance, d.is_mandatory, d.status,
           d.offer_expires_on
      FROM sponsor_deal d
      JOIN world_id_map mc  ON mc.kind  = 'club'    AND mc.old_id  = d.club_id
      JOIN world_id_map msp ON msp.kind = 'sponsor' AND msp.old_id = d.sponsor_id;

    SELECT new_id INTO v_new_club FROM world_id_map WHERE kind = 'club' AND old_id = p_template_club;
    IF v_new_club IS NULL THEN
        RAISE EXCEPTION 'Клуб % не найден в шаблоне мира', p_template_club;
    END IF;

    UPDATE game_save s
       SET user_club_id = v_new_club,
           game_date = t.game_date
      FROM game_save t
     WHERE s.id = p_save AND t.id = p_template;

    INSERT INTO manager_career (save_id, club_id, from_date, end_reason)
    SELECT p_save, v_new_club, game_date, 'active' FROM game_save WHERE id = p_save;

    RETURN v_new_club;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION clone_world(INT, INT, INT) IS
    'Копирует мир из шаблона (первый аргумент) в сохранение игрока (второй) и возвращает id выбранного клуба в новом сохранении (третий аргумент — id клуба в шаблоне)';
