package ru.bbmanager.ui;

import com.vaadin.flow.component.UI;
import com.vaadin.flow.component.button.Button;
import com.vaadin.flow.component.button.ButtonVariant;
import com.vaadin.flow.component.checkbox.CheckboxGroup;
import com.vaadin.flow.component.dialog.Dialog;
import com.vaadin.flow.component.grid.Grid;
import com.vaadin.flow.component.grid.GridVariant;
import com.vaadin.flow.component.html.Div;
import com.vaadin.flow.component.html.H2;
import com.vaadin.flow.component.html.H3;
import com.vaadin.flow.component.html.Paragraph;
import com.vaadin.flow.component.html.Span;
import com.vaadin.flow.component.notification.Notification;
import com.vaadin.flow.component.orderedlayout.HorizontalLayout;
import com.vaadin.flow.component.orderedlayout.VerticalLayout;
import com.vaadin.flow.component.tabs.Tab;
import com.vaadin.flow.component.tabs.Tabs;
import com.vaadin.flow.component.textfield.TextField;
import com.vaadin.flow.data.value.ValueChangeMode;
import com.vaadin.flow.router.PageTitle;
import com.vaadin.flow.router.Route;
import com.vaadin.flow.router.RouteParameters;
import jakarta.annotation.security.PermitAll;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Optional;
import ru.bbmanager.account.CurrentUserService;
import ru.bbmanager.club.ClubCatalog;
import ru.bbmanager.club.MapClub;
import ru.bbmanager.game.ClubLockedException;
import ru.bbmanager.game.GameStartService;
import ru.bbmanager.game.SaveLimitReachedException;
import ru.bbmanager.ui.map.RussiaMap;

/**
 * Экран 3: выбор клуба. Карта России и список, фильтры по лигам, поиск.
 * Сложность клуба не показывается. Закрытые клубы выбрать нельзя.
 */
@Route("clubs")
@PageTitle("Выбор клуба")
@PermitAll
public class ClubSelectView extends VerticalLayout {

    private final ClubCatalog catalog;
    private final GameStartService gameStart;
    private final CurrentUserService currentUser;
    private final Map<Integer, String> leagueNames;

    private final RussiaMap map = new RussiaMap();
    private final Grid<MapClub> grid = new Grid<>(MapClub.class, false);
    private final CheckboxGroup<Integer> leagueFilter = new CheckboxGroup<>();
    private final TextField search = new TextField();
    private final Div details = new Div();
    private final Tab mapTab = new Tab("Карта");
    private final Tab listTab = new Tab("Список");
    private final Tabs modeTabs = new Tabs(mapTab, listTab);

    private MapClub selected;

    public ClubSelectView(ClubCatalog catalog, GameStartService gameStart, CurrentUserService currentUser) {
        this.catalog = catalog;
        this.gameStart = gameStart;
        this.currentUser = currentUser;
        this.leagueNames = catalog.leagueNames();
        setPadding(true);

        Button back = new Button("Назад", e -> UI.getCurrent().navigate(SavesView.class));
        HorizontalLayout header = new HorizontalLayout(new H2("Выбор клуба"), back);
        header.setWidthFull();
        header.setAlignItems(Alignment.CENTER);
        header.setJustifyContentMode(JustifyContentMode.BETWEEN);

        leagueFilter.setLabel("Лиги");
        leagueFilter.setItems(leagueNames.keySet().stream().sorted().toList());
        leagueFilter.setItemLabelGenerator(leagueNames::get);
        leagueFilter.select(leagueNames.keySet().toArray(new Integer[0]));
        leagueFilter.addValueChangeListener(e -> refresh());

        search.setPlaceholder("Поиск по клубу или городу");
        search.setClearButtonVisible(true);
        search.setValueChangeMode(ValueChangeMode.LAZY);
        search.addValueChangeListener(e -> refresh());
        search.setWidthFull();

        modeTabs.addSelectedChangeListener(e -> showMode());

        configureGrid();
        details.setWidthFull();

        Button createOwn = new Button("Создать свой клуб",
                e -> Notification.show("Создание клуба появится на следующем этапе разработки"));

        map.addClubSelectListener(e -> findClub(e.getClubId()).ifPresent(this::select));
        map.addCitySelectListener(e -> openCityDialog(e.getClubIds()));

        Paragraph demo = new Paragraph("Клубы берутся из шаблона мира. В режиме dev это демо-данные: клубы вымышленные.");
        demo.getStyle().set("color", "var(--lumo-secondary-text-color)");
        demo.getStyle().set("font-size", "var(--lumo-font-size-s)");

        add(header, leagueFilter, search, modeTabs, map, grid, details, createOwn, demo);
        refresh();
        showMode();
        renderDetails();
    }

