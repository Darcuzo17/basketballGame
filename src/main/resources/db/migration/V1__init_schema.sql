-- ============================================================
-- Баскетбольный менеджер: итоговая схема БД
-- СУБД: PostgreSQL 14+
--
-- Соглашения:
--   * справочники и настройки общие для всех сохранений;
--   * всё, что меняется по ходу партии, привязано к save_id;
--   * деньги в рублях, шкалы 0-100 (если не сказано иное);
--   * уровень лиги: 1 — высшая, чем больше число, тем ниже;
--   * подписи к таблицам и колонкам лежат в блоке COMMENT ON в конце файла;
--   * значения в seed-блоке примерные, их подберёте при настройке баланса.
-- ============================================================


-- ============================================================
-- 1. СПРАВОЧНИКИ И НАСТРОЙКИ (общие для всех сохранений)
-- ============================================================

-- @table: Регионы (края, области) России
CREATE TABLE region (
    id                 SERIAL PRIMARY KEY,   -- идентификатор региона
    name               TEXT NOT NULL UNIQUE, -- название региона
    population         INT,                  -- население региона, чел.
    income_per_capita  NUMERIC(12,2),        -- средний доход на человека, руб. в месяц
    sport_support      SMALLINT CHECK (sport_support BETWEEN 0 AND 100) -- уровень поддержки спорта властью региона
);

-- @table: Лиги: Лига ВТБ, Суперлига, лига ниже Суперлиги
CREATE TABLE league (
    id             SERIAL PRIMARY KEY,   -- идентификатор лиги
    name           TEXT NOT NULL,        -- название лиги
    tier           SMALLINT NOT NULL,    -- уровень лиги: 1 — высшая
    teams_count    SMALLINT NOT NULL,    -- число команд в лиге
    salary_cap     NUMERIC(14,2),        -- потолок фонда зарплат клуба за сезон
    salary_floor   NUMERIC(14,2),        -- нижняя граница фонда зарплат
    foreign_limit  SMALLINT              -- максимум легионеров в заявке
);

-- @table: Правила лиги: зоны таблицы и формат серий плей-офф
CREATE TABLE league_rule (
    league_id         INT PRIMARY KEY REFERENCES league(id) ON DELETE CASCADE, -- лига
    playoff_spots     SMALLINT NOT NULL DEFAULT 8,  -- сколько команд выходит в плей-офф
    promotion_spots   SMALLINT NOT NULL DEFAULT 0,  -- сколько мест дают право на повышение
    relegation_spots  SMALLINT NOT NULL DEFAULT 0,  -- сколько мест вылетает вниз
    series_length     SMALLINT NOT NULL DEFAULT 5   -- серия плей-офф идёт до стольких побед
);

-- @table: Требования лиги к клубу для допуска и повышения
CREATE TABLE league_requirement (
    league_id           INT PRIMARY KEY REFERENCES league(id) ON DELETE CASCADE, -- лига, в которую хотят войти
    min_arena_capacity  INT NOT NULL DEFAULT 0,          -- минимальная вместимость арены
    min_balance         NUMERIC(14,2) NOT NULL DEFAULT 0, -- минимальный баланс клуба
    min_roster          SMALLINT NOT NULL DEFAULT 12,    -- минимальный размер состава
    min_reputation      SMALLINT NOT NULL DEFAULT 0      -- минимальная репутация клуба
);

-- @table: Кубки: Кубок России, Винлайн кубок
CREATE TABLE cup (
    id          SERIAL PRIMARY KEY,   -- идентификатор кубка
    name        TEXT NOT NULL,        -- название кубка
    format      TEXT,                 -- формат розыгрыша (описание)
    prize_fund  NUMERIC(14,2)         -- призовой фонд
);

-- @table: Глобальные настройки баланса игры (ключ — значение)
CREATE TABLE game_config (
    key          TEXT PRIMARY KEY,    -- ключ настройки
    value        NUMERIC NOT NULL,    -- числовое значение
    description  TEXT                 -- что настройка означает
);

-- @table: Роли штаба и предельное число слотов на роль
CREATE TABLE staff_role (
    role       TEXT PRIMARY KEY,                -- код роли: doctor, scout, marketing, fitness, pr
    title      TEXT NOT NULL,                   -- название роли для интерфейса
    max_slots  SMALLINT NOT NULL DEFAULT 3      -- максимум слотов на роль (1 для ролей с единственным человеком)
);

-- @table: Условия открытия дополнительных слотов штаба
CREATE TABLE slot_unlock_rule (
    role         TEXT NOT NULL REFERENCES staff_role(role), -- роль штаба
    slot_number  SMALLINT NOT NULL CHECK (slot_number BETWEEN 2 AND 3), -- номер открываемого слота
    conditions   JSONB NOT NULL,                -- условия, например {"min_reputation":60,"min_league_tier":2,"min_years":3}
    PRIMARY KEY (role, slot_number)
);

-- @table: Условия открытия типов мест на арене (партер, VIP)
CREATE TABLE sector_unlock_rule (
    kind        TEXT PRIMARY KEY CHECK (kind IN ('standard','parterre','vip')), -- тип мест
    conditions  JSONB NOT NULL     -- условия открытия, например {"max_league_tier":2,"min_years":3,"min_reputation":60}
);

-- @table: Ограничения арены по репутации клуба (число ярусов и вместимость)
CREATE TABLE arena_limit_rule (
    min_reputation  SMALLINT PRIMARY KEY,   -- с какой репутации действует строка
    max_tiers       SMALLINT NOT NULL,      -- максимум ярусов
    max_capacity    INT NOT NULL            -- максимум посадочных мест
);

-- @table: Шаблоны форм арены для конструктора
CREATE TABLE arena_template (
    id            SERIAL PRIMARY KEY,   -- идентификатор шаблона
    name          TEXT NOT NULL,        -- название формы (прямоугольная, овальная, подкова)
    sector_slots  JSONB NOT NULL        -- слоты секторов шаблона: положение на плане и максимумы
);

-- @table: Автонадбавки к цене билета
CREATE TABLE ticket_markup_rule (
    reason      TEXT PRIMARY KEY CHECK (reason IN ('top_opponent','playoff')), -- причина надбавки
    multiplier  NUMERIC(4,2) NOT NULL   -- множитель к цене
);

-- @table: Коэффициент спроса по дням недели (билеты и выезды болельщиков)
CREATE TABLE day_demand_factor (
    weekday  SMALLINT PRIMARY KEY CHECK (weekday BETWEEN 1 AND 7), -- день недели: 1 — понедельник
    factor   NUMERIC(4,2) NOT NULL     -- множитель спроса
);

-- @table: Тарифы транспорта для выезда болельщиков
CREATE TABLE transport_rate (
    transport        TEXT PRIMARY KEY CHECK (transport IN ('bus','train','plane')), -- вид транспорта
    cost_per_km      NUMERIC(8,2) NOT NULL,  -- стоимость за километр на человека
    min_km           INT NOT NULL DEFAULT 0, -- минимальное расстояние, на котором вариант доступен
    max_km           INT,                    -- максимальное расстояние (пусто — без ограничения)
    lodging_from_km  INT                     -- с какого расстояния нужен ночлег
);

-- @table: Прирост или падение ажиотажа по причинам
CREATE TABLE hype_rule (
    reason  TEXT PRIMARY KEY,     -- причина: win, win_streak, upset_win, loss, star_signing, playoff, campaign
    delta   SMALLINT NOT NULL     -- изменение ажиотажа (может быть отрицательным)
);

-- @table: Каталог акций и маркетинговых кампаний
CREATE TABLE campaign_type (
    id               SERIAL PRIMARY KEY,           -- идентификатор типа акции
    name             TEXT NOT NULL,                -- название акции
    base_cost        NUMERIC(12,2) NOT NULL,       -- базовая стоимость
    duration_days    SMALLINT NOT NULL,            -- длительность, дней
    cooldown_days    SMALLINT NOT NULL DEFAULT 30, -- перерыв перед повтором, дней
    effect_loyalty   SMALLINT DEFAULT 0,           -- ожидаемый прирост лояльности
    effect_hype      SMALLINT DEFAULT 0,           -- ожидаемый прирост ажиотажа
    effect_base_pct  NUMERIC(5,2) DEFAULT 0,       -- ожидаемый рост базы болельщиков, %
    effect_culture   NUMERIC(5,3) DEFAULT 0,       -- ожидаемый рост культуры города
    needs_marketing  BOOLEAN DEFAULT FALSE         -- нужен ли менеджер по маркетингу
);

-- @table: Уровни молодёжной академии: размер набора и стоимость улучшения
CREATE TABLE academy_level_rule (
    level         SMALLINT PRIMARY KEY,            -- уровень академии
    intake_size   SMALLINT NOT NULL,               -- сколько воспитанников в ежегодном наборе
    talent_boost  SMALLINT NOT NULL DEFAULT 0,     -- бонус к потолку талантов
    upgrade_cost  NUMERIC(12,2) NOT NULL           -- стоимость перехода на этот уровень
);

-- @table: Слоты спонсоров по типу владельца клуба
CREATE TABLE sponsor_slot_rule (
    owner_type  TEXT NOT NULL CHECK (owner_type IN ('private','state','mixed')), -- тип владельца
    slot        TEXT NOT NULL CHECK (slot IN ('title','partner')), -- title — титульный, partner — смежный
    max_slots   SMALLINT NOT NULL,                  -- максимум договоров этого слота
    PRIMARY KEY (owner_type, slot)
);


-- ============================================================
-- 2. ПОЛЬЗОВАТЕЛИ И СОХРАНЕНИЯ
-- ============================================================

-- @table: Аккаунты игроков
CREATE TABLE app_user (
    id                 SERIAL PRIMARY KEY,   -- идентификатор пользователя
    email              TEXT UNIQUE,          -- email (пусто у гостей и при входе через соцсети)
    password_hash      TEXT,                 -- хэш пароля (пусто при входе через соцсети)
    email_verified_at  TIMESTAMPTZ,          -- когда подтверждён email (пусто — не подтверждён)
    is_guest           BOOLEAN NOT NULL DEFAULT FALSE, -- гостевой аккаунт (режим появится позже)
    created_at         TIMESTAMPTZ NOT NULL DEFAULT now() -- дата регистрации
);

-- @table: Способы входа через внешние сервисы (VK, Яндекс, Telegram)
CREATE TABLE auth_identity (
    id            SERIAL PRIMARY KEY,   -- идентификатор записи
    user_id       INT NOT NULL REFERENCES app_user(id) ON DELETE CASCADE, -- пользователь
    provider      TEXT NOT NULL CHECK (provider IN ('vk','yandex','telegram')), -- внешний сервис
    provider_uid  TEXT NOT NULL,        -- идентификатор пользователя во внешнем сервисе
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now(), -- когда привязан
    UNIQUE (provider, provider_uid)
);

-- @table: Токены подтверждения email
CREATE TABLE email_verification (
    id          SERIAL PRIMARY KEY,     -- идентификатор записи
    user_id     INT NOT NULL REFERENCES app_user(id) ON DELETE CASCADE, -- пользователь
    token_hash  TEXT NOT NULL,          -- хэш токена из письма
    expires_at  TIMESTAMPTZ NOT NULL,   -- срок действия токена
    used_at     TIMESTAMPTZ             -- когда использован (пусто — не использован)
);

-- @table: Сохранения партий (до 5 на аккаунт, только автосохранение)
CREATE TABLE game_save (
    id                  SERIAL PRIMARY KEY,   -- идентификатор сохранения
    user_id             INT NOT NULL REFERENCES app_user(id) ON DELETE CASCADE, -- владелец сохранения
    name                TEXT NOT NULL,        -- название сохранения
    game_date           DATE NOT NULL,        -- текущая игровая дата
    user_club_id        INT,                  -- клуб, которым управляет игрок (FK добавлен ниже)
    manager_reputation  SMALLINT NOT NULL DEFAULT 30 CHECK (manager_reputation BETWEEN 0 AND 100), -- репутация менеджера
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(), -- когда создано
    last_played_at      TIMESTAMPTZ NOT NULL DEFAULT now()  -- когда игрок заходил в последний раз
);

