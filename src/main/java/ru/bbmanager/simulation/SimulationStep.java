package ru.bbmanager.simulation;

/**
 * Один шаг расчёта игрового дня. Каждая механика (травмы, зарплаты, продажи билетов,
 * ажиотаж, матчи, события) реализуется отдельным бином этого интерфейса.
 * Порядок выполнения задаётся методом order(): меньше число, раньше выполнение.
 */
public interface SimulationStep {

    int order();

    void apply(SimulationContext context);
}
