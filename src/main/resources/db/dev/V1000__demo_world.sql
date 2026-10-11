-- ============================================================
-- V1000. ДЕМО-мир для разработки (подключается только профилем dev).
-- Клубы вымышленные, города настоящие, цифры случайные, но повторяемые (setseed).
-- Заменяется реальным наполнением справочников: регионы, клубы, бюджеты, составы.
-- ============================================================

INSERT INTO region (name, population, sport_support) VALUES
    ('Москва', 13000000, 70), ('Санкт-Петербург', 5600000, 65), ('Республика Татарстан', 4000000, 75),
    ('Краснодарский край', 5700000, 55), ('Свердловская область', 4300000, 50), ('Пермский край', 2600000, 55),
    ('Новосибирская область', 2800000, 50), ('Красноярский край', 2800000, 50), ('Самарская область', 3100000, 50),
    ('Нижегородская область', 3200000, 50), ('Хабаровский край', 1300000, 45), ('Калининградская область', 1000000, 45),
    ('Иркутская область', 2300000, 40), ('Мурманская область', 650000, 40);

INSERT INTO game_save (user_id, name, game_date, is_template)
VALUES (NULL, 'Шаблон мира (демо)', DATE '2026-07-01', TRUE);

DO $$
DECLARE
    tpl        INT;
    v_season   INT;
    rec        RECORD;
    srole      RECORD;
    v_region   INT;
    v_league   INT;
    v_city     INT;
    v_owner    INT;
    v_club     INT;
    v_arena    INT;
    v_coach    INT;
    v_player   INT;
    v_staff    INT;
    v_sponsor  INT;
    n          INT := 0;
    i          INT;
    positions  TEXT[] := ARRAY['PG','SG','SF','PF','C'];
    heights    INT[]  := ARRAY[185, 192, 199, 205, 211];
    colors     TEXT[] := ARRAY['#c92a2a','#1864ab','#2b8a3e','#e67700','#5f3dc4','#0b7285','#a61e4d','#364fc7'];
    v_target   INT;
    v_parterre INT;
    v_vip      INT;
    v_std_seats INT;
    base_attr  INT;
    v_attr     INT;
    v_pos      INT;
    v_salary   NUMERIC;