-- @table: Игровые сезоны в рамках сохранения
CREATE TABLE season (
    id                           SERIAL PRIMARY KEY,   -- идентификатор сезона
    save_id                      INT NOT NULL REFERENCES game_save(id) ON DELETE CASCADE, -- сохранение
    year_start                   SMALLINT NOT NULL,    -- год начала сезона
    phase                        TEXT NOT NULL CHECK (phase IN ('offseason','regular','playoff','finished')), -- текущая фаза сезона
    league_application_deadline  DATE,                 -- крайний срок подачи заявки в лигу
    UNIQUE (save_id, year_start)
);

-- @table: Трансферные окна (летнее длинное, зимнее короткое)
CREATE TABLE transfer_window (
    id          SERIAL PRIMARY KEY,   -- идентификатор окна
    season_id   INT NOT NULL REFERENCES season(id) ON DELETE CASCADE, -- сезон
    kind        TEXT NOT NULL CHECK (kind IN ('summer','winter')), -- вид окна
    start_date  DATE NOT NULL,        -- дата открытия
    end_date    DATE NOT NULL,        -- дата закрытия
    UNIQUE (season_id, kind)
);


-- ============================================================
-- 3. МИР: ГОРОДА, ВЛАДЕЛЬЦЫ, КЛУБЫ, АРЕНЫ
-- ============================================================

-- @table: Города в рамках сохранения
CREATE TABLE city (
    id                  SERIAL PRIMARY KEY,   -- идентификатор города
    save_id             INT NOT NULL REFERENCES game_save(id) ON DELETE CASCADE, -- сохранение
    region_id           INT NOT NULL REFERENCES region(id), -- регион
    name                TEXT NOT NULL,        -- название города
    population          INT NOT NULL,         -- население, чел.
    basketball_culture  NUMERIC(5,2) NOT NULL CHECK (basketball_culture BETWEEN 0 AND 100), -- культура баскетбола (растёт медленно)
    sport_competition   SMALLINT CHECK (sport_competition BETWEEN 0 AND 100), -- конкуренция других видов спорта и развлечений
    has_arena           BOOLEAN NOT NULL DEFAULT FALSE, -- есть ли в городе арена
    latitude            NUMERIC(9,6),         -- широта (для карты и расчёта расстояний)
    longitude           NUMERIC(9,6)          -- долгота
);

-- @table: История культуры баскетбола города по сезонам
CREATE TABLE city_culture_history (
    city_id    INT NOT NULL REFERENCES city(id) ON DELETE CASCADE, -- город
    season_id  INT NOT NULL REFERENCES season(id) ON DELETE CASCADE, -- сезон
    culture    NUMERIC(5,2) NOT NULL,   -- значение культуры на конец сезона
    PRIMARY KEY (city_id, season_id)
);

-- @table: Владельцы клубов (государство или частные)
CREATE TABLE owner (
    id                  SERIAL PRIMARY KEY,   -- идентификатор владельца
    save_id             INT NOT NULL REFERENCES game_save(id) ON DELETE CASCADE, -- сохранение
    type                TEXT NOT NULL CHECK (type IN ('state','private','mixed')), -- тип: государство, частный, смешанный
    name                TEXT,                 -- название или имя владельца
    expectation_rank    SMALLINT,             -- ожидаемое место в лиге
    expectation_profit  NUMERIC(14,2),        -- ожидаемая прибыль или баланс
    patience            SMALLINT CHECK (patience BETWEEN 0 AND 100) -- терпение владельца (0 — потеряно)
);

-- @table: Клубы в рамках сохранения
CREATE TABLE club (
    id               SERIAL PRIMARY KEY,   -- идентификатор клуба
    save_id          INT NOT NULL REFERENCES game_save(id) ON DELETE CASCADE, -- сохранение
    city_id          INT NOT NULL REFERENCES city(id), -- город клуба
    league_id        INT NOT NULL REFERENCES league(id), -- текущая лига
    owner_id         INT REFERENCES owner(id), -- владелец
    name             TEXT NOT NULL,        -- название клуба
    founded_year     SMALLINT,             -- год основания
    budget           NUMERIC(14,2) NOT NULL, -- текущий баланс
    annual_budget    NUMERIC(14,2) NOT NULL, -- плановый годовой бюджет
    reputation       SMALLINT CHECK (reputation BETWEEN 0 AND 100), -- репутация клуба
    primary_color    CHAR(7),              -- основной цвет (#RRGGBB)
    secondary_color  CHAR(7),              -- дополнительный цвет (#RRGGBB)
    is_real          BOOLEAN NOT NULL DEFAULT TRUE,  -- реальный клуб из базы
    is_user_created  BOOLEAN NOT NULL DEFAULT FALSE, -- создан игроком
    access_tier      TEXT NOT NULL DEFAULT 'open' CHECK (access_tier IN ('open','locked','premium')), -- доступность для выбора: открыт, закрыт, платная разблокировка
    is_top_draw      BOOLEAN NOT NULL DEFAULT FALSE, -- топ-клуб: даёт автонадбавку к цене билета у соперников
    status           TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('forming','applied','active')) -- формируется, заявка подана, играет в лиге
);

ALTER TABLE game_save
    ADD CONSTRAINT fk_save_user_club FOREIGN KEY (user_club_id) REFERENCES club(id);

-- @table: Принадлежность клуба к лиге по сезонам
CREATE TABLE club_league_membership (
    club_id    INT NOT NULL REFERENCES club(id) ON DELETE CASCADE, -- клуб
    season_id  INT NOT NULL REFERENCES season(id) ON DELETE CASCADE, -- сезон
    league_id  INT NOT NULL REFERENCES league(id), -- лига, в которой клуб играл
    PRIMARY KEY (club_id, season_id)
);

-- @table: Арены клубов (у клуба без арены — арендованный зал)
CREATE TABLE arena (
    id               SERIAL PRIMARY KEY,   -- идентификатор арены
    club_id          INT NOT NULL UNIQUE REFERENCES club(id) ON DELETE CASCADE, -- клуб
    name             TEXT,                 -- название арены
    kind             TEXT NOT NULL DEFAULT 'arena' CHECK (kind IN ('rented_hall','school_gym','arena')), -- вид: арендованный зал, школьный зал, арена
    capacity         INT NOT NULL,         -- суммарная вместимость (сумма секторов)
    condition        SMALLINT CHECK (condition BETWEEN 0 AND 100), -- износ и состояние арены
    upkeep_cost      NUMERIC(12,2),        -- стоимость содержания
    guest_quota_pct  SMALLINT NOT NULL DEFAULT 5 -- доля мест под гостевой сектор, %
);

-- @table: Секторы арены (схема мест)
CREATE TABLE arena_sector (
    id             SERIAL PRIMARY KEY,   -- идентификатор сектора
    arena_id       INT NOT NULL REFERENCES arena(id) ON DELETE CASCADE, -- арена
    name           TEXT NOT NULL,        -- название сектора
    kind           TEXT NOT NULL CHECK (kind IN ('vip','parterre','standard')), -- тип мест: VIP, партер, обычные
    tier           SMALLINT NOT NULL DEFAULT 1, -- ярус
    rows_count     SMALLINT NOT NULL,    -- число рядов
    seats_per_row  SMALLINT NOT NULL,    -- мест в ряду
    capacity       INT GENERATED ALWAYS AS (rows_count * seats_per_row) STORED, -- вместимость сектора
    geometry       JSONB,                -- положение сектора на плане для отрисовки
    UNIQUE (arena_id, name)
);

-- @table: Проекты строительства и реконструкции арены
CREATE TABLE arena_project (
    id           SERIAL PRIMARY KEY,   -- идентификатор проекта
    club_id      INT NOT NULL REFERENCES club(id) ON DELETE CASCADE, -- клуб
    type         TEXT NOT NULL CHECK (type IN ('build','expand','rebuild')), -- строительство, расширение, перестройка
    template_id  INT REFERENCES arena_template(id), -- выбранный шаблон формы
    layout       JSONB NOT NULL,       -- планируемая схема секторов
    cost         NUMERIC(14,2) NOT NULL, -- смета с учётом скидки
    discount_pct NUMERIC(5,2) NOT NULL DEFAULT 0, -- скидка (например, для государственных клубов), %
    funded       NUMERIC(14,2) NOT NULL DEFAULT 0, -- сколько финансирования уже собрано
    start_date   DATE,                 -- дата начала работ
    end_date     DATE,                 -- плановая дата завершения
    status       TEXT NOT NULL DEFAULT 'planned' CHECK (status IN ('planned','funding','building','done','cancelled')) -- статус проекта
);


-- ============================================================
-- 4. ЛЮДИ: ТРЕНЕРЫ, ИГРОКИ, ШТАБ, КОНТРАКТЫ
-- ============================================================

-- @table: Тренеры (тактику и ход матча решает главный тренер)
CREATE TABLE coach (
    id                SERIAL PRIMARY KEY,   -- идентификатор тренера
    save_id           INT NOT NULL REFERENCES game_save(id) ON DELETE CASCADE, -- сохранение
    club_id           INT REFERENCES club(id) ON DELETE SET NULL, -- текущий клуб (пусто — без клуба)
    full_name         TEXT NOT NULL,        -- имя тренера
    birth_date        DATE,                 -- дата рождения
    tactics_skill     SMALLINT CHECK (tactics_skill BETWEEN 1 AND 100), -- тактика
    youth_skill       SMALLINT CHECK (youth_skill BETWEEN 1 AND 100),   -- работа с молодёжью
    motivation_skill  SMALLINT CHECK (motivation_skill BETWEEN 1 AND 100), -- мотивация
    reputation        SMALLINT CHECK (reputation BETWEEN 0 AND 100),    -- репутация тренера
    preferred_style   TEXT                  -- любимый стиль игры
);

-- @table: Игроки (в интерфейсе характеристики показываются ярлыками, без цифр)
CREATE TABLE player (
    id              SERIAL PRIMARY KEY,   -- идентификатор игрока
    save_id         INT NOT NULL REFERENCES game_save(id) ON DELETE CASCADE, -- сохранение
    club_id         INT REFERENCES club(id) ON DELETE SET NULL, -- текущий клуб (пусто — свободный агент)
    full_name       TEXT NOT NULL,        -- имя игрока
    birth_date      DATE NOT NULL,        -- дата рождения
    nationality     TEXT,                 -- гражданство
    height_cm       SMALLINT,             -- рост, см
    position        TEXT NOT NULL CHECK (position IN ('PG','SG','SF','PF','C')), -- позиция
    attack          SMALLINT CHECK (attack BETWEEN 1 AND 100),        -- атака
    defense         SMALLINT CHECK (defense BETWEEN 1 AND 100),       -- защита
    physical        SMALLINT CHECK (physical BETWEEN 1 AND 100),      -- физика
    basketball_iq   SMALLINT CHECK (basketball_iq BETWEEN 1 AND 100), -- баскетбольный интеллект
    potential       SMALLINT CHECK (potential BETWEEN 1 AND 100),     -- истинный потенциал (игроку показывается размыто)
    form            SMALLINT CHECK (form BETWEEN 0 AND 100),          -- текущая форма
    fatigue         SMALLINT CHECK (fatigue BETWEEN 0 AND 100),       -- усталость
    morale          SMALLINT CHECK (morale BETWEEN 0 AND 100),        -- мораль
    injury_until    DATE,                 -- до какой даты травма (пусто — здоров)
    is_foreign      BOOLEAN NOT NULL DEFAULT FALSE, -- легионер
    is_youth        BOOLEAN NOT NULL DEFAULT FALSE, -- молодёжный игрок
    source          TEXT CHECK (source IN ('academy','market','real')), -- откуда игрок: академия, рынок, реальная база
    academy_status  TEXT CHECK (academy_status IN ('prospect','graduated','released')) -- состояние воспитанника академии
);

-- @table: Сотрудники штаба (врач, скаут, маркетинг, физподготовка, PR)
CREATE TABLE staff (
    id         SERIAL PRIMARY KEY,   -- идентификатор сотрудника
    save_id    INT NOT NULL REFERENCES game_save(id) ON DELETE CASCADE, -- сохранение
    club_id    INT REFERENCES club(id) ON DELETE SET NULL, -- текущий клуб
    role       TEXT NOT NULL REFERENCES staff_role(role), -- роль
    full_name  TEXT NOT NULL,        -- имя сотрудника
    skill      SMALLINT CHECK (skill BETWEEN 1 AND 100), -- навык
    salary     NUMERIC(12,2)         -- зарплата
);

-- @table: Контракты игроков, тренеров и сотрудников (каждый — ровно с одним человеком)
CREATE TABLE contract (
    id             SERIAL PRIMARY KEY,   -- идентификатор контракта
    save_id        INT NOT NULL REFERENCES game_save(id) ON DELETE CASCADE, -- сохранение
    club_id        INT NOT NULL REFERENCES club(id) ON DELETE CASCADE, -- клуб
    player_id      INT REFERENCES player(id) ON DELETE CASCADE, -- игрок (если контракт игрока)
    coach_id       INT REFERENCES coach(id) ON DELETE CASCADE,  -- тренер (если контракт тренера)
    staff_id       INT REFERENCES staff(id) ON DELETE CASCADE,  -- сотрудник (если контракт сотрудника)
    salary         NUMERIC(12,2) NOT NULL, -- зарплата
    start_date     DATE NOT NULL,        -- начало контракта
    end_date       DATE NOT NULL,        -- окончание контракта
    bonus_per_win  NUMERIC(12,2) NOT NULL DEFAULT 0, -- бонус за победу
    release_clause NUMERIC(14,2),        -- сумма выкупа контракта
    CHECK ((player_id IS NOT NULL)::INT + (coach_id IS NOT NULL)::INT + (staff_id IS NOT NULL)::INT = 1)
);

-- @table: Сколько слотов каждой роли штаба открыто у клуба
CREATE TABLE club_staff_slot (
    club_id     INT NOT NULL REFERENCES club(id) ON DELETE CASCADE, -- клуб
    role        TEXT NOT NULL REFERENCES staff_role(role), -- роль штаба
    slots_open  SMALLINT NOT NULL DEFAULT 1, -- открыто слотов (у нового клуба — 1)
    PRIMARY KEY (club_id, role)
);

-- @table: Менеджерская карьера игрока: клубы, увольнения
CREATE TABLE manager_career (
    id          SERIAL PRIMARY KEY,   -- идентификатор записи
    save_id     INT NOT NULL REFERENCES game_save(id) ON DELETE CASCADE, -- сохранение
    club_id     INT NOT NULL REFERENCES club(id), -- клуб
    from_date   DATE NOT NULL,        -- с какой даты менеджер в клубе
    to_date     DATE,                 -- по какую дату (пусто — работает сейчас)
    end_reason  TEXT NOT NULL DEFAULT 'active' CHECK (end_reason IN ('active','dismissed','resigned')) -- причина окончания
);


-- ============================================================
-- 5. ФИНАНСЫ, СПОНСОРЫ, БОЛЕЛЬЩИКИ, БИЛЕТЫ
-- ============================================================

-- @table: Спонсоры (коммерческие, город, край)
CREATE TABLE sponsor (
    id                   SERIAL PRIMARY KEY,   -- идентификатор спонсора
    save_id              INT NOT NULL REFERENCES game_save(id) ON DELETE CASCADE, -- сохранение
    name                 TEXT NOT NULL,        -- название
    kind                 TEXT NOT NULL DEFAULT 'commercial' CHECK (kind IN ('commercial','city','region')), -- вид: коммерческий, город, край
    category             TEXT,                 -- отрасль
    min_reputation       SMALLINT,             -- минимальная репутация клуба для сделки
    min_city_population  INT NOT NULL DEFAULT 0, -- минимальное население города
    base_amount          NUMERIC(14,2)         -- базовая годовая сумма
);

-- @table: Спонсорские договоры клубов и предложения
CREATE TABLE sponsor_deal (
    id                SERIAL PRIMARY KEY,   -- идентификатор договора
    club_id           INT NOT NULL REFERENCES club(id) ON DELETE CASCADE, -- клуб
    sponsor_id        INT NOT NULL REFERENCES sponsor(id), -- спонсор
    slot              TEXT NOT NULL DEFAULT 'partner' CHECK (slot IN ('title','partner')), -- слот: титульный или смежный
    amount_per_year   NUMERIC(14,2) NOT NULL, -- сумма в год
    bonus_amount      NUMERIC(14,2) NOT NULL DEFAULT 0, -- бонус за выполнение условий
    penalty_amount    NUMERIC(14,2) NOT NULL DEFAULT 0, -- штраф за невыполнение
    start_date        DATE NOT NULL,        -- начало договора
    end_date          DATE NOT NULL,        -- окончание договора
    min_rank          SMALLINT,             -- условие: занять место не ниже
    min_attendance    INT,                  -- условие: средняя посещаемость не ниже
    is_mandatory      BOOLEAN NOT NULL DEFAULT FALSE, -- обязательный договор (городской или краевой у госклуба)
    status            TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('offered','active','completed','terminated','expired')), -- статус договора
    offer_expires_on  DATE                  -- до какой даты действует предложение
);

