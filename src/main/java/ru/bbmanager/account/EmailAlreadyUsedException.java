package ru.bbmanager.account;

public class EmailAlreadyUsedException extends RuntimeException {

    public EmailAlreadyUsedException(String email) {
        super("Email уже зарегистрирован: " + email);
    }
}
