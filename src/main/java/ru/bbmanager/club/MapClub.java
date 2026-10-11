package ru.bbmanager.club;

/**
 * Клуб в том виде, в каком его показывает экран выбора клуба и карта.
 * Поля lat, lon, tier и locked читает JS-компонент карты, поэтому их имена менять нельзя.
 *
 * @param tier      уровень лиги: 1 — высшая
 * @param ownerType state (государственный) или private (частный)
 * @param locked    клуб закрыт для выбора (access_tier не open)
 */
public record MapClub(int id,
                      String name,
                      String city,
                      double lat,
                      double lon,
                      int tier,
                      String leagueName,
                      String ownerType,
                      boolean locked) {
}
