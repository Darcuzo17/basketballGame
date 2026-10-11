package ru.bbmanager.account;

import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;

public interface AppUserRepository extends JpaRepository<AppUser, Integer> {

    Optional<AppUser> findByEmailIgnoreCase(String email);
}
