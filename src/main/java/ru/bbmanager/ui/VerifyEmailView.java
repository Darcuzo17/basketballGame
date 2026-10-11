package ru.bbmanager.ui;

import com.vaadin.flow.component.html.H2;
import com.vaadin.flow.component.html.Paragraph;
import com.vaadin.flow.component.orderedlayout.VerticalLayout;
import com.vaadin.flow.router.BeforeEnterEvent;
import com.vaadin.flow.router.BeforeEnterObserver;
import com.vaadin.flow.router.PageTitle;
import com.vaadin.flow.router.Route;
import com.vaadin.flow.router.RouterLink;
import com.vaadin.flow.server.auth.AnonymousAllowed;
import ru.bbmanager.account.AccountService;

/** Страница по ссылке из письма: /verify?token=... */
@Route("verify")
@PageTitle("Подтверждение email")
@AnonymousAllowed
public class VerifyEmailView extends VerticalLayout implements BeforeEnterObserver {

    private final AccountService accounts;

    public VerifyEmailView(AccountService accounts) {
        this.accounts = accounts;
        addClassName("auth-view");
        setSizeFull();
        setAlignItems(Alignment.CENTER);
        setJustifyContentMode(JustifyContentMode.CENTER);
    }

    @Override
    public void beforeEnter(BeforeEnterEvent event) {
        String token = event.getLocation().getQueryParameters()
                .getSingleParameter("token").orElse("");
        boolean ok = accounts.verify(token);

        removeAll();
        if (ok) {
            add(new H2("Email подтверждён"),
                    new Paragraph("Теперь можно войти в игру."),
                    new RouterLink("Войти", LoginView.class));
        } else {
            add(new H2("Ссылка недействительна"),
                    new Paragraph("Ссылка устарела или уже использована. Зарегистрируйтесь заново или запросите письмо ещё раз."),
                    new RouterLink("К регистрации", RegisterView.class));
        }
    }
}
