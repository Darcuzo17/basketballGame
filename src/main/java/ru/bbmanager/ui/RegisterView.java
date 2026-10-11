package ru.bbmanager.ui;

import com.vaadin.flow.component.button.Button;
import com.vaadin.flow.component.button.ButtonVariant;
import com.vaadin.flow.component.html.H2;
import com.vaadin.flow.component.html.Paragraph;
import com.vaadin.flow.component.notification.Notification;
import com.vaadin.flow.component.orderedlayout.VerticalLayout;
import com.vaadin.flow.component.textfield.EmailField;
import com.vaadin.flow.component.textfield.PasswordField;
import com.vaadin.flow.router.PageTitle;
import com.vaadin.flow.router.Route;
import com.vaadin.flow.router.RouterLink;
import com.vaadin.flow.server.auth.AnonymousAllowed;
import org.springframework.mail.MailException;
import ru.bbmanager.account.AccountService;
import ru.bbmanager.account.EmailAlreadyUsedException;

@Route("register")
@PageTitle("Регистрация")
@AnonymousAllowed
public class RegisterView extends VerticalLayout {

    private static final int MIN_PASSWORD_LENGTH = 8;

    public RegisterView(AccountService accounts) {
        addClassName("auth-view");
        setSizeFull();
        setAlignItems(Alignment.CENTER);
        setJustifyContentMode(JustifyContentMode.CENTER);
        showForm(accounts);
    }

    private void showForm(AccountService accounts) {
        removeAll();

        EmailField email = new EmailField("Email");
        PasswordField password = new PasswordField("Пароль (не короче 8 символов)");
        PasswordField repeat = new PasswordField("Повторите пароль");
        Button submit = new Button("Создать аккаунт");
        submit.addThemeVariants(ButtonVariant.LUMO_PRIMARY);
        for (var field : new com.vaadin.flow.component.Component[] {email, password, repeat, submit}) {
            field.getElement().getStyle().set("width", "100%");
        }

        submit.addClickListener(e -> {
            email.setInvalid(false);
            password.setInvalid(false);
            repeat.setInvalid(false);

            if (email.isEmpty() || email.isInvalid()) {
                email.setErrorMessage("Введите корректный email");
                email.setInvalid(true);
                return;
            }
            if (password.getValue().length() < MIN_PASSWORD_LENGTH) {
                password.setErrorMessage("Пароль слишком короткий");
                password.setInvalid(true);
                return;
            }
            if (!password.getValue().equals(repeat.getValue())) {
                repeat.setErrorMessage("Пароли не совпадают");
                repeat.setInvalid(true);
                return;
            }
            try {
                accounts.register(email.getValue(), password.getValue());
                showCheckMail(email.getValue());
            } catch (EmailAlreadyUsedException ex) {
                email.setErrorMessage("Этот email уже зарегистрирован");
                email.setInvalid(true);
            } catch (MailException ex) {
                Notification.show("Не удалось отправить письмо. Попробуйте позже.");
            }
        });

        VerticalLayout card = new VerticalLayout(new H2("Регистрация"), email, password, repeat, submit,
                new RouterLink("У меня уже есть аккаунт", LoginView.class));
        card.addClassName("auth-card");
        add(card);
    }

    private void showCheckMail(String email) {
        removeAll();
        VerticalLayout card = new VerticalLayout(
                new H2("Проверьте почту"),
                new Paragraph("Мы отправили письмо на " + email
                        + ". Перейдите по ссылке из письма, чтобы подтвердить адрес."),
                new RouterLink("Ко входу", LoginView.class));
        card.addClassName("auth-card");
        add(card);
    }
}
