package ru.bbmanager.config;

import com.vaadin.flow.spring.security.VaadinWebSecurity;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import ru.bbmanager.ui.LoginView;

/**
 * Безопасность на базе Vaadin. Страницы входа, регистрации и подтверждения email
 * помечены @AnonymousAllowed, остальные требуют входа (@PermitAll).
 * В новых версиях Vaadin этот базовый класс может быть заменён на VaadinSecurityConfigurer:
 * смотрите документацию вашей версии.
 */
@EnableWebSecurity
@Configuration
public class SecurityConfig extends VaadinWebSecurity {

    @Override
    protected void configure(HttpSecurity http) throws Exception {
        super.configure(http);
        setLoginView(http, LoginView.class);
    }
}