BEGIN
    PERFORM setseed(0.42);
    SELECT id INTO tpl FROM game_save WHERE is_template;

    INSERT INTO season (save_id, year_start, phase, league_application_deadline)
    VALUES (tpl, 2026, 'offseason', DATE '2026-09-15') RETURNING id INTO v_season;
    INSERT INTO transfer_window (season_id, kind, start_date, end_date) VALUES
        (v_season, 'summer', DATE '2026-07-01', DATE '2026-09-15'),
        (v_season, 'winter', DATE '2027-01-15', DATE '2027-02-15');

    FOR rec IN
        SELECT * FROM (VALUES
            ('Москва',          'Москва',                  13000000, 55.7558,  37.6173, 1, 'private', 'Демо Москва-1',          false, true,  80,  900, 60),
            ('Москва',          'Москва',                  13000000, 55.7558,  37.6173, 1, 'state',   'Демо Москва-2',          true,  true,  90, 1200, 60),
            ('Санкт-Петербург', 'Санкт-Петербург',          5600000, 59.9343,  30.3361, 1, 'state',   'Демо Санкт-Петербург',   false, false, 70,  700, 55),
            ('Казань',          'Республика Татарстан',     1300000, 55.7961,  49.1064, 1, 'state',   'Демо Казань',            false, true,  75,  800, 65),
            ('Краснодар',       'Краснодарский край',       1100000, 45.0355,  38.9753, 1, 'private', 'Демо Краснодар',         false, false, 65,  500, 60),
            ('Екатеринбург',    'Свердловская область',     1500000, 56.8389,  60.6057, 2, 'private', 'Демо Екатеринбург',      false, false, 50,  200, 50),
            ('Пермь',           'Пермский край',            1000000, 58.0105,  56.2502, 2, 'state',   'Демо Пермь',             false, false, 45,  180, 55),
            ('Новосибирск',     'Новосибирская область',    1600000, 55.0084,  82.9357, 2, 'private', 'Демо Новосибирск',       false, false, 48,  190, 50),
            ('Красноярск',      'Красноярский край',        1200000, 56.0153,  92.8932, 2, 'state',   'Демо Красноярск',        false, false, 47,  185, 45),
            ('Самара',          'Самарская область',        1150000, 53.1959,  50.1002, 2, 'private', 'Демо Самара',            false, false, 44,  170, 50),
            ('Нижний Новгород', 'Нижегородская область',    1200000, 56.2965,  43.9361, 2, 'state',   'Демо Нижний Новгород',   false, false, 43,  175, 50),
            ('Хабаровск',       'Хабаровский край',          620000, 48.4802, 135.0719, 3, 'state',   'Демо Хабаровск',         false, false, 30,   60, 40),
            ('Калининград',     'Калининградская область',   490000, 54.7104,  20.4522, 3, 'private', 'Демо Калининград',       false, false, 28,   55, 45),
            ('Иркутск',         'Иркутская область',         620000, 52.2870, 104.3050, 3, 'private', 'Демо Иркутск',           false, false, 26,   50, 35),
            ('Мурманск',        'Мурманская область',        270000, 68.9585,  33.0827, 3, 'state',   'Демо Мурманск',          false, false, 25,   45, 35)
        ) AS d(city_name, region_name, population, lat, lon, tier, owner_type, club_name, locked, top_draw,
               reputation, budget_m, culture)
    LOOP
        n := n + 1;
        SELECT id INTO v_region FROM region WHERE name = rec.region_name;
        SELECT id INTO v_league FROM league WHERE tier = rec.tier;

        SELECT id INTO v_city FROM city WHERE save_id = tpl AND name = rec.city_name;
        IF NOT FOUND THEN
            INSERT INTO city (save_id, region_id, name, population, basketball_culture, sport_competition,
                              has_arena, latitude, longitude)
            VALUES (tpl, v_region, rec.city_name, rec.population, rec.culture, 50, TRUE, rec.lat, rec.lon)
            RETURNING id INTO v_city;
        END IF;

        INSERT INTO owner (save_id, type, name, expectation_rank, expectation_profit, patience)
        VALUES (tpl, rec.owner_type,
                CASE rec.owner_type WHEN 'state' THEN 'Учредитель: ' || rec.region_name
                                    ELSE 'Частный владелец клуба ' || rec.club_name END,
                CASE rec.tier WHEN 1 THEN 4 WHEN 2 THEN 6 ELSE 8 END, 0, 70)
        RETURNING id INTO v_owner;

        INSERT INTO club (save_id, city_id, league_id, owner_id, name, founded_year, budget, annual_budget,
                          reputation, primary_color, secondary_color, is_real, access_tier, is_top_draw, status)
        VALUES (tpl, v_city, v_league, v_owner, rec.club_name, 1950 + n * 3, rec.budget_m * 1000000,
                rec.budget_m * 1000000, rec.reputation, colors[1 + n % 8], '#ffffff', TRUE,
                CASE WHEN rec.locked THEN 'locked' ELSE 'open' END, rec.top_draw, 'active')
        RETURNING id INTO v_club;

        INSERT INTO club_league_membership (club_id, season_id, league_id) VALUES (v_club, v_season, v_league);

        -- арена: вместимость по лиге, партер с Суперлиги, VIP только в высшей лиге
        v_target   := CASE rec.tier WHEN 1 THEN 5000 WHEN 2 THEN 2500 ELSE 1000 END;
        v_parterre := CASE WHEN rec.tier <= 2 THEN 200 ELSE 0 END;
        v_vip      := CASE WHEN rec.tier = 1 THEN 40 ELSE 0 END;
        v_std_seats := (v_target - v_parterre - v_vip) / 2 / 20;   -- мест в ряду; 20 рядов, два сектора

        INSERT INTO arena (club_id, name, kind, capacity, condition, upkeep_cost, guest_quota_pct)
        VALUES (v_club, 'Арена ' || rec.city_name, 'arena', v_target, 80, v_target * 400, 5)
        RETURNING id INTO v_arena;
        INSERT INTO arena_sector (arena_id, name, kind, tier, rows_count, seats_per_row) VALUES
            (v_arena, 'Сектор A', 'standard', 1, 20, v_std_seats),
            (v_arena, 'Сектор B', 'standard', 1, 20, v_std_seats);
        IF v_parterre > 0 THEN
            INSERT INTO arena_sector (arena_id, name, kind, tier, rows_count, seats_per_row)
            VALUES (v_arena, 'Партер', 'parterre', 1, 10, 20);
        END IF;
        IF v_vip > 0 THEN
            INSERT INTO arena_sector (arena_id, name, kind, tier, rows_count, seats_per_row)
            VALUES (v_arena, 'VIP', 'vip', 1, 2, 20);
        END IF;
        UPDATE arena SET capacity = (SELECT SUM(capacity) FROM arena_sector WHERE arena_id = v_arena)
         WHERE id = v_arena;

        INSERT INTO sector_price (club_id, kind, price)
        VALUES (v_club, 'standard', CASE rec.tier WHEN 1 THEN 500 WHEN 2 THEN 300 ELSE 150 END);
        IF v_parterre > 0 THEN
            INSERT INTO sector_price VALUES (v_club, 'parterre', CASE rec.tier WHEN 1 THEN 1200 ELSE 700 END);
        END IF;
        IF v_vip > 0 THEN
            INSERT INTO sector_price VALUES (v_club, 'vip', 4000);
        END IF;

        INSERT INTO fan_base (club_id, size, loyalty, hype, city_share, avg_attendance)
        VALUES (v_club, (rec.population * rec.culture / 2000)::INT, 50, 10, 100, (v_target * 0.6)::INT);

        INSERT INTO youth_academy (club_id, type, level, talent_ceiling, yearly_cost)
        SELECT v_club,
               CASE WHEN rec.population < 700000 THEN 'school' WHEN rec.population < 2000000 THEN 'club' ELSE 'pro' END,
               CASE WHEN rec.population < 700000 THEN 1 WHEN rec.population < 2000000 THEN 2 ELSE 3 END,
               CASE WHEN rec.population < 700000 THEN 40 WHEN rec.population < 2000000 THEN 55 ELSE 70 END,
               CASE WHEN rec.population < 700000 THEN 5000000 WHEN rec.population < 2000000 THEN 10000000 ELSE 15000000 END;

        INSERT INTO club_staff_slot (club_id, role, slots_open)
        SELECT v_club, role, 1 FROM staff_role;

        -- главный тренер
        base_attr := 70 - (rec.tier - 1) * 15;
        INSERT INTO coach (save_id, club_id, full_name, birth_date, tactics_skill, youth_skill,
                           motivation_skill, reputation, preferred_style)
        VALUES (tpl, v_club, 'Тренер ' || rec.club_name, DATE '1965-01-01' + (random() * 6000)::INT,
                LEAST(100, (base_attr + random() * 15)::INT), LEAST(100, (base_attr + random() * 15)::INT),
                LEAST(100, (base_attr + random() * 15)::INT), rec.reputation,
                (ARRAY['быстрый','оборонительный','позиционный'])[1 + n % 3])
        RETURNING id INTO v_coach;
        INSERT INTO contract (save_id, club_id, coach_id, salary, start_date, end_date, bonus_per_win)
        VALUES (tpl, v_club, v_coach, rec.budget_m * 40000, DATE '2026-07-01', DATE '2028-06-30', 0);

        -- штаб: по одному сотруднику каждой роли
        FOR srole IN SELECT role, title FROM staff_role LOOP
            INSERT INTO staff (save_id, club_id, role, full_name, skill, salary)
            VALUES (tpl, v_club, srole.role, srole.title || ' ' || rec.club_name,
                    LEAST(100, (base_attr - 10 + random() * 20)::INT), rec.budget_m * 10000)
            RETURNING id INTO v_staff;
            INSERT INTO contract (save_id, club_id, staff_id, salary, start_date, end_date)
            VALUES (tpl, v_club, v_staff, rec.budget_m * 10000, DATE '2026-07-01', DATE '2027-06-30');
        END LOOP;

        -- 12 игроков
        base_attr := 65 - (rec.tier - 1) * 13;
        FOR i IN 1..12 LOOP
            v_pos := 1 + (i - 1) % 5;
            v_attr := base_attr;
            INSERT INTO player (save_id, club_id, full_name, birth_date, nationality, height_cm, position,
                                attack, defense, physical, basketball_iq, potential, form, fatigue, morale,
                                is_foreign, is_youth, source)
            VALUES (tpl, v_club, 'Игрок ' || n || '-' || i, DATE '1988-01-01' + (random() * 7000)::INT,
                    CASE WHEN rec.tier <= 2 AND i <= 2 THEN 'США' ELSE 'Россия' END,
                    heights[v_pos] + (random() * 6)::INT, positions[v_pos],
                    LEAST(100, (v_attr + random() * 20 - 5)::INT), LEAST(100, (v_attr + random() * 20 - 5)::INT),
                    LEAST(100, (v_attr + random() * 20 - 5)::INT), LEAST(100, (v_attr + random() * 20 - 5)::INT),
                    LEAST(100, (v_attr + 5 + random() * 20)::INT), (50 + random() * 30)::INT,
                    (random() * 20)::INT, (50 + random() * 30)::INT,
                    (rec.tier <= 2 AND i <= 2), FALSE, 'real')
            RETURNING id INTO v_player;
            v_salary := (1 + random()) * CASE rec.tier WHEN 1 THEN 8000000 WHEN 2 THEN 2500000 ELSE 800000 END;
            INSERT INTO contract (save_id, club_id, player_id, salary, start_date, end_date, bonus_per_win)
            VALUES (tpl, v_club, v_player, round(v_salary), DATE '2026-07-01',
                    DATE '2027-06-30' + ((random() * 2)::INT * 365), round(v_salary / 100));
        END LOOP;

        -- спонсор: у госклуба обязательный городской или краевой, у частного коммерческий
        INSERT INTO sponsor (save_id, name, kind, category, min_reputation, base_amount)
        VALUES (tpl,
                CASE rec.owner_type WHEN 'state' THEN 'Правительство: ' || rec.region_name
                                    ELSE 'Демо Спонсор ' || rec.club_name END,
                CASE WHEN rec.owner_type = 'state' THEN (CASE WHEN rec.tier = 1 THEN 'city' ELSE 'region' END)
                     ELSE 'commercial' END,
                CASE rec.owner_type WHEN 'state' THEN 'власть' ELSE 'торговля' END,
                0, rec.budget_m * 350000)
        RETURNING id INTO v_sponsor;
        INSERT INTO sponsor_deal (club_id, sponsor_id, slot, amount_per_year, start_date, end_date, is_mandatory, status)
        VALUES (v_club, v_sponsor, 'title', rec.budget_m * 350000, DATE '2026-07-01', DATE '2028-06-30',
                rec.owner_type = 'state', 'active');
    END LOOP;

    -- города, где несколько клубов: делим внимание поровну
    UPDATE fan_base f SET city_share = ROUND(100.0 / cnt.n, 2)
      FROM club c
      JOIN (SELECT city_id, COUNT(*) n FROM club WHERE save_id = tpl GROUP BY city_id) cnt ON cnt.city_id = c.city_id
     WHERE f.club_id = c.id AND c.save_id = tpl;

    -- 24 свободных агента: из них новый клуб набирает недостающих игроков
    FOR i IN 1..24 LOOP
        v_pos := 1 + (i - 1) % 5;
        INSERT INTO player (save_id, club_id, full_name, birth_date, nationality, height_cm, position,
                            attack, defense, physical, basketball_iq, potential, form, fatigue, morale,
                            is_foreign, is_youth, source)
        VALUES (tpl, NULL, 'Свободный агент ' || i, DATE '1988-01-01' + (random() * 7000)::INT, 'Россия',
                heights[v_pos] + (random() * 6)::INT, positions[v_pos],
                (30 + random() * 25)::INT, (30 + random() * 25)::INT, (30 + random() * 25)::INT,
                (30 + random() * 25)::INT, (40 + random() * 30)::INT, 60, 0, 60, FALSE, FALSE, 'market');
    END LOOP;
END
$$;
