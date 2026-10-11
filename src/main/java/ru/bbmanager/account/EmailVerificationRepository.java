package ru.bbmanager.account;

import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;

public interface EmailVerificationRepository extends JpaRepository<EmailVerification, Integer> {

    Optional<EmailVerification> findByTokenHash(String tokenHash);
}
