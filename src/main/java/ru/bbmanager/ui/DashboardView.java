package ru.bbmanager.ui;

import com.vaadin.flow.component.UI;
import com.vaadin.flow.component.button.Button;
import com.vaadin.flow.component.button.ButtonVariant;
import com.vaadin.flow.component.grid.Grid;
import com.vaadin.flow.component.grid.GridVariant;
import com.vaadin.flow.component.html.Div;
import com.vaadin.flow.component.html.H2;
import com.vaadin.flow.component.html.H3;
import com.vaadin.flow.component.html.Paragraph;
import com.vaadin.flow.component.notification.Notification;
import com.vaadin.flow.component.orderedlayout.FlexLayout;
import com.vaadin.flow.component.orderedlayout.VerticalLayout;
import com.vaadin.flow.router.BeforeEnterEvent;
import com.vaadin.flow.router.BeforeEnterObserver;
import com.vaadin.flow.router.PageTitle;
import com.vaadin.flow.router.Route;
import jakarta.annotation.security.PermitAll;
import java.math.BigDecimal;
import java.text.NumberFormat;
import java.time.format.DateTimeFormatter;
import java.time.format.TextStyle;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Optional;
import org.springframework.jdbc.core.JdbcTemplate;
import ru.bbmanager.account.CurrentUserService;
import ru.bbmanager.competition.LeagueQueryService;
import ru.bbmanager.competition.LeagueQueryService.EventLine;
import ru.bbmanager.competition.LeagueQueryService.NextMatch;
import ru.bbmanager.competition.LeagueQueryService.StandingRow;
import ru.bbmanager.game.GameSave;
import ru.bbmanager.game.GameSaveRepository;
import ru.bbmanager.simulation.DaySimulationService;
import ru.bbmanager.simulation.DaySimulationService.AdvanceResult;

/**
 * Экран 5: дашборд партии (упрощённый). Открывается по адресу /game/{id сохранения}.
 * Чужое или несуществующее сохранение открыть нельзя: пользователь возвращается к списку своих игр.
 */
@Route("game/:saveId")
@PageTitle("Партия")
@PermitAll
public class DashboardView extends VerticalLayout implements BeforeEnterObserver {

    private static final Locale RU = Locale.forLanguageTag("ru-RU");
    private static final DateTimeFormatter DATE = DateTimeFormatter.ofPattern("dd.MM.yyyy");
    private static final DateTimeFormatter SHORT_DATE = DateTimeFormatter.ofPattern("dd.MM");

    private final CurrentUserService currentUser;
    private final GameSaveRepository saves;
    private final DaySimulationService simulation;
    private final LeagueQueryService league;
    private final JdbcTemplate jdbc;

    private Integer saveId;

    public DashboardView(CurrentUserService currentUser,
                         GameSaveRepository saves,
                         DaySimulationService simulation,
                         LeagueQueryService league,
                         JdbcTemplate jdbc) {
        this.currentUser = currentUser;
        this.saves = saves;
        this.simulation = simulation;
        this.league = league;
        this.jdbc = jdbc;
    }

    @Override
    public void beforeEnter(BeforeEnterEvent event) {
        Integer userId = currentUser.requireUserId();
        Optional<GameSave> save = event.getRouteParameters().get("saveId")
                .flatMap(DashboardView::parseId)
                .flatMap(saves::findById)
                .filter(s -> userId.equals(s.getUserId()));
        if (save.isEmpty()) {
            event.forwardTo(SavesView.class);
            return;
        }
        this.saveId = save.get().getId();
        render();
    }

