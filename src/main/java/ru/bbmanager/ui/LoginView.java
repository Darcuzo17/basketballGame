package ru.bbmanager.ui;

import com.vaadin.flow.component.html.H1;
import com.vaadin.flow.component.login.LoginForm;
import com.vaadin.flow.component.login.LoginI18n;
import com.vaadin.flow.component.orderedlayout.VerticalLayout;
import com.vaadin.flow.router.BeforeEnterEvent;
import com.vaadin.flow.router.BeforeEnterObserver;
import com.vaadin.flow.router.PageTitle;
import com.vaadin.flow.router.Route;
import com.vaadin.flow.router.RouterLink;
import com.vaadin.flow.server.auth.AnonymousAllowed;

@Route("login")
@PageTitle("Вход")
@AnonymousAllowed
public class LoginView extends VerticalLayout implements BeforeEnterObserver {

    private final LoginForm login = new LoginForm();

    public LoginView() {
        addClassName("auth-view");
        setSizeFull();
        setAlignItems(Alignment.CENTER);
        setJustifyContentMode(JustifyContentMode.CENTER);

        LoginI18n i18n = LoginI18n.createDefault();
        i18n.getForm().setTitle("Вход");
        i18n.getForm().setUsername("Email");
        i18n.getForm().setPassword("Пароль");
        i18n.getForm().setSubmit("Войти");
        i18n.getErrorMessage().setTitle("Не удалось войти");
        i18n.getErrorMessage().setMessage(
                "Проверьте email и пароль. Если вы только зарегистрировались, "
                        + "подтвердите email по ссылке из письма.");
        login.setI18n(i18n);
        login.setAction("login");
        login.setForgotPasswordButtonVisible(false); // восстановление пароля добавим позже

        // Сюда позже добавятся кнопки входа через VK, Яндекс и Telegram
        add(new H1("Баскетбольный менеджер"), login, new RouterLink("Создать аккаунт", RegisterView.class));
    }

    @Override
    public void beforeEnter(BeforeEnterEvent event) {
        if (event.getLocation().getQueryParameters().getParameters().containsKey("error")) {
            login.setError(true);
        }
    }
}
