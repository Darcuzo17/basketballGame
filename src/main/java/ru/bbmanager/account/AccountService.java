package ru.bbmanager.account;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.security.SecureRandom;
import java.time.Duration;
import java.time.Instant;
import java.util.Base64;
import java.util.HexFormat;
import java.util.Locale;
import org.springframework.mail.SimpleMailMessage;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import ru.bbmanager.config.AppProperties;

/**
 * Регистрация и подтверждение email.
 * В БД хранится только хэш токена, сам токен уходит в письме.
 * TODO: отправлять письмо после коммита транзакции (сейчас при сбое почты регистрация откатывается).
 */
@Service
public class AccountService {

    private static final Duration TOKEN_TTL = Duration.ofHours(24);

    private final AppUserRepository users;
    private final EmailVerificationRepository verifications;
    private final PasswordEncoder passwordEncoder;
    private final JavaMailSender mailSender;
    private final AppProperties props;
    private final SecureRandom random = new SecureRandom();

    public AccountService(AppUserRepository users,
                          EmailVerificationRepository verifications,
                          PasswordEncoder passwordEncoder,
                          JavaMailSender mailSender,
                          AppProperties props) {
        this.users = users;
        this.verifications = verifications;
        this.passwordEncoder = passwordEncoder;
        this.mailSender = mailSender;
        this.props = props;
    }

    @Transactional
    public void register(String email, String rawPassword) {
        String normalized = email.trim().toLowerCase(Locale.ROOT);
        if (users.findByEmailIgnoreCase(normalized).isPresent()) {
            throw new EmailAlreadyUsedException(normalized);
        }
        AppUser user = new AppUser();
        user.setEmail(normalized);
        user.setPasswordHash(passwordEncoder.encode(rawPassword));
        users.save(user);
        sendVerification(user);
    }

    /** Повторная отправка письма. Для неизвестных и уже подтверждённых адресов ничего не делает. */
    @Transactional
    public void resendVerification(String email) {
        users.findByEmailIgnoreCase(email.trim())
                .filter(u -> u.getEmailVerifiedAt() == null)
                .ifPresent(this::sendVerification);
    }

    @Transactional
    public boolean verify(String token) {
        if (token == null || token.isBlank()) {
            return false;
        }
        Instant now = Instant.now();
        return verifications.findByTokenHash(sha256(token))
                .filter(v -> v.getUsedAt() == null && v.getExpiresAt().isAfter(now))
                .flatMap(v -> users.findById(v.getUserId()).map(u -> {
                    u.setEmailVerifiedAt(now);
                    v.setUsedAt(now);
                    return true;
                }))
                .orElse(false);
    }

    private void sendVerification(AppUser user) {
        byte[] raw = new byte[32];
        random.nextBytes(raw);
        String token = Base64.getUrlEncoder().withoutPadding().encodeToString(raw);

        EmailVerification verification = new EmailVerification();
        verification.setUserId(user.getId());
        verification.setTokenHash(sha256(token));
        verification.setExpiresAt(Instant.now().plus(TOKEN_TTL));
        verifications.save(verification);

        SimpleMailMessage message = new SimpleMailMessage();
        message.setFrom(props.mailFrom());
        message.setTo(user.getEmail());
        message.setSubject("Подтверждение email");
        message.setText("Чтобы подтвердить адрес, перейдите по ссылке:\n"
                + props.baseUrl() + "/verify?token=" + token
                + "\n\nСсылка действует 24 часа.");
        mailSender.send(message);
    }

    private static String sha256(String value) {
        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            return HexFormat.of().formatHex(digest.digest(value.getBytes(StandardCharsets.UTF_8)));
        } catch (NoSuchAlgorithmException e) {
            throw new IllegalStateException(e);
        }
    }
}
