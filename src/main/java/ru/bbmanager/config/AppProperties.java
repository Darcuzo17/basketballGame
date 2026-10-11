package ru.bbmanager.config;

import org.springframework.boot.context.properties.ConfigurationProperties;

/** Настройки приложения из секции app в application.yml. */
@ConfigurationProperties(prefix = "app")
public record AppProperties(String baseUrl, String mailFrom, int maxSavesPerUser) {
}
