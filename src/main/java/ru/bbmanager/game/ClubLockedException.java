package ru.bbmanager.game;

public class ClubLockedException extends RuntimeException {

    public ClubLockedException(String clubName) {
        super("Клуб закрыт для выбора: " + clubName);
    }
}
