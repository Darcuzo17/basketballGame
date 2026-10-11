package ru.bbmanager.account;

import org.springframework.security.core.userdetails.User;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.security.core.userdetails.UsernameNotFoundException;
import org.springframework.stereotype.Service;

/** Пользователь с неподтверждённым email считается отключённым и войти не может. */
@Service
public class UserDetailsServiceImpl implements UserDetailsService {

    private final AppUserRepository users;

    public UserDetailsServiceImpl(AppUserRepository users) {
        this.users = users;
    }

    @Override
    public UserDetails loadUserByUsername(String username) throws UsernameNotFoundException {
        AppUser user = users.findByEmailIgnoreCase(username)
                .filter(u -> u.getPasswordHash() != null)
                .orElseThrow(() -> new UsernameNotFoundException(username));
        return User.withUsername(user.getEmail())
                .password(user.getPasswordHash())
                .roles("USER")
                .disabled(user.getEmailVerifiedAt() == null)
                .build();
    }
}