-- @table: Журнал доходов и расходов клуба
CREATE TABLE finance_record (
    id         BIGSERIAL PRIMARY KEY,   -- идентификатор записи
    club_id    INT NOT NULL REFERENCES club(id) ON DELETE CASCADE, -- клуб
    season_id  INT NOT NULL REFERENCES season(id) ON DELETE CASCADE, -- сезон
    month      DATE NOT NULL,           -- первое число месяца
    category   TEXT NOT NULL CHECK (category IN (
                 'tickets','season_passes','sponsors','subsidy','merch','tv','prizes','transfer_in',
                 'salaries','arena','match_costs','construction','staff','youth','marketing','away_trips','transfer_out','other')), -- статья
    amount     NUMERIC(14,2) NOT NULL,  -- сумма: плюс — доход, минус — расход
    match_id   INT                      -- матч, к которому относится запись (FK добавлен ниже)
);

-- @table: Текущие показатели болельщиков клуба
CREATE TABLE fan_base (
    club_id         INT PRIMARY KEY REFERENCES club(id) ON DELETE CASCADE, -- клуб
    size            INT NOT NULL DEFAULT 0, -- размер базы болельщиков
    loyalty         SMALLINT NOT NULL DEFAULT 0 CHECK (loyalty BETWEEN 0 AND 100), -- лояльность (медленно меняется)
    hype            SMALLINT NOT NULL DEFAULT 0 CHECK (hype BETWEEN 0 AND 100),    -- ажиотаж (быстро растёт и затухает)
    city_share      NUMERIC(5,2) NOT NULL DEFAULT 0 CHECK (city_share BETWEEN 0 AND 100), -- доля внимания города, %
    avg_attendance  INT                     -- средняя посещаемость домашних матчей
);

-- @table: История показателей болельщиков по месяцам
CREATE TABLE fan_base_history (
    club_id         INT NOT NULL REFERENCES club(id) ON DELETE CASCADE, -- клуб
    month           DATE NOT NULL,        -- первое число месяца
    size            INT NOT NULL,         -- размер базы
    loyalty         SMALLINT NOT NULL,    -- лояльность
    hype            SMALLINT,             -- ажиотаж
    city_share      NUMERIC(5,2) NOT NULL, -- доля города, %
    avg_attendance  INT,                  -- средняя посещаемость
    factors         JSONB,                -- вклад факторов в изменение (для блока «Что влияет»)
    PRIMARY KEY (club_id, month)
);

-- @table: Запущенные акции и кампании клуба
CREATE TABLE fan_campaign (
    id                SERIAL PRIMARY KEY,   -- идентификатор акции
    club_id           INT NOT NULL REFERENCES club(id) ON DELETE CASCADE, -- клуб
    campaign_type_id  INT NOT NULL REFERENCES campaign_type(id), -- тип акции
    cost              NUMERIC(12,2) NOT NULL, -- фактическая стоимость
    start_date        DATE NOT NULL,        -- начало
    end_date          DATE NOT NULL,        -- окончание
    status            TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active','finished','cancelled')), -- статус
    result            JSONB                 -- фактический результат (лояльность, ажиотаж, база, культура)
);

-- @table: Базовые цены билетов клуба по типам мест
CREATE TABLE sector_price (
    club_id  INT NOT NULL REFERENCES club(id) ON DELETE CASCADE, -- клуб
    kind     TEXT NOT NULL CHECK (kind IN ('vip','parterre','standard')), -- тип мест
    price    NUMERIC(8,2) NOT NULL,  -- базовая цена билета
    PRIMARY KEY (club_id, kind)
);

-- @table: Абонементы на сезон (продаются на старте сезона)
CREATE TABLE season_pass (
    id           SERIAL PRIMARY KEY,   -- идентификатор
    club_id      INT NOT NULL REFERENCES club(id) ON DELETE CASCADE, -- клуб
    season_id    INT NOT NULL REFERENCES season(id) ON DELETE CASCADE, -- сезон
    kind         TEXT NOT NULL CHECK (kind IN ('vip','parterre','standard')), -- тип мест
    price        NUMERIC(10,2) NOT NULL, -- цена абонемента
    quota        INT NOT NULL,           -- сколько мест отдано под абонементы
    sold         INT NOT NULL DEFAULT 0, -- продано абонементов
    sales_open   DATE,                   -- начало продаж
    sales_close  DATE,                   -- конец продаж
    UNIQUE (club_id, season_id, kind)
);

-- @table: Продажа билетов на домашний матч по типам мест
CREATE TABLE match_ticket_sales (
    match_id         INT NOT NULL,        -- матч (FK добавлен ниже)
    kind             TEXT NOT NULL CHECK (kind IN ('vip','parterre','standard')), -- тип мест
    price            NUMERIC(8,2) NOT NULL, -- итоговая цена с автонадбавкой
    markup_reason    TEXT,                -- причина автонадбавки (top_opponent, playoff)
    capacity         INT NOT NULL,        -- мест в продаже (за вычетом абонементов)
    sold             INT NOT NULL DEFAULT 0, -- продано билетов
    sales_opened_on  DATE,                -- когда игрок открыл продажу (пусто — не открыта)
    PRIMARY KEY (match_id, kind)
);

-- @table: Динамика продаж билетов по дням
CREATE TABLE ticket_sales_daily (
    match_id  INT NOT NULL,           -- матч (FK добавлен ниже)
    kind      TEXT NOT NULL CHECK (kind IN ('vip','parterre','standard')), -- тип мест
    day       DATE NOT NULL,          -- игровой день
    sold      INT NOT NULL,           -- продано за день
    PRIMARY KEY (match_id, kind, day)
);

-- @table: Расходы на проведение матча
CREATE TABLE match_finance (
    match_id       INT NOT NULL,        -- матч (FK добавлен ниже)
    club_id        INT NOT NULL REFERENCES club(id) ON DELETE CASCADE, -- клуб, который несёт расходы
    arena_cost     NUMERIC(12,2) NOT NULL DEFAULT 0, -- аренда и обслуживание арены
    security_cost  NUMERIC(12,2) NOT NULL DEFAULT 0, -- охрана
    referee_cost   NUMERIC(12,2) NOT NULL DEFAULT 0, -- судьи
    travel_cost    NUMERIC(12,2) NOT NULL DEFAULT 0, -- логистика выездного матча
    service_level  TEXT NOT NULL DEFAULT 'standard' CHECK (service_level IN ('economy','standard','premium')), -- уровень организации
    PRIMARY KEY (match_id, club_id)
);

