package ru.bbmanager.ui.map;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.vaadin.flow.component.Component;
import com.vaadin.flow.component.ComponentEvent;
import com.vaadin.flow.component.ComponentEventListener;
import com.vaadin.flow.component.DomEvent;
import com.vaadin.flow.component.EventData;
import com.vaadin.flow.component.HasSize;
import com.vaadin.flow.component.Tag;
import com.vaadin.flow.component.dependency.JsModule;
import com.vaadin.flow.shared.Registration;
import java.util.Arrays;
import java.util.List;
import ru.bbmanager.club.MapClub;

/**
 * Карта России с клубами. Рисует веб-компонент frontend/components/russia-map.js.
 * Данные передаются строкой JSON, поэтому код не зависит от версии JSON-API Vaadin.
 */
@Tag("russia-map")
@JsModule("./components/russia-map.js")
public class RussiaMap extends Component implements HasSize {

    private static final ObjectMapper MAPPER = new ObjectMapper();

    public RussiaMap() {
        getElement().getStyle().set("display", "block");
        setWidthFull();
    }

    public void setClubs(List<MapClub> clubs) {
        try {
            getElement().setProperty("clubsJson", MAPPER.writeValueAsString(clubs));
        } catch (JsonProcessingException e) {
            throw new IllegalStateException("Не удалось сериализовать клубы для карты", e);
        }
    }

    /** Подсветить клуб на карте; null снимает выделение. */
    public void setSelectedClubId(Integer clubId) {
        getElement().setProperty("selectedId", clubId == null ? -1 : clubId);
    }

    public Registration addClubSelectListener(ComponentEventListener<ClubSelectEvent> listener) {
        return addListener(ClubSelectEvent.class, listener);
    }

    public Registration addCitySelectListener(ComponentEventListener<CitySelectEvent> listener) {
        return addListener(CitySelectEvent.class, listener);
    }

    /** Клик по городу, где один клуб. */
    @DomEvent("club-select")
    public static class ClubSelectEvent extends ComponentEvent<RussiaMap> {
        private final int clubId;

        public ClubSelectEvent(RussiaMap source, boolean fromClient,
                               @EventData("event.detail.id") int clubId) {
            super(source, fromClient);
            this.clubId = clubId;
        }

        public int getClubId() {
            return clubId;
        }
    }

    /** Клик по городу, где несколько клубов. */
    @DomEvent("city-select")
    public static class CitySelectEvent extends ComponentEvent<RussiaMap> {
        private final List<Integer> clubIds;

        public CitySelectEvent(RussiaMap source, boolean fromClient,
                               @EventData("event.detail.ids") String ids) {
            super(source, fromClient);
            this.clubIds = Arrays.stream(ids.split(","))
                    .filter(s -> !s.isBlank())
                    .map(Integer::parseInt)
                    .toList();
        }

        public List<Integer> getClubIds() {
            return clubIds;
        }
    }
}
