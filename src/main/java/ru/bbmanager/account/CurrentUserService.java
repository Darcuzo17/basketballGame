package ru.bbmanager.account;

import com.vaadin.flow.spring.security.AuthenticationContext;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.stereotype.Service;

/** Id вошедшего пользователя. Вызывать из экранов, доступных только после входа. */
@Service
public class CurrentUserService {

    private final AuthenticationContext authContext;
    private final AppUserRepository users;

    public CurrentUserService(AuthenticationContext authContext, AppUserRepository users) {
        this.authContext = authContext;
        this.users = users;
    }

    public Integer requireUserId() {
        return authContext.getAuthenticatedUser(UserDetails.class)
                .flatMap(u -> users.findByEmailIgnoreCase(u.getUsername()))
                .map(AppUser::getId)
                .orElseThrow(() -> new IllegalStateException("Пользователь не вошёл в систему"));
    }
}
