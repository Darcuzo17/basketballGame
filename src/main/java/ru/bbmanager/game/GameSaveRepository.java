package ru.bbmanager.game;

import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;

public interface GameSaveRepository extends JpaRepository<GameSave, Integer> {

    List<GameSave> findByUserIdOrderByLastPlayedAtDesc(Integer userId);
}
