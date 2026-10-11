package ru.bbmanager.game;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import java.time.LocalDate;

@Entity
@Table(name = "game_save")
public class GameSave {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer id;

    @Column(name = "user_id", nullable = false)
    private Integer userId;

    @Column(nullable = false)
    private String name;

    @Column(name = "game_date", nullable = false)
    private LocalDate gameDate;

    @Column(name = "user_club_id")
    private Integer userClubId;

    @Column(name = "manager_reputation", nullable = false)
    private Integer managerReputation = 30;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt = Instant.now();

    @Column(name = "last_played_at", nullable = false)
    private Instant lastPlayedAt = Instant.now();

    public Integer getId() { return id; }
    public Integer getUserId() { return userId; }
    public void setUserId(Integer userId) { this.userId = userId; }
    public String getName() { return name; }
    public void setName(String name) { this.name = name; }
    public LocalDate getGameDate() { return gameDate; }
    public void setGameDate(LocalDate gameDate) { this.gameDate = gameDate; }
    public Integer getUserClubId() { return userClubId; }
    public void setUserClubId(Integer userClubId) { this.userClubId = userClubId; }
    public Integer getManagerReputation() { return managerReputation; }
    public void setManagerReputation(Integer managerReputation) { this.managerReputation = managerReputation; }
    public Instant getCreatedAt() { return createdAt; }
    public Instant getLastPlayedAt() { return lastPlayedAt; }
    public void setLastPlayedAt(Instant lastPlayedAt) { this.lastPlayedAt = lastPlayedAt; }
}
