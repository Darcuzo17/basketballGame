package ru.bbmanager.ui;

import com.vaadin.flow.component.UI;
import com.vaadin.flow.component.button.Button;
import com.vaadin.flow.component.button.ButtonVariant;
import com.vaadin.flow.component.grid.Grid;
import com.vaadin.flow.component.html.H2;
import com.vaadin.flow.component.html.Paragraph;
import com.vaadin.flow.component.orderedlayout.HorizontalLayout;
import com.vaadin.flow.component.orderedlayout.VerticalLayout;
import com.vaadin.flow.router.PageTitle;
import com.vaadin.flow.router.Route;
import com.vaadin.flow.router.RouteParameters;
import com.vaadin.flow.spring.security.AuthenticationContext;
import jakarta.annotation.security.PermitAll;
import java.time.ZoneId;
import java.time.format.DateTimeFormatter;
import java.util.List;
import ru.bbmanager.account.CurrentUserService;
import ru.bbmanager.config.AppProperties;
import ru.bbmanager.game.GameSave;
import ru.bbmanager.game.GameSaveRepository;

/** Экран 2: выбор сохранения. Лимит сохранений берётся из настройки app.max-saves-per-user. */
@Route("")
@PageTitle("Мои игры")
@PermitAll
public class SavesView extends VerticalLayout {

    private static final DateTimeFormatter DATE = DateTimeFormatter.ofPattern("dd.MM.yyyy");
    private static final DateTimeFormatter DATE_TIME = DateTimeFormatter.ofPattern("dd.MM.yyyy HH:mm");

    public SavesView(AuthenticationContext authContext,
                     CurrentUserService currentUser,
                     GameSaveRepository saves,
                     AppProperties props) {
        List<GameSave> list = saves.findByUserIdOrderByLastPlayedAtDesc(currentUser.requireUserId());

        Button logout = new Button("Выйти", e -> authContext.logout());
        HorizontalLayout header = new HorizontalLayout(new H2("Мои игры"), logout);
        header.setWidthFull();
        header.setJustifyContentMode(JustifyContentMode.BETWEEN);
        header.setAlignItems(Alignment.CENTER);
        add(header);

        if (list.isEmpty()) {
            add(new Paragraph("Сохранений пока нет. Начните новую игру."));
        } else {
            Grid<GameSave> grid = new Grid<>(GameSave.class, false);
            grid.addColumn(GameSave::getName).setHeader("Клуб");
            grid.addColumn(s -> s.getGameDate().format(DATE)).setHeader("Игровая дата");
            grid.addColumn(s -> s.getLastPlayedAt().atZone(ZoneId.systemDefault()).format(DATE_TIME))
                    .setHeader("Последний заход");
            grid.setItems(list);
            grid.setAllRowsVisible(true);
            grid.addItemClickListener(e -> open(e.getItem().getId()));
            add(grid);

            Button resume = new Button("Продолжить: " + list.get(0).getName(),
                    e -> open(list.get(0).getId()));
            resume.addThemeVariants(ButtonVariant.LUMO_PRIMARY);
            add(resume);
        }

        boolean limitReached = list.size() >= props.maxSavesPerUser();
        Button newGame = new Button("Новая игра");
        newGame.setEnabled(!limitReached);
        newGame.addClickListener(e -> UI.getCurrent().navigate(ClubSelectView.class));
        add(newGame);
        if (limitReached) {
            add(new Paragraph("Достигнут лимит сохранений. Удалите одно из них, чтобы начать новую игру."));
        }
    }

    private static void open(Integer saveId) {
        UI.getCurrent().navigate(DashboardView.class, new RouteParameters("saveId", String.valueOf(saveId)));
    }
}