-- @table: Организация выезда болельщиков на матч
CREATE TABLE away_trip (
    id              SERIAL PRIMARY KEY,   -- идентификатор выезда
    club_id         INT NOT NULL REFERENCES club(id) ON DELETE CASCADE, -- клуб
    match_id        INT NOT NULL,         -- выездной матч (FK добавлен ниже)
    transport       TEXT NOT NULL CHECK (transport IN ('none','bus','train','plane')), -- транспорт
    subsidy_pct     SMALLINT NOT NULL DEFAULT 0 CHECK (subsidy_pct BETWEEN 0 AND 100), -- доля стоимости, которую берёт клуб, %
    seats_ordered   INT NOT NULL DEFAULT 0, -- заказано мест в гостевом секторе
    distance_km     INT,                  -- расстояние до города соперника
    planned_fans    INT,                  -- ожидаемое число поехавших
    actual_fans     INT,                  -- сколько поехало на самом деле
    cost            NUMERIC(12,2) NOT NULL DEFAULT 0, -- итоговые расходы клуба
    cost_breakdown  JSONB,                -- разбивка: дорога, ночлег, субсидия
    status          TEXT NOT NULL DEFAULT 'planned' CHECK (status IN ('planned','confirmed','done','cancelled')), -- статус
    UNIQUE (club_id, match_id)
);


-- ============================================================
-- 6. СОРЕВНОВАНИЯ
-- ============================================================

-- @table: Розыгрыши (лига или кубок) в рамках сезона
CREATE TABLE competition (
    id         SERIAL PRIMARY KEY,   -- идентификатор розыгрыша
    season_id  INT NOT NULL REFERENCES season(id) ON DELETE CASCADE, -- сезон
    league_id  INT REFERENCES league(id), -- лига (если это чемпионат)
    cup_id     INT REFERENCES cup(id),    -- кубок (если это кубок)
    CHECK ((league_id IS NOT NULL)::INT + (cup_id IS NOT NULL)::INT = 1)
);

-- @table: Матчи
CREATE TABLE match (
    id              SERIAL PRIMARY KEY,   -- идентификатор матча
    competition_id  INT NOT NULL REFERENCES competition(id) ON DELETE CASCADE, -- розыгрыш
    match_date      DATE NOT NULL,        -- игровая дата
    stage           TEXT,                 -- этап: тур, 1/4, финал
    home_club_id    INT NOT NULL REFERENCES club(id), -- хозяева
    away_club_id    INT NOT NULL REFERENCES club(id), -- гости
    home_score      SMALLINT,             -- очки хозяев
    away_score      SMALLINT,             -- очки гостей
    quarter_scores  JSONB,                -- счёт по четвертям
    attendance      INT,                  -- посещаемость
    summary         TEXT,                 -- текстовая хроника матча
    played          BOOLEAN NOT NULL DEFAULT FALSE, -- матч сыгран
    CHECK (home_club_id <> away_club_id)
);

ALTER TABLE finance_record
    ADD CONSTRAINT fk_finance_match FOREIGN KEY (match_id) REFERENCES match(id) ON DELETE SET NULL;
ALTER TABLE match_ticket_sales
    ADD CONSTRAINT fk_mts_match FOREIGN KEY (match_id) REFERENCES match(id) ON DELETE CASCADE;
ALTER TABLE ticket_sales_daily
    ADD CONSTRAINT fk_tsd_match FOREIGN KEY (match_id) REFERENCES match(id) ON DELETE CASCADE;
ALTER TABLE match_finance
    ADD CONSTRAINT fk_mf_match FOREIGN KEY (match_id) REFERENCES match(id) ON DELETE CASCADE;
ALTER TABLE away_trip
    ADD CONSTRAINT fk_trip_match FOREIGN KEY (match_id) REFERENCES match(id) ON DELETE CASCADE;

-- @table: Статистика игроков в матчах
CREATE TABLE player_match_stat (
    match_id   INT NOT NULL REFERENCES match(id) ON DELETE CASCADE, -- матч
    player_id  INT NOT NULL REFERENCES player(id) ON DELETE CASCADE, -- игрок
    minutes    SMALLINT,    -- минуты на площадке
    points     SMALLINT,    -- очки
    rebounds   SMALLINT,    -- подборы
    assists    SMALLINT,    -- передачи
    PRIMARY KEY (match_id, player_id)
);

-- @table: Турнирная таблица розыгрыша
CREATE TABLE standings (
    competition_id  INT NOT NULL REFERENCES competition(id) ON DELETE CASCADE, -- розыгрыш
    club_id         INT NOT NULL REFERENCES club(id) ON DELETE CASCADE, -- клуб
    wins            SMALLINT NOT NULL DEFAULT 0, -- победы
    losses          SMALLINT NOT NULL DEFAULT 0, -- поражения
    points_for      INT NOT NULL DEFAULT 0,      -- набранные очки
    points_against  INT NOT NULL DEFAULT 0,      -- пропущенные очки
    PRIMARY KEY (competition_id, club_id)
);

-- @table: Серии плей-офф
CREATE TABLE playoff_series (
    id              SERIAL PRIMARY KEY,   -- идентификатор серии
    competition_id  INT NOT NULL REFERENCES competition(id) ON DELETE CASCADE, -- розыгрыш
    round           SMALLINT NOT NULL,    -- раунд
    club_a_id       INT NOT NULL REFERENCES club(id), -- первый клуб
    club_b_id       INT NOT NULL REFERENCES club(id), -- второй клуб
    wins_a          SMALLINT NOT NULL DEFAULT 0,      -- победы первого клуба в серии
    wins_b          SMALLINT NOT NULL DEFAULT 0,      -- победы второго клуба в серии
    winner_id       INT REFERENCES club(id)           -- победитель серии
);

-- @table: Заявки клубов на повышение в лигу (автоматического повышения нет)
CREATE TABLE promotion_application (
    id           SERIAL PRIMARY KEY,   -- идентификатор заявки
    club_id      INT NOT NULL REFERENCES club(id) ON DELETE CASCADE, -- клуб
    season_id    INT NOT NULL REFERENCES season(id) ON DELETE CASCADE, -- сезон
    from_league  INT NOT NULL REFERENCES league(id), -- текущая лига
    to_league    INT NOT NULL REFERENCES league(id), -- лига, в которую клуб имеет право подняться
    status       TEXT NOT NULL DEFAULT 'eligible' CHECK (status IN ('eligible','applied','declined','rejected','accepted')), -- право есть, подана, отказ остаться на год, условия не выполнены, принята
    deadline     DATE NOT NULL,        -- крайний срок подачи
    checklist    JSONB,                -- результат проверки требований по пунктам
    UNIQUE (club_id, season_id)
);

-- @table: Итоги сезонов клуба (история клуба)
CREATE TABLE club_season_summary (
    club_id        INT NOT NULL REFERENCES club(id) ON DELETE CASCADE, -- клуб
    season_id      INT NOT NULL REFERENCES season(id) ON DELETE CASCADE, -- сезон
    league_id      INT NOT NULL REFERENCES league(id), -- лига сезона
    final_rank     SMALLINT,           -- итоговое место
    wins           SMALLINT,           -- победы
    losses         SMALLINT,           -- поражения
    cup_result     TEXT,               -- результат в кубках
    trophies       JSONB,              -- завоёванные трофеи
    final_balance  NUMERIC(14,2),      -- баланс на конец сезона
    PRIMARY KEY (club_id, season_id)
);

-- @table: Цели владельца на сезон
CREATE TABLE owner_goal (
    id         SERIAL PRIMARY KEY,   -- идентификатор цели
    club_id    INT NOT NULL REFERENCES club(id) ON DELETE CASCADE, -- клуб
    season_id  INT NOT NULL REFERENCES season(id) ON DELETE CASCADE, -- сезон
    type       TEXT NOT NULL,        -- вид цели: rank, profit, arena, roster
    target     NUMERIC(14,2),        -- целевое значение
    status     TEXT NOT NULL DEFAULT 'on_track' CHECK (status IN ('on_track','at_risk','failed','achieved')) -- статус цели
);


-- ============================================================
-- 7. ТРАНСФЕРЫ, СКАУТИНГ, АКАДЕМИЯ, СОБЫТИЯ
-- ============================================================

-- @table: Трансферные предложения
CREATE TABLE transfer_offer (
    id               SERIAL PRIMARY KEY,   -- идентификатор предложения
    save_id          INT NOT NULL REFERENCES game_save(id) ON DELETE CASCADE, -- сохранение
    player_id        INT NOT NULL REFERENCES player(id) ON DELETE CASCADE, -- игрок
    from_club_id     INT REFERENCES club(id), -- продающий клуб (пусто — свободный агент)
    to_club_id       INT NOT NULL REFERENCES club(id), -- покупающий клуб
    fee              NUMERIC(14,2) NOT NULL DEFAULT 0, -- сумма трансфера
    offered_salary   NUMERIC(12,2),        -- предложенная игроку зарплата
    offered_years    SMALLINT,             -- предложенный срок контракта, лет
    status           TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','accepted','rejected','withdrawn','expired')), -- статус
    created_on       DATE NOT NULL,        -- дата создания
    expires_on       DATE                  -- срок действия предложения
);

-- @table: Задания скаутам
CREATE TABLE scouting_task (
    id               SERIAL PRIMARY KEY,   -- идентификатор задания
    club_id          INT NOT NULL REFERENCES club(id) ON DELETE CASCADE, -- клуб
    scout_id         INT NOT NULL REFERENCES staff(id), -- скаут
    target_region    TEXT,                 -- регион или страна поиска
    target_position  TEXT,                 -- искомая позиция
    progress         SMALLINT NOT NULL DEFAULT 0 CHECK (progress BETWEEN 0 AND 100), -- прогресс задания, %
    started_at       DATE NOT NULL         -- дата начала
);

-- @table: Игроки, найденные по заданию скаута
CREATE TABLE scouting_result (
    task_id    INT NOT NULL REFERENCES scouting_task(id) ON DELETE CASCADE, -- задание
    player_id  INT NOT NULL REFERENCES player(id) ON DELETE CASCADE, -- найденный игрок
    PRIMARY KEY (task_id, player_id)
);

-- @table: Скрытые игроки, открытые клубу скаутингом
CREATE TABLE player_visibility (
    club_id    INT NOT NULL REFERENCES club(id) ON DELETE CASCADE, -- клуб
    player_id  INT NOT NULL REFERENCES player(id) ON DELETE CASCADE, -- открытый игрок
    PRIMARY KEY (club_id, player_id)
);

-- @table: Молодёжная академия клуба (генератор молодых игроков)
CREATE TABLE youth_academy (
    club_id         INT PRIMARY KEY REFERENCES club(id) ON DELETE CASCADE, -- клуб
    type            TEXT CHECK (type IN ('school','club','pro')), -- тип: школьная, клубная, профессиональная
    level           SMALLINT CHECK (level BETWEEN 1 AND 10), -- уровень
    talent_ceiling  SMALLINT,          -- потолок талантов
    yearly_cost     NUMERIC(12,2)      -- годовые расходы
);

-- @table: Ежегодный набор воспитанников академии
CREATE TABLE youth_intake (
    id         SERIAL PRIMARY KEY,   -- идентификатор набора
    club_id    INT NOT NULL REFERENCES club(id) ON DELETE CASCADE, -- клуб
    season_id  INT NOT NULL REFERENCES season(id) ON DELETE CASCADE, -- сезон
    size       SMALLINT NOT NULL,    -- сколько воспитанников сгенерировано
    UNIQUE (club_id, season_id)
);

-- @table: Лента событий клуба (входящие)
CREATE TABLE game_event (
    id               BIGSERIAL PRIMARY KEY,   -- идентификатор события
    save_id          INT NOT NULL REFERENCES game_save(id) ON DELETE CASCADE, -- сохранение
    club_id          INT REFERENCES club(id) ON DELETE CASCADE, -- клуб, которого касается событие
    event_date       DATE NOT NULL,           -- игровая дата события
    type             TEXT NOT NULL,           -- тип: injury, conflict, sponsor_offer, transfer_offer, owner_message
    payload          JSONB,                   -- данные события
    is_read          BOOLEAN NOT NULL DEFAULT FALSE, -- прочитано
    requires_action  BOOLEAN NOT NULL DEFAULT FALSE, -- требует решения игрока
    expires_on       DATE,                    -- срок действия (после него — просрочено)
    resolution       TEXT                     -- итог: accepted, declined, expired
);