    private void render() {
        removeAll();
        GameSave save = saves.findById(saveId).orElseThrow();
        Map<String, Object> info = jdbc.queryForMap("""
                SELECT c.name, ci.name AS city, l.name AS league, c.budget
                  FROM game_save s
                  JOIN club c  ON c.id  = s.user_club_id
                  JOIN city ci ON ci.id = c.city_id
                  JOIN league l ON l.id = c.league_id
                 WHERE s.id = ?
                """, saveId);
        int userClubId = save.getUserClubId();
        boolean finished = "finished".equals(league.seasonPhase(saveId));

        BigDecimal budget = (BigDecimal) info.get("budget");
        String balance = NumberFormat.getIntegerInstance(RU).format(budget.longValue()) + " ₽";

        Button nextDay = new Button("Следующий день", e -> advanceOneDay());
        nextDay.addThemeVariants(ButtonVariant.LUMO_PRIMARY);
        nextDay.setEnabled(!finished);
        Button untilEvent = new Button("До события", e -> advanceUntilEvent());
        untilEvent.setEnabled(!finished);
        Button toSaves = new Button("К моим играм", e -> UI.getCurrent().navigate(SavesView.class));
        FlexLayout buttons = new FlexLayout(nextDay, untilEvent, toSaves);
        buttons.getStyle().set("gap", "var(--lumo-space-s)").set("flex-wrap", "wrap");

        add(new H2((String) info.get("name")),
                new Paragraph(info.get("league") + " · " + info.get("city")),
                new Paragraph("Игровая дата: " + save.getGameDate().format(DATE) + " · Баланс: " + balance),
                buttons);

        if (finished) {
            add(new Paragraph("Сезон завершён. Переход к новому сезону появится на следующем этапе."));
        }
        add(nextMatchBlock(userClubId), eventsBlock(), standingsBlock(userClubId));
    }

    private Div nextMatchBlock(int userClubId) {
        Div block = new Div(new H3("Ближайший матч"));
        Optional<NextMatch> next = league.nextMatch(saveId, userClubId);
        if (next.isEmpty()) {
            block.add(new Paragraph("Матчей больше нет."));
        } else {
            NextMatch m = next.get();
            String day = m.date().getDayOfWeek().getDisplayName(TextStyle.SHORT, RU);
            String opponent = m.userIsHome() ? m.away() : m.home();
            block.add(new Paragraph(m.date().format(DATE) + " (" + day + "), " + m.stage() + ": "
                    + (m.userIsHome() ? "дома против " : "в гостях у ") + opponent));
        }
        return block;
    }

    private Div eventsBlock() {
        Div block = new Div(new H3("Последние события"));
        List<EventLine> events = league.recentEvents(saveId, 5);
        if (events.isEmpty()) {
            block.add(new Paragraph("Пока ничего не произошло."));
        }
        for (EventLine line : events) {
            block.add(new Paragraph(line.date().format(SHORT_DATE) + "  " + line.text()));
        }
        return block;
    }

    private Div standingsBlock(int userClubId) {
        Div block = new Div(new H3("Таблица"));
        List<StandingRow> rows = league.standings(saveId);
        Grid<StandingRow> grid = new Grid<>(StandingRow.class, false);
        grid.addThemeVariants(GridVariant.LUMO_COMPACT, GridVariant.LUMO_NO_BORDER);
        grid.addColumn(StandingRow::place).setHeader("№").setAutoWidth(true).setFlexGrow(0);
        grid.addColumn(StandingRow::club).setHeader("Клуб").setAutoWidth(true).setFlexGrow(1);
        grid.addColumn(StandingRow::played).setHeader("И").setAutoWidth(true).setFlexGrow(0);
        grid.addColumn(StandingRow::wins).setHeader("В").setAutoWidth(true).setFlexGrow(0);
        grid.addColumn(StandingRow::losses).setHeader("П").setAutoWidth(true).setFlexGrow(0);
        grid.addColumn(r -> (r.diff() > 0 ? "+" : "") + r.diff()).setHeader("±").setAutoWidth(true).setFlexGrow(0);
        grid.setPartNameGenerator(r -> r.clubId() == userClubId ? "my-club" : null);
        grid.setItems(rows);
        grid.setAllRowsVisible(true);
        block.add(grid);
        return block;
    }

    private void advanceOneDay() {
        try {
            simulation.advanceDay(saveId);
            render();
        } catch (RuntimeException ex) {
            Notification.show("Не удалось посчитать день: " + ex.getMessage());
        }
    }

    private void advanceUntilEvent() {
        try {
            AdvanceResult result = simulation.advanceUntilEvent(saveId);
            render();
            String reason = switch (result.reason()) {
                case EVENT -> "сыгран матч или случилось событие";
                case SEASON_FINISHED -> "сезон завершён";
                case LIMIT -> "долго не было событий";
            };
            Notification.show("Прошло дней: " + result.days() + ", остановка: " + reason);
        } catch (RuntimeException ex) {
            Notification.show("Не удалось посчитать дни: " + ex.getMessage());
        }
    }

    private static Optional<Integer> parseId(String value) {
        try {
            return Optional.of(Integer.parseInt(value));
        } catch (NumberFormatException e) {
            return Optional.empty();
        }
    }
}