    private void configureGrid() {
        grid.addThemeVariants(GridVariant.LUMO_NO_BORDER);
        grid.addColumn(MapClub::name).setHeader("Клуб").setAutoWidth(true);
        grid.addColumn(MapClub::city).setHeader("Город").setAutoWidth(true);
        grid.addColumn(MapClub::leagueName).setHeader("Лига").setAutoWidth(true);
        grid.addColumn(c -> ownerLabel(c.ownerType())).setHeader("Владелец").setAutoWidth(true);
        grid.addColumn(c -> c.locked() ? "закрыт" : "").setHeader("");
        grid.setSelectionMode(Grid.SelectionMode.SINGLE);
        grid.addSelectionListener(e -> e.getFirstSelectedItem().ifPresent(this::select));
        grid.setAllRowsVisible(true);
    }

    private void showMode() {
        boolean mapMode = modeTabs.getSelectedTab() == mapTab;
        map.setVisible(mapMode);
        grid.setVisible(!mapMode);
    }

    private void refresh() {
        String query = search.getValue() == null ? "" : search.getValue().trim().toLowerCase(Locale.ROOT);
        List<MapClub> filtered = catalog.findAll().stream()
                .filter(c -> leagueFilter.getValue().contains(c.tier()))
                .filter(c -> query.isEmpty()
                        || c.name().toLowerCase(Locale.ROOT).contains(query)
                        || c.city().toLowerCase(Locale.ROOT).contains(query))
                .toList();
        map.setClubs(filtered);
        grid.setItems(filtered);
        if (selected != null && filtered.stream().noneMatch(c -> c.id() == selected.id())) {
            selected = null;
            map.setSelectedClubId(null);
            renderDetails();
        }
    }

    private Optional<MapClub> findClub(int id) {
        return catalog.findAll().stream().filter(c -> c.id() == id).findFirst();
    }

    private void select(MapClub club) {
        this.selected = club;
        map.setSelectedClubId(club.id());
        renderDetails();
    }

    private void openCityDialog(List<Integer> ids) {
        List<MapClub> clubs = ids.stream().map(this::findClub).flatMap(Optional::stream).toList();
        if (clubs.isEmpty()) {
            return;
        }
        Dialog dialog = new Dialog();
        dialog.setHeaderTitle("Клубы города: " + clubs.get(0).city());
        VerticalLayout content = new VerticalLayout();
        for (MapClub club : clubs) {
            String caption = club.name() + " (" + club.leagueName() + ")" + (club.locked() ? ", закрыт" : "");
            Button button = new Button(caption, e -> {
                select(club);
                dialog.close();
            });
            button.setWidthFull();
            content.add(button);
        }
        dialog.add(content);
        dialog.getFooter().add(new Button("Закрыть", e -> dialog.close()));
        dialog.open();
    }

    private void renderDetails() {
        details.removeAll();
        if (selected == null) {
            details.add(new Paragraph("Выберите клуб на карте или в списке."));
            return;
        }
        Span badge = new Span(selected.leagueName());
        badge.getElement().getThemeList().add("badge");
        Paragraph info = new Paragraph(selected.city() + " · " + ownerLabel(selected.ownerType()));

        Button start = new Button(selected.locked() ? "Недоступен" : "Начать играть");
        start.addThemeVariants(ButtonVariant.LUMO_PRIMARY);
        start.setEnabled(!selected.locked());
        start.addClickListener(e -> confirmStart(selected));

        details.add(new H3(selected.name()), badge, info, start);
    }

    private void confirmStart(MapClub club) {
        Dialog dialog = new Dialog();
        dialog.setHeaderTitle("Начать игру?");
        dialog.add(new Paragraph("Вы возглавите клуб «" + club.name() + "» (" + club.city() + ")."));
        Button ok = new Button("Начать", e -> {
            dialog.close();
            startGame(club);
        });
        ok.addThemeVariants(ButtonVariant.LUMO_PRIMARY);
        dialog.getFooter().add(new Button("Отмена", e -> dialog.close()), ok);
        dialog.open();
    }

    private void startGame(MapClub club) {
        try {
            int saveId = gameStart.startNewGame(currentUser.requireUserId(), club.id());
            UI.getCurrent().navigate(DashboardView.class, new RouteParameters("saveId", String.valueOf(saveId)));
        } catch (SaveLimitReachedException ex) {
            Notification.show("Достигнут лимит сохранений. Удалите одно из них и попробуйте снова.");
        } catch (ClubLockedException ex) {
            Notification.show("Этот клуб недоступен для выбора.");
        }
    }

    private static String ownerLabel(String ownerType) {
        return switch (ownerType) {
            case "state" -> "государственный";
            case "mixed" -> "смешанный";
            default -> "частный";
        };
    }
}