-- @table: Дневной журнал расчёта игры для ленты дней
CREATE TABLE day_log (
    id        BIGSERIAL PRIMARY KEY,   -- идентификатор записи
    save_id   INT NOT NULL REFERENCES game_save(id) ON DELETE CASCADE, -- сохранение
    log_date  DATE NOT NULL,           -- игровой день
    summary   JSONB NOT NULL,          -- сводка дня: баланс, форма, матч, события
    UNIQUE (save_id, log_date)
);


-- ============================================================
-- 8. ОГРАНИЧЕНИЕ: НЕ БОЛЕЕ N СОХРАНЕНИЙ НА АККАУНТ
-- ============================================================

CREATE OR REPLACE FUNCTION check_save_limit() RETURNS trigger AS $$
DECLARE
    max_saves INT;
BEGIN
    SELECT COALESCE((SELECT value::INT FROM game_config WHERE key = 'max_saves_per_user'), 5)
      INTO max_saves;
    IF (SELECT COUNT(*) FROM game_save WHERE user_id = NEW.user_id) >= max_saves THEN
        RAISE EXCEPTION 'Достигнут лимит сохранений: %', max_saves;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_save_limit
    BEFORE INSERT ON game_save
    FOR EACH ROW EXECUTE FUNCTION check_save_limit();


-- ============================================================
-- 9. ИНДЕКСЫ
-- ============================================================

CREATE INDEX idx_save_user          ON game_save(user_id, last_played_at DESC);
CREATE INDEX idx_club_save          ON club(save_id);
CREATE INDEX idx_club_city          ON club(city_id);
CREATE INDEX idx_city_save          ON city(save_id);
CREATE INDEX idx_player_club        ON player(club_id);
CREATE INDEX idx_player_save        ON player(save_id);
CREATE INDEX idx_contract_club      ON contract(club_id, end_date);
CREATE INDEX idx_match_comp_date    ON match(competition_id, match_date);
CREATE INDEX idx_match_home         ON match(home_club_id);
CREATE INDEX idx_match_away         ON match(away_club_id);
CREATE INDEX idx_finance_club_season ON finance_record(club_id, season_id);
CREATE INDEX idx_event_save_unread  ON game_event(save_id, is_read);
CREATE INDEX idx_transfer_status    ON transfer_offer(to_club_id, status);
CREATE INDEX idx_sponsor_deal_club  ON sponsor_deal(club_id, status);


-- ============================================================
-- 10. НАЧАЛЬНЫЕ ДАННЫЕ СПРАВОЧНИКОВ (значения примерные)
-- ============================================================

INSERT INTO game_config (key, value, description) VALUES
    ('max_saves_per_user',          5,    'Максимум сохранений на аккаунт'),
    ('roster_min',                  12,   'Минимальный состав для заявки в лигу'),
    ('ticket_sales_max_days_before',30,   'За сколько дней до матча можно открыть продажу билетов'),
    ('away_trip_max_days_before',   14,   'За сколько дней до матча можно организовать выезд болельщиков'),
    ('culture_base_growth',         0.05, 'Базовый рост культуры города за сезон'),
    ('culture_pioneer_multiplier',  1.3,  'Множитель роста культуры в городе без других клубов'),
    ('state_culture_multiplier',    1.5,  'Множитель роста культуры при госспонсоре'),
    ('state_arena_discount_pct',    15,   'Скидка госклубам на строительство арены, %'),
    ('hype_decay_per_day',          0.97, 'Ежедневный множитель затухания ажиотажа'),
    ('youth_graduation_age',        19,   'Возраст выпуска воспитанника из академии');

INSERT INTO staff_role (role, title, max_slots) VALUES
    ('doctor',    'Врач',                       3),
    ('scout',     'Скаут',                      3),
    ('marketing', 'Менеджер по маркетингу',     3),
    ('fitness',   'Тренер по физподготовке',    3),
    ('pr',        'PR-менеджер',                1);

INSERT INTO sponsor_slot_rule (owner_type, slot, max_slots) VALUES
    ('private', 'title',   1),
    ('private', 'partner', 3),
    ('state',   'title',   1),
    ('state',   'partner', 0),
    ('mixed',   'title',   1),
    ('mixed',   'partner', 1);

INSERT INTO sector_unlock_rule (kind, conditions) VALUES
    ('standard', '{}'),
    ('parterre', '{"max_league_tier": 2}'),
    ('vip',      '{"max_league_tier": 2, "min_years": 3, "min_reputation": 60}');

INSERT INTO arena_limit_rule (min_reputation, max_tiers, max_capacity) VALUES
    (0,  1, 1000),
    (30, 2, 5000),
    (60, 3, 12000),
    (85, 3, 25000);

INSERT INTO ticket_markup_rule (reason, multiplier) VALUES
    ('top_opponent', 1.25),
    ('playoff',      1.30);

INSERT INTO day_demand_factor (weekday, factor) VALUES
    (1, 0.80), (2, 0.80), (3, 0.85), (4, 0.90), (5, 1.00), (6, 1.20), (7, 1.15);

INSERT INTO transport_rate (transport, cost_per_km, min_km, max_km, lodging_from_km) VALUES
    ('bus',   3.50,    0, 1000, 700),
    ('train', 5.00,  300, 3000, 700),
    ('plane', 12.00, 800, NULL, 1500);

INSERT INTO hype_rule (reason, delta) VALUES
    ('win', 2), ('win_streak', 3), ('upset_win', 5), ('loss', -1),
    ('star_signing', 8), ('playoff', 4), ('campaign', 3);


-- ============================================================
-- 11. ПОДПИСИ К ТАБЛИЦАМ И КОЛОНКАМ (COMMENT ON)
-- Видны в pgAdmin, DBeaver и psql (\d+ таблица)
-- ============================================================

COMMENT ON TABLE region IS 'Регионы (края, области) России';
COMMENT ON TABLE league IS 'Лиги: Лига ВТБ, Суперлига, лига ниже Суперлиги';
COMMENT ON TABLE league_rule IS 'Правила лиги: зоны таблицы и формат серий плей-офф';
COMMENT ON TABLE league_requirement IS 'Требования лиги к клубу для допуска и повышения';
COMMENT ON TABLE cup IS 'Кубки: Кубок России, Винлайн кубок';
COMMENT ON TABLE game_config IS 'Глобальные настройки баланса игры (ключ — значение)';
COMMENT ON TABLE staff_role IS 'Роли штаба и предельное число слотов на роль';
COMMENT ON TABLE slot_unlock_rule IS 'Условия открытия дополнительных слотов штаба';
COMMENT ON TABLE sector_unlock_rule IS 'Условия открытия типов мест на арене (партер, VIP)';
COMMENT ON TABLE arena_limit_rule IS 'Ограничения арены по репутации клуба (число ярусов и вместимость)';
COMMENT ON TABLE arena_template IS 'Шаблоны форм арены для конструктора';
COMMENT ON TABLE ticket_markup_rule IS 'Автонадбавки к цене билета';
COMMENT ON TABLE day_demand_factor IS 'Коэффициент спроса по дням недели (билеты и выезды болельщиков)';
COMMENT ON TABLE transport_rate IS 'Тарифы транспорта для выезда болельщиков';
COMMENT ON TABLE hype_rule IS 'Прирост или падение ажиотажа по причинам';
COMMENT ON TABLE campaign_type IS 'Каталог акций и маркетинговых кампаний';
COMMENT ON TABLE academy_level_rule IS 'Уровни молодёжной академии: размер набора и стоимость улучшения';
COMMENT ON TABLE sponsor_slot_rule IS 'Слоты спонсоров по типу владельца клуба';
COMMENT ON TABLE app_user IS 'Аккаунты игроков';
COMMENT ON TABLE auth_identity IS 'Способы входа через внешние сервисы (VK, Яндекс, Telegram)';
COMMENT ON TABLE email_verification IS 'Токены подтверждения email';
COMMENT ON TABLE game_save IS 'Сохранения партий (до 5 на аккаунт, только автосохранение)';
COMMENT ON TABLE season IS 'Игровые сезоны в рамках сохранения';
COMMENT ON TABLE transfer_window IS 'Трансферные окна (летнее длинное, зимнее короткое)';
COMMENT ON TABLE city IS 'Города в рамках сохранения';
COMMENT ON TABLE city_culture_history IS 'История культуры баскетбола города по сезонам';
COMMENT ON TABLE owner IS 'Владельцы клубов (государство или частные)';
COMMENT ON TABLE club IS 'Клубы в рамках сохранения';
COMMENT ON TABLE club_league_membership IS 'Принадлежность клуба к лиге по сезонам';
COMMENT ON TABLE arena IS 'Арены клубов (у клуба без арены — арендованный зал)';
COMMENT ON TABLE arena_sector IS 'Секторы арены (схема мест)';
COMMENT ON TABLE arena_project IS 'Проекты строительства и реконструкции арены';
COMMENT ON TABLE coach IS 'Тренеры (тактику и ход матча решает главный тренер)';
COMMENT ON TABLE player IS 'Игроки (в интерфейсе характеристики показываются ярлыками, без цифр)';
COMMENT ON TABLE staff IS 'Сотрудники штаба (врач, скаут, маркетинг, физподготовка, PR)';
COMMENT ON TABLE contract IS 'Контракты игроков, тренеров и сотрудников (каждый — ровно с одним человеком)';
COMMENT ON TABLE club_staff_slot IS 'Сколько слотов каждой роли штаба открыто у клуба';
COMMENT ON TABLE manager_career IS 'Менеджерская карьера игрока: клубы, увольнения';
COMMENT ON TABLE sponsor IS 'Спонсоры (коммерческие, город, край)';
COMMENT ON TABLE sponsor_deal IS 'Спонсорские договоры клубов и предложения';
COMMENT ON TABLE finance_record IS 'Журнал доходов и расходов клуба';
COMMENT ON TABLE fan_base IS 'Текущие показатели болельщиков клуба';
COMMENT ON TABLE fan_base_history IS 'История показателей болельщиков по месяцам';
COMMENT ON TABLE fan_campaign IS 'Запущенные акции и кампании клуба';
COMMENT ON TABLE sector_price IS 'Базовые цены билетов клуба по типам мест';
COMMENT ON TABLE season_pass IS 'Абонементы на сезон (продаются на старте сезона)';
COMMENT ON TABLE match_ticket_sales IS 'Продажа билетов на домашний матч по типам мест';
COMMENT ON TABLE ticket_sales_daily IS 'Динамика продаж билетов по дням';
COMMENT ON TABLE match_finance IS 'Расходы на проведение матча';
COMMENT ON TABLE away_trip IS 'Организация выезда болельщиков на матч';
COMMENT ON TABLE competition IS 'Розыгрыши (лига или кубок) в рамках сезона';
COMMENT ON TABLE match IS 'Матчи';
COMMENT ON TABLE player_match_stat IS 'Статистика игроков в матчах';
COMMENT ON TABLE standings IS 'Турнирная таблица розыгрыша';
COMMENT ON TABLE playoff_series IS 'Серии плей-офф';
COMMENT ON TABLE promotion_application IS 'Заявки клубов на повышение в лигу (автоматического повышения нет)';
COMMENT ON TABLE club_season_summary IS 'Итоги сезонов клуба (история клуба)';
COMMENT ON TABLE owner_goal IS 'Цели владельца на сезон';
COMMENT ON TABLE transfer_offer IS 'Трансферные предложения';
COMMENT ON TABLE scouting_task IS 'Задания скаутам';
COMMENT ON TABLE scouting_result IS 'Игроки, найденные по заданию скаута';
COMMENT ON TABLE player_visibility IS 'Скрытые игроки, открытые клубу скаутингом';
COMMENT ON TABLE youth_academy IS 'Молодёжная академия клуба (генератор молодых игроков)';
COMMENT ON TABLE youth_intake IS 'Ежегодный набор воспитанников академии';
COMMENT ON TABLE game_event IS 'Лента событий клуба (входящие)';
COMMENT ON TABLE day_log IS 'Дневной журнал расчёта игры для ленты дней';


