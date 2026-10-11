package ru.bbmanager.game;

public class SaveLimitReachedException extends RuntimeException {

    public SaveLimitReachedException(int limit) {
        super("Достигнут лимит сохранений: " + limit);
    }
}
