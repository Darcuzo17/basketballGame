package ru.bbmanager.game;

import java.util.Map;
import org.springframework.dao.EmptyResultDataAccessException;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import ru.bbmanager.competition.ScheduleService;
import ru.bbmanager.config.AppProperties;

/**
 * Старт новой игры: создаёт сохранение и копирует в него мир из шаблона
 * (функция clone_world из миграции V2) и создаёт расписание сезона. Всё в одной транзакции: при любой ошибке
 * не остаётся ни пустого сохранения, ни полукопии мира.
 */
@Service
public class GameStartService {

    private final JdbcTemplate jdbc;
    private final AppProperties props;
    private final ScheduleService scheduleService;

    public GameStartService(JdbcTemplate jdbc, AppProperties props, ScheduleService scheduleService) {
        this.jdbc = jdbc;
        this.props = props;
        this.scheduleService = scheduleService;
    }

    /**
     * @param templateClubId id клуба в шаблоне мира (его отдаёт каталог клубов)
     * @return id созданного сохранения
     */
    @Transactional
    public int startNewGame(int userId, int templateClubId) {
        Integer existing = jdbc.queryForObject(
                "SELECT COUNT(*) FROM game_save WHERE user_id = ?", Integer.class, userId);
        if (existing != null && existing >= props.maxSavesPerUser()) {
            throw new SaveLimitReachedException(props.maxSavesPerUser());
        }

        Integer templateId;
        try {
            templateId = jdbc.queryForObject(
                    "SELECT id FROM game_save WHERE is_template", Integer.class);
        } catch (EmptyResultDataAccessException e) {
            throw new IllegalStateException("Шаблон мира не найден: наполните справочники или включите профиль dev", e);
        }

        Map<String, Object> club;
        try {
            club = jdbc.queryForMap(
                    "SELECT name, access_tier FROM club WHERE id = ? AND save_id = ?",
                    templateClubId, templateId);
        } catch (EmptyResultDataAccessException e) {
            throw new IllegalArgumentException("Клуб " + templateClubId + " не найден в шаблоне мира", e);
        }
        String clubName = (String) club.get("name");
        if (!"open".equals(club.get("access_tier"))) {
            throw new ClubLockedException(clubName);
        }

        Integer saveId = jdbc.queryForObject(
                "INSERT INTO game_save (user_id, name, game_date) "
                        + "SELECT ?, ?, game_date FROM game_save WHERE id = ? RETURNING id",
                Integer.class, userId, clubName, templateId);
        jdbc.queryForObject("SELECT clone_world(?, ?, ?)", Integer.class, templateId, saveId, templateClubId);
        scheduleService.createSeasonSchedule(saveId);
        return saveId;
    }
}