COMMENT ON COLUMN region.id IS 'идентификатор региона';
COMMENT ON COLUMN region.name IS 'название региона';
COMMENT ON COLUMN region.population IS 'население региона, чел.';
COMMENT ON COLUMN region.income_per_capita IS 'средний доход на человека, руб. в месяц';
COMMENT ON COLUMN region.sport_support IS 'уровень поддержки спорта властью региона';

COMMENT ON COLUMN league.id IS 'идентификатор лиги';
COMMENT ON COLUMN league.name IS 'название лиги';
COMMENT ON COLUMN league.tier IS 'уровень лиги: 1 — высшая';
COMMENT ON COLUMN league.teams_count IS 'число команд в лиге';
COMMENT ON COLUMN league.salary_cap IS 'потолок фонда зарплат клуба за сезон';
COMMENT ON COLUMN league.salary_floor IS 'нижняя граница фонда зарплат';
COMMENT ON COLUMN league.foreign_limit IS 'максимум легионеров в заявке';

COMMENT ON COLUMN league_rule.league_id IS 'лига';
COMMENT ON COLUMN league_rule.playoff_spots IS 'сколько команд выходит в плей-офф';
COMMENT ON COLUMN league_rule.promotion_spots IS 'сколько мест дают право на повышение';
COMMENT ON COLUMN league_rule.relegation_spots IS 'сколько мест вылетает вниз';
COMMENT ON COLUMN league_rule.series_length IS 'серия плей-офф идёт до стольких побед';

COMMENT ON COLUMN league_requirement.league_id IS 'лига, в которую хотят войти';
COMMENT ON COLUMN league_requirement.min_arena_capacity IS 'минимальная вместимость арены';
COMMENT ON COLUMN league_requirement.min_balance IS 'минимальный баланс клуба';
COMMENT ON COLUMN league_requirement.min_roster IS 'минимальный размер состава';
COMMENT ON COLUMN league_requirement.min_reputation IS 'минимальная репутация клуба';

COMMENT ON COLUMN cup.id IS 'идентификатор кубка';
COMMENT ON COLUMN cup.name IS 'название кубка';
COMMENT ON COLUMN cup.format IS 'формат розыгрыша (описание)';
COMMENT ON COLUMN cup.prize_fund IS 'призовой фонд';

COMMENT ON COLUMN game_config.key IS 'ключ настройки';
COMMENT ON COLUMN game_config.value IS 'числовое значение';
COMMENT ON COLUMN game_config.description IS 'что настройка означает';

COMMENT ON COLUMN staff_role.role IS 'код роли: doctor, scout, marketing, fitness, pr';
COMMENT ON COLUMN staff_role.title IS 'название роли для интерфейса';
COMMENT ON COLUMN staff_role.max_slots IS 'максимум слотов на роль (1 для ролей с единственным человеком)';

COMMENT ON COLUMN slot_unlock_rule.role IS 'роль штаба';
COMMENT ON COLUMN slot_unlock_rule.slot_number IS 'номер открываемого слота';
COMMENT ON COLUMN slot_unlock_rule.conditions IS 'условия, например {"min_reputation":60,"min_league_tier":2,"min_years":3}';

COMMENT ON COLUMN sector_unlock_rule.kind IS 'тип мест';
COMMENT ON COLUMN sector_unlock_rule.conditions IS 'условия открытия, например {"max_league_tier":2,"min_years":3,"min_reputation":60}';

COMMENT ON COLUMN arena_limit_rule.min_reputation IS 'с какой репутации действует строка';
COMMENT ON COLUMN arena_limit_rule.max_tiers IS 'максимум ярусов';
COMMENT ON COLUMN arena_limit_rule.max_capacity IS 'максимум посадочных мест';

COMMENT ON COLUMN arena_template.id IS 'идентификатор шаблона';
COMMENT ON COLUMN arena_template.name IS 'название формы (прямоугольная, овальная, подкова)';
COMMENT ON COLUMN arena_template.sector_slots IS 'слоты секторов шаблона: положение на плане и максимумы';

COMMENT ON COLUMN ticket_markup_rule.reason IS 'причина надбавки';
COMMENT ON COLUMN ticket_markup_rule.multiplier IS 'множитель к цене';

COMMENT ON COLUMN day_demand_factor.weekday IS 'день недели: 1 — понедельник';
COMMENT ON COLUMN day_demand_factor.factor IS 'множитель спроса';

COMMENT ON COLUMN transport_rate.transport IS 'вид транспорта';
COMMENT ON COLUMN transport_rate.cost_per_km IS 'стоимость за километр на человека';
COMMENT ON COLUMN transport_rate.min_km IS 'минимальное расстояние, на котором вариант доступен';
COMMENT ON COLUMN transport_rate.max_km IS 'максимальное расстояние (пусто — без ограничения)';
COMMENT ON COLUMN transport_rate.lodging_from_km IS 'с какого расстояния нужен ночлег';

COMMENT ON COLUMN hype_rule.reason IS 'причина: win, win_streak, upset_win, loss, star_signing, playoff, campaign';
COMMENT ON COLUMN hype_rule.delta IS 'изменение ажиотажа (может быть отрицательным)';

COMMENT ON COLUMN campaign_type.id IS 'идентификатор типа акции';
COMMENT ON COLUMN campaign_type.name IS 'название акции';
COMMENT ON COLUMN campaign_type.base_cost IS 'базовая стоимость';
COMMENT ON COLUMN campaign_type.duration_days IS 'длительность, дней';
COMMENT ON COLUMN campaign_type.cooldown_days IS 'перерыв перед повтором, дней';
COMMENT ON COLUMN campaign_type.effect_loyalty IS 'ожидаемый прирост лояльности';
COMMENT ON COLUMN campaign_type.effect_hype IS 'ожидаемый прирост ажиотажа';
COMMENT ON COLUMN campaign_type.effect_base_pct IS 'ожидаемый рост базы болельщиков, %';
COMMENT ON COLUMN campaign_type.effect_culture IS 'ожидаемый рост культуры города';
COMMENT ON COLUMN campaign_type.needs_marketing IS 'нужен ли менеджер по маркетингу';

COMMENT ON COLUMN academy_level_rule.level IS 'уровень академии';
COMMENT ON COLUMN academy_level_rule.intake_size IS 'сколько воспитанников в ежегодном наборе';
COMMENT ON COLUMN academy_level_rule.talent_boost IS 'бонус к потолку талантов';
COMMENT ON COLUMN academy_level_rule.upgrade_cost IS 'стоимость перехода на этот уровень';

COMMENT ON COLUMN sponsor_slot_rule.owner_type IS 'тип владельца';
COMMENT ON COLUMN sponsor_slot_rule.slot IS 'title — титульный, partner — смежный';
COMMENT ON COLUMN sponsor_slot_rule.max_slots IS 'максимум договоров этого слота';

COMMENT ON COLUMN app_user.id IS 'идентификатор пользователя';
COMMENT ON COLUMN app_user.email IS 'email (пусто у гостей и при входе через соцсети)';
COMMENT ON COLUMN app_user.password_hash IS 'хэш пароля (пусто при входе через соцсети)';
COMMENT ON COLUMN app_user.email_verified_at IS 'когда подтверждён email (пусто — не подтверждён)';
COMMENT ON COLUMN app_user.is_guest IS 'гостевой аккаунт (режим появится позже)';
COMMENT ON COLUMN app_user.created_at IS 'дата регистрации';

COMMENT ON COLUMN auth_identity.id IS 'идентификатор записи';
COMMENT ON COLUMN auth_identity.user_id IS 'пользователь';
COMMENT ON COLUMN auth_identity.provider IS 'внешний сервис';
COMMENT ON COLUMN auth_identity.provider_uid IS 'идентификатор пользователя во внешнем сервисе';
COMMENT ON COLUMN auth_identity.created_at IS 'когда привязан';

COMMENT ON COLUMN email_verification.id IS 'идентификатор записи';
COMMENT ON COLUMN email_verification.user_id IS 'пользователь';
COMMENT ON COLUMN email_verification.token_hash IS 'хэш токена из письма';
COMMENT ON COLUMN email_verification.expires_at IS 'срок действия токена';
COMMENT ON COLUMN email_verification.used_at IS 'когда использован (пусто — не использован)';

COMMENT ON COLUMN game_save.id IS 'идентификатор сохранения';
COMMENT ON COLUMN game_save.user_id IS 'владелец сохранения';
COMMENT ON COLUMN game_save.name IS 'название сохранения';
COMMENT ON COLUMN game_save.game_date IS 'текущая игровая дата';
COMMENT ON COLUMN game_save.user_club_id IS 'клуб, которым управляет игрок (FK добавлен ниже)';
COMMENT ON COLUMN game_save.manager_reputation IS 'репутация менеджера';
COMMENT ON COLUMN game_save.created_at IS 'когда создано';
COMMENT ON COLUMN game_save.last_played_at IS 'когда игрок заходил в последний раз';

COMMENT ON COLUMN season.id IS 'идентификатор сезона';
COMMENT ON COLUMN season.save_id IS 'сохранение';
COMMENT ON COLUMN season.year_start IS 'год начала сезона';
COMMENT ON COLUMN season.phase IS 'текущая фаза сезона';
COMMENT ON COLUMN season.league_application_deadline IS 'крайний срок подачи заявки в лигу';

COMMENT ON COLUMN transfer_window.id IS 'идентификатор окна';
COMMENT ON COLUMN transfer_window.season_id IS 'сезон';
COMMENT ON COLUMN transfer_window.kind IS 'вид окна';
COMMENT ON COLUMN transfer_window.start_date IS 'дата открытия';
COMMENT ON COLUMN transfer_window.end_date IS 'дата закрытия';

COMMENT ON COLUMN city.id IS 'идентификатор города';
COMMENT ON COLUMN city.save_id IS 'сохранение';
COMMENT ON COLUMN city.region_id IS 'регион';
COMMENT ON COLUMN city.name IS 'название города';
COMMENT ON COLUMN city.population IS 'население, чел.';
COMMENT ON COLUMN city.basketball_culture IS 'культура баскетбола (растёт медленно)';
COMMENT ON COLUMN city.sport_competition IS 'конкуренция других видов спорта и развлечений';
COMMENT ON COLUMN city.has_arena IS 'есть ли в городе арена';
COMMENT ON COLUMN city.latitude IS 'широта (для карты и расчёта расстояний)';
COMMENT ON COLUMN city.longitude IS 'долгота';

COMMENT ON COLUMN city_culture_history.city_id IS 'город';
COMMENT ON COLUMN city_culture_history.season_id IS 'сезон';
COMMENT ON COLUMN city_culture_history.culture IS 'значение культуры на конец сезона';

COMMENT ON COLUMN owner.id IS 'идентификатор владельца';
COMMENT ON COLUMN owner.save_id IS 'сохранение';
COMMENT ON COLUMN owner.type IS 'тип: государство, частный, смешанный';
COMMENT ON COLUMN owner.name IS 'название или имя владельца';
COMMENT ON COLUMN owner.expectation_rank IS 'ожидаемое место в лиге';
COMMENT ON COLUMN owner.expectation_profit IS 'ожидаемая прибыль или баланс';
COMMENT ON COLUMN owner.patience IS 'терпение владельца (0 — потеряно)';

COMMENT ON COLUMN club.id IS 'идентификатор клуба';
COMMENT ON COLUMN club.save_id IS 'сохранение';
COMMENT ON COLUMN club.city_id IS 'город клуба';
COMMENT ON COLUMN club.league_id IS 'текущая лига';
COMMENT ON COLUMN club.owner_id IS 'владелец';
COMMENT ON COLUMN club.name IS 'название клуба';
COMMENT ON COLUMN club.founded_year IS 'год основания';
COMMENT ON COLUMN club.budget IS 'текущий баланс';
COMMENT ON COLUMN club.annual_budget IS 'плановый годовой бюджет';
COMMENT ON COLUMN club.reputation IS 'репутация клуба';
COMMENT ON COLUMN club.primary_color IS 'основной цвет (#RRGGBB)';
COMMENT ON COLUMN club.secondary_color IS 'дополнительный цвет (#RRGGBB)';
COMMENT ON COLUMN club.is_real IS 'реальный клуб из базы';
COMMENT ON COLUMN club.is_user_created IS 'создан игроком';
COMMENT ON COLUMN club.access_tier IS 'доступность для выбора: открыт, закрыт, платная разблокировка';
COMMENT ON COLUMN club.is_top_draw IS 'топ-клуб: даёт автонадбавку к цене билета у соперников';
COMMENT ON COLUMN club.status IS 'формируется, заявка подана, играет в лиге';

COMMENT ON COLUMN club_league_membership.club_id IS 'клуб';
COMMENT ON COLUMN club_league_membership.season_id IS 'сезон';
COMMENT ON COLUMN club_league_membership.league_id IS 'лига, в которой клуб играл';

COMMENT ON COLUMN arena.id IS 'идентификатор арены';
COMMENT ON COLUMN arena.club_id IS 'клуб';
COMMENT ON COLUMN arena.name IS 'название арены';
COMMENT ON COLUMN arena.kind IS 'вид: арендованный зал, школьный зал, арена';
COMMENT ON COLUMN arena.capacity IS 'суммарная вместимость (сумма секторов)';
COMMENT ON COLUMN arena.condition IS 'износ и состояние арены';
COMMENT ON COLUMN arena.upkeep_cost IS 'стоимость содержания';
COMMENT ON COLUMN arena.guest_quota_pct IS 'доля мест под гостевой сектор, %';

COMMENT ON COLUMN arena_sector.id IS 'идентификатор сектора';
COMMENT ON COLUMN arena_sector.arena_id IS 'арена';
COMMENT ON COLUMN arena_sector.name IS 'название сектора';
COMMENT ON COLUMN arena_sector.kind IS 'тип мест: VIP, партер, обычные';
COMMENT ON COLUMN arena_sector.tier IS 'ярус';
COMMENT ON COLUMN arena_sector.rows_count IS 'число рядов';
COMMENT ON COLUMN arena_sector.seats_per_row IS 'мест в ряду';
COMMENT ON COLUMN arena_sector.capacity IS 'вместимость сектора';
COMMENT ON COLUMN arena_sector.geometry IS 'положение сектора на плане для отрисовки';

COMMENT ON COLUMN arena_project.id IS 'идентификатор проекта';
COMMENT ON COLUMN arena_project.club_id IS 'клуб';
COMMENT ON COLUMN arena_project.type IS 'строительство, расширение, перестройка';
COMMENT ON COLUMN arena_project.template_id IS 'выбранный шаблон формы';
COMMENT ON COLUMN arena_project.layout IS 'планируемая схема секторов';
COMMENT ON COLUMN arena_project.cost IS 'смета с учётом скидки';
COMMENT ON COLUMN arena_project.discount_pct IS 'скидка (например, для государственных клубов), %';
COMMENT ON COLUMN arena_project.funded IS 'сколько финансирования уже собрано';
COMMENT ON COLUMN arena_project.start_date IS 'дата начала работ';
COMMENT ON COLUMN arena_project.end_date IS 'плановая дата завершения';
COMMENT ON COLUMN arena_project.status IS 'статус проекта';

COMMENT ON COLUMN coach.id IS 'идентификатор тренера';
COMMENT ON COLUMN coach.save_id IS 'сохранение';
COMMENT ON COLUMN coach.club_id IS 'текущий клуб (пусто — без клуба)';
COMMENT ON COLUMN coach.full_name IS 'имя тренера';
COMMENT ON COLUMN coach.birth_date IS 'дата рождения';
COMMENT ON COLUMN coach.tactics_skill IS 'тактика';
COMMENT ON COLUMN coach.youth_skill IS 'работа с молодёжью';
COMMENT ON COLUMN coach.motivation_skill IS 'мотивация';
COMMENT ON COLUMN coach.reputation IS 'репутация тренера';
COMMENT ON COLUMN coach.preferred_style IS 'любимый стиль игры';

COMMENT ON COLUMN player.id IS 'идентификатор игрока';
COMMENT ON COLUMN player.save_id IS 'сохранение';
COMMENT ON COLUMN player.club_id IS 'текущий клуб (пусто — свободный агент)';
COMMENT ON COLUMN player.full_name IS 'имя игрока';
COMMENT ON COLUMN player.birth_date IS 'дата рождения';
COMMENT ON COLUMN player.nationality IS 'гражданство';
COMMENT ON COLUMN player.height_cm IS 'рост, см';
COMMENT ON COLUMN player.position IS 'позиция';
COMMENT ON COLUMN player.attack IS 'атака';
COMMENT ON COLUMN player.defense IS 'защита';
COMMENT ON COLUMN player.physical IS 'физика';
COMMENT ON COLUMN player.basketball_iq IS 'баскетбольный интеллект';
COMMENT ON COLUMN player.potential IS 'истинный потенциал (игроку показывается размыто)';
COMMENT ON COLUMN player.form IS 'текущая форма';
COMMENT ON COLUMN player.fatigue IS 'усталость';
COMMENT ON COLUMN player.morale IS 'мораль';
COMMENT ON COLUMN player.injury_until IS 'до какой даты травма (пусто — здоров)';
COMMENT ON COLUMN player.is_foreign IS 'легионер';
COMMENT ON COLUMN player.is_youth IS 'молодёжный игрок';
COMMENT ON COLUMN player.source IS 'откуда игрок: академия, рынок, реальная база';
COMMENT ON COLUMN player.academy_status IS 'состояние воспитанника академии';

COMMENT ON COLUMN staff.id IS 'идентификатор сотрудника';
COMMENT ON COLUMN staff.save_id IS 'сохранение';
COMMENT ON COLUMN staff.club_id IS 'текущий клуб';
COMMENT ON COLUMN staff.role IS 'роль';
COMMENT ON COLUMN staff.full_name IS 'имя сотрудника';
COMMENT ON COLUMN staff.skill IS 'навык';
COMMENT ON COLUMN staff.salary IS 'зарплата';

COMMENT ON COLUMN contract.id IS 'идентификатор контракта';
COMMENT ON COLUMN contract.save_id IS 'сохранение';
COMMENT ON COLUMN contract.club_id IS 'клуб';
COMMENT ON COLUMN contract.player_id IS 'игрок (если контракт игрока)';
COMMENT ON COLUMN contract.coach_id IS 'тренер (если контракт тренера)';
COMMENT ON COLUMN contract.staff_id IS 'сотрудник (если контракт сотрудника)';
COMMENT ON COLUMN contract.salary IS 'зарплата';
COMMENT ON COLUMN contract.start_date IS 'начало контракта';
COMMENT ON COLUMN contract.end_date IS 'окончание контракта';
COMMENT ON COLUMN contract.bonus_per_win IS 'бонус за победу';
COMMENT ON COLUMN contract.release_clause IS 'сумма выкупа контракта';

COMMENT ON COLUMN club_staff_slot.club_id IS 'клуб';
COMMENT ON COLUMN club_staff_slot.role IS 'роль штаба';
COMMENT ON COLUMN club_staff_slot.slots_open IS 'открыто слотов (у нового клуба — 1)';

COMMENT ON COLUMN manager_career.id IS 'идентификатор записи';
COMMENT ON COLUMN manager_career.save_id IS 'сохранение';
COMMENT ON COLUMN manager_career.club_id IS 'клуб';
COMMENT ON COLUMN manager_career.from_date IS 'с какой даты менеджер в клубе';
COMMENT ON COLUMN manager_career.to_date IS 'по какую дату (пусто — работает сейчас)';
COMMENT ON COLUMN manager_career.end_reason IS 'причина окончания';

COMMENT ON COLUMN sponsor.id IS 'идентификатор спонсора';
COMMENT ON COLUMN sponsor.save_id IS 'сохранение';
COMMENT ON COLUMN sponsor.name IS 'название';
COMMENT ON COLUMN sponsor.kind IS 'вид: коммерческий, город, край';
COMMENT ON COLUMN sponsor.category IS 'отрасль';
COMMENT ON COLUMN sponsor.min_reputation IS 'минимальная репутация клуба для сделки';
COMMENT ON COLUMN sponsor.min_city_population IS 'минимальное население города';
COMMENT ON COLUMN sponsor.base_amount IS 'базовая годовая сумма';

COMMENT ON COLUMN sponsor_deal.id IS 'идентификатор договора';
COMMENT ON COLUMN sponsor_deal.club_id IS 'клуб';
COMMENT ON COLUMN sponsor_deal.sponsor_id IS 'спонсор';
COMMENT ON COLUMN sponsor_deal.slot IS 'слот: титульный или смежный';
COMMENT ON COLUMN sponsor_deal.amount_per_year IS 'сумма в год';
COMMENT ON COLUMN sponsor_deal.bonus_amount IS 'бонус за выполнение условий';
COMMENT ON COLUMN sponsor_deal.penalty_amount IS 'штраф за невыполнение';
COMMENT ON COLUMN sponsor_deal.start_date IS 'начало договора';
COMMENT ON COLUMN sponsor_deal.end_date IS 'окончание договора';
COMMENT ON COLUMN sponsor_deal.min_rank IS 'условие: занять место не ниже';
COMMENT ON COLUMN sponsor_deal.min_attendance IS 'условие: средняя посещаемость не ниже';
COMMENT ON COLUMN sponsor_deal.is_mandatory IS 'обязательный договор (городской или краевой у госклуба)';
COMMENT ON COLUMN sponsor_deal.status IS 'статус договора';
COMMENT ON COLUMN sponsor_deal.offer_expires_on IS 'до какой даты действует предложение';

COMMENT ON COLUMN finance_record.id IS 'идентификатор записи';
COMMENT ON COLUMN finance_record.club_id IS 'клуб';
COMMENT ON COLUMN finance_record.season_id IS 'сезон';
COMMENT ON COLUMN finance_record.month IS 'первое число месяца';
COMMENT ON COLUMN finance_record.category IS 'статья дохода или расхода';
COMMENT ON COLUMN finance_record.amount IS 'сумма: плюс — доход, минус — расход';
COMMENT ON COLUMN finance_record.match_id IS 'матч, к которому относится запись (FK добавлен ниже)';

COMMENT ON COLUMN fan_base.club_id IS 'клуб';
COMMENT ON COLUMN fan_base.size IS 'размер базы болельщиков';
COMMENT ON COLUMN fan_base.loyalty IS 'лояльность (медленно меняется)';
COMMENT ON COLUMN fan_base.hype IS 'ажиотаж (быстро растёт и затухает)';
COMMENT ON COLUMN fan_base.city_share IS 'доля внимания города, %';
COMMENT ON COLUMN fan_base.avg_attendance IS 'средняя посещаемость домашних матчей';

COMMENT ON COLUMN fan_base_history.club_id IS 'клуб';
COMMENT ON COLUMN fan_base_history.month IS 'первое число месяца';
COMMENT ON COLUMN fan_base_history.size IS 'размер базы';
COMMENT ON COLUMN fan_base_history.loyalty IS 'лояльность';
COMMENT ON COLUMN fan_base_history.hype IS 'ажиотаж';
COMMENT ON COLUMN fan_base_history.city_share IS 'доля города, %';
COMMENT ON COLUMN fan_base_history.avg_attendance IS 'средняя посещаемость';
COMMENT ON COLUMN fan_base_history.factors IS 'вклад факторов в изменение (для блока «Что влияет»)';

COMMENT ON COLUMN fan_campaign.id IS 'идентификатор акции';
COMMENT ON COLUMN fan_campaign.club_id IS 'клуб';
COMMENT ON COLUMN fan_campaign.campaign_type_id IS 'тип акции';
COMMENT ON COLUMN fan_campaign.cost IS 'фактическая стоимость';
COMMENT ON COLUMN fan_campaign.start_date IS 'начало';
COMMENT ON COLUMN fan_campaign.end_date IS 'окончание';
COMMENT ON COLUMN fan_campaign.status IS 'статус';
COMMENT ON COLUMN fan_campaign.result IS 'фактический результат (лояльность, ажиотаж, база, культура)';

COMMENT ON COLUMN sector_price.club_id IS 'клуб';
COMMENT ON COLUMN sector_price.kind IS 'тип мест';
COMMENT ON COLUMN sector_price.price IS 'базовая цена билета';

COMMENT ON COLUMN season_pass.id IS 'идентификатор';
COMMENT ON COLUMN season_pass.club_id IS 'клуб';
COMMENT ON COLUMN season_pass.season_id IS 'сезон';
COMMENT ON COLUMN season_pass.kind IS 'тип мест';
COMMENT ON COLUMN season_pass.price IS 'цена абонемента';
COMMENT ON COLUMN season_pass.quota IS 'сколько мест отдано под абонементы';
COMMENT ON COLUMN season_pass.sold IS 'продано абонементов';
COMMENT ON COLUMN season_pass.sales_open IS 'начало продаж';
COMMENT ON COLUMN season_pass.sales_close IS 'конец продаж';

COMMENT ON COLUMN match_ticket_sales.match_id IS 'матч (FK добавлен ниже)';
COMMENT ON COLUMN match_ticket_sales.kind IS 'тип мест';
COMMENT ON COLUMN match_ticket_sales.price IS 'итоговая цена с автонадбавкой';
COMMENT ON COLUMN match_ticket_sales.markup_reason IS 'причина автонадбавки (top_opponent, playoff)';
COMMENT ON COLUMN match_ticket_sales.capacity IS 'мест в продаже (за вычетом абонементов)';
COMMENT ON COLUMN match_ticket_sales.sold IS 'продано билетов';
COMMENT ON COLUMN match_ticket_sales.sales_opened_on IS 'когда игрок открыл продажу (пусто — не открыта)';

COMMENT ON COLUMN ticket_sales_daily.match_id IS 'матч (FK добавлен ниже)';
COMMENT ON COLUMN ticket_sales_daily.kind IS 'тип мест';
COMMENT ON COLUMN ticket_sales_daily.day IS 'игровой день';
COMMENT ON COLUMN ticket_sales_daily.sold IS 'продано за день';

COMMENT ON COLUMN match_finance.match_id IS 'матч (FK добавлен ниже)';
COMMENT ON COLUMN match_finance.club_id IS 'клуб, который несёт расходы';
COMMENT ON COLUMN match_finance.arena_cost IS 'аренда и обслуживание арены';
COMMENT ON COLUMN match_finance.security_cost IS 'охрана';
COMMENT ON COLUMN match_finance.referee_cost IS 'судьи';
COMMENT ON COLUMN match_finance.travel_cost IS 'логистика выездного матча';
COMMENT ON COLUMN match_finance.service_level IS 'уровень организации';

COMMENT ON COLUMN away_trip.id IS 'идентификатор выезда';
COMMENT ON COLUMN away_trip.club_id IS 'клуб';
COMMENT ON COLUMN away_trip.match_id IS 'выездной матч (FK добавлен ниже)';
COMMENT ON COLUMN away_trip.transport IS 'транспорт';
COMMENT ON COLUMN away_trip.subsidy_pct IS 'доля стоимости, которую берёт клуб, %';
COMMENT ON COLUMN away_trip.seats_ordered IS 'заказано мест в гостевом секторе';
COMMENT ON COLUMN away_trip.distance_km IS 'расстояние до города соперника';
COMMENT ON COLUMN away_trip.planned_fans IS 'ожидаемое число поехавших';
COMMENT ON COLUMN away_trip.actual_fans IS 'сколько поехало на самом деле';
COMMENT ON COLUMN away_trip.cost IS 'итоговые расходы клуба';
COMMENT ON COLUMN away_trip.cost_breakdown IS 'разбивка: дорога, ночлег, субсидия';
COMMENT ON COLUMN away_trip.status IS 'статус';

COMMENT ON COLUMN competition.id IS 'идентификатор розыгрыша';
COMMENT ON COLUMN competition.season_id IS 'сезон';
COMMENT ON COLUMN competition.league_id IS 'лига (если это чемпионат)';
COMMENT ON COLUMN competition.cup_id IS 'кубок (если это кубок)';

COMMENT ON COLUMN match.id IS 'идентификатор матча';
COMMENT ON COLUMN match.competition_id IS 'розыгрыш';
COMMENT ON COLUMN match.match_date IS 'игровая дата';
COMMENT ON COLUMN match.stage IS 'этап: тур, 1/4, финал';
COMMENT ON COLUMN match.home_club_id IS 'хозяева';
COMMENT ON COLUMN match.away_club_id IS 'гости';
COMMENT ON COLUMN match.home_score IS 'очки хозяев';
COMMENT ON COLUMN match.away_score IS 'очки гостей';
COMMENT ON COLUMN match.quarter_scores IS 'счёт по четвертям';
COMMENT ON COLUMN match.attendance IS 'посещаемость';
COMMENT ON COLUMN match.summary IS 'текстовая хроника матча';
COMMENT ON COLUMN match.played IS 'матч сыгран';

COMMENT ON COLUMN player_match_stat.match_id IS 'матч';
COMMENT ON COLUMN player_match_stat.player_id IS 'игрок';
COMMENT ON COLUMN player_match_stat.minutes IS 'минуты на площадке';
COMMENT ON COLUMN player_match_stat.points IS 'очки';
COMMENT ON COLUMN player_match_stat.rebounds IS 'подборы';
COMMENT ON COLUMN player_match_stat.assists IS 'передачи';

COMMENT ON COLUMN standings.competition_id IS 'розыгрыш';
COMMENT ON COLUMN standings.club_id IS 'клуб';
COMMENT ON COLUMN standings.wins IS 'победы';
COMMENT ON COLUMN standings.losses IS 'поражения';
COMMENT ON COLUMN standings.points_for IS 'набранные очки';
COMMENT ON COLUMN standings.points_against IS 'пропущенные очки';

COMMENT ON COLUMN playoff_series.id IS 'идентификатор серии';
COMMENT ON COLUMN playoff_series.competition_id IS 'розыгрыш';
COMMENT ON COLUMN playoff_series.round IS 'раунд';
COMMENT ON COLUMN playoff_series.club_a_id IS 'первый клуб';
COMMENT ON COLUMN playoff_series.club_b_id IS 'второй клуб';
COMMENT ON COLUMN playoff_series.wins_a IS 'победы первого клуба в серии';
COMMENT ON COLUMN playoff_series.wins_b IS 'победы второго клуба в серии';
COMMENT ON COLUMN playoff_series.winner_id IS 'победитель серии';

COMMENT ON COLUMN promotion_application.id IS 'идентификатор заявки';
COMMENT ON COLUMN promotion_application.club_id IS 'клуб';
COMMENT ON COLUMN promotion_application.season_id IS 'сезон';
COMMENT ON COLUMN promotion_application.from_league IS 'текущая лига';
COMMENT ON COLUMN promotion_application.to_league IS 'лига, в которую клуб имеет право подняться';
COMMENT ON COLUMN promotion_application.status IS 'право есть, подана, отказ остаться на год, условия не выполнены, принята';
COMMENT ON COLUMN promotion_application.deadline IS 'крайний срок подачи';
COMMENT ON COLUMN promotion_application.checklist IS 'результат проверки требований по пунктам';

COMMENT ON COLUMN club_season_summary.club_id IS 'клуб';
COMMENT ON COLUMN club_season_summary.season_id IS 'сезон';
COMMENT ON COLUMN club_season_summary.league_id IS 'лига сезона';
COMMENT ON COLUMN club_season_summary.final_rank IS 'итоговое место';
COMMENT ON COLUMN club_season_summary.wins IS 'победы';
COMMENT ON COLUMN club_season_summary.losses IS 'поражения';
COMMENT ON COLUMN club_season_summary.cup_result IS 'результат в кубках';
COMMENT ON COLUMN club_season_summary.trophies IS 'завоёванные трофеи';
COMMENT ON COLUMN club_season_summary.final_balance IS 'баланс на конец сезона';

COMMENT ON COLUMN owner_goal.id IS 'идентификатор цели';
COMMENT ON COLUMN owner_goal.club_id IS 'клуб';
COMMENT ON COLUMN owner_goal.season_id IS 'сезон';
COMMENT ON COLUMN owner_goal.type IS 'вид цели: rank, profit, arena, roster';
COMMENT ON COLUMN owner_goal.target IS 'целевое значение';
COMMENT ON COLUMN owner_goal.status IS 'статус цели';

COMMENT ON COLUMN transfer_offer.id IS 'идентификатор предложения';
COMMENT ON COLUMN transfer_offer.save_id IS 'сохранение';
COMMENT ON COLUMN transfer_offer.player_id IS 'игрок';
COMMENT ON COLUMN transfer_offer.from_club_id IS 'продающий клуб (пусто — свободный агент)';
COMMENT ON COLUMN transfer_offer.to_club_id IS 'покупающий клуб';
COMMENT ON COLUMN transfer_offer.fee IS 'сумма трансфера';
COMMENT ON COLUMN transfer_offer.offered_salary IS 'предложенная игроку зарплата';
COMMENT ON COLUMN transfer_offer.offered_years IS 'предложенный срок контракта, лет';
COMMENT ON COLUMN transfer_offer.status IS 'статус';
COMMENT ON COLUMN transfer_offer.created_on IS 'дата создания';
COMMENT ON COLUMN transfer_offer.expires_on IS 'срок действия предложения';

COMMENT ON COLUMN scouting_task.id IS 'идентификатор задания';
COMMENT ON COLUMN scouting_task.club_id IS 'клуб';
COMMENT ON COLUMN scouting_task.scout_id IS 'скаут';
COMMENT ON COLUMN scouting_task.target_region IS 'регион или страна поиска';
COMMENT ON COLUMN scouting_task.target_position IS 'искомая позиция';
COMMENT ON COLUMN scouting_task.progress IS 'прогресс задания, %';
COMMENT ON COLUMN scouting_task.started_at IS 'дата начала';

COMMENT ON COLUMN scouting_result.task_id IS 'задание';
COMMENT ON COLUMN scouting_result.player_id IS 'найденный игрок';

COMMENT ON COLUMN player_visibility.club_id IS 'клуб';
COMMENT ON COLUMN player_visibility.player_id IS 'открытый игрок';

COMMENT ON COLUMN youth_academy.club_id IS 'клуб';
COMMENT ON COLUMN youth_academy.type IS 'тип: школьная, клубная, профессиональная';
COMMENT ON COLUMN youth_academy.level IS 'уровень';
COMMENT ON COLUMN youth_academy.talent_ceiling IS 'потолок талантов';
COMMENT ON COLUMN youth_academy.yearly_cost IS 'годовые расходы';

COMMENT ON COLUMN youth_intake.id IS 'идентификатор набора';
COMMENT ON COLUMN youth_intake.club_id IS 'клуб';
COMMENT ON COLUMN youth_intake.season_id IS 'сезон';
COMMENT ON COLUMN youth_intake.size IS 'сколько воспитанников сгенерировано';

COMMENT ON COLUMN game_event.id IS 'идентификатор события';
COMMENT ON COLUMN game_event.save_id IS 'сохранение';
COMMENT ON COLUMN game_event.club_id IS 'клуб, которого касается событие';
COMMENT ON COLUMN game_event.event_date IS 'игровая дата события';
COMMENT ON COLUMN game_event.type IS 'тип: injury, conflict, sponsor_offer, transfer_offer, owner_message';
COMMENT ON COLUMN game_event.payload IS 'данные события';
COMMENT ON COLUMN game_event.is_read IS 'прочитано';
COMMENT ON COLUMN game_event.requires_action IS 'требует решения игрока';
COMMENT ON COLUMN game_event.expires_on IS 'срок действия (после него — просрочено)';
COMMENT ON COLUMN game_event.resolution IS 'итог: accepted, declined, expired';

COMMENT ON COLUMN day_log.id IS 'идентификатор записи';
COMMENT ON COLUMN day_log.save_id IS 'сохранение';
COMMENT ON COLUMN day_log.log_date IS 'игровой день';
COMMENT ON COLUMN day_log.summary IS 'сводка дня: баланс, форма, матч, события';
