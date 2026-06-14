# Milestone 4 - Nemici base e drop

## Stato

Completata come prototipo minimo.

## Deliverable

- `BasicEnemy` melee con stati idle, chase, attack e dead.
- Targeting periodico del player vivo piu vicino.
- Retarget automatico durante leave o morte del target.
- Attacco tramite `HealthSystem`.
- Morte tramite `HealthComponent`.
- Spawn e registro runtime in `EnemySystem`.
- `DropEntry` e `LootTable` tipizzate.
- `DropSystem` responsabile di roll, spawn e applicazione ricompense.
- `DropPickup` fisici per XP, denaro, munizioni, vita e armi.
- XP e denaro condivisi dal party.
- Munizioni, cura e arma applicate al raccoglitore.
- `Prototype Blaster` come primo drop arma.
- Due nemici dimostrativi nella scena principale.

## Verifica automatica

```text
godot --headless --path . --script res://tests/combat_smoke_test.gd
godot --headless --path . --script res://tests/enemy_drop_smoke_test.gd
```

Risultati attesi: `COMBAT_SMOKE_TEST: PASS` e `ENEMY_DROP_SMOKE_TEST: PASS`.

## Verifica manuale

1. Aprire il progetto in Godot 4.x.
2. Avviare `res://game/main/main.tscn`.
3. Verificare che i nemici verdi inseguano il player piu vicino.
4. Lasciarsi raggiungere e verificare la perdita di vita nell'HUD.
5. Uccidere un nemico con tre colpi della pistola.
6. Raccogliere il pickup XP azzurro.
7. Ripetere per osservare gli eventuali drop denaro, munizioni, vita e arma.
8. Attivare player 2 e verificare che munizioni, cura e arma restino per-player.
9. Disattivare il target inseguito e verificare il retarget.

## Limiti noti

- Esiste una sola AI melee; shooter, tank e runner sono futuri.
- Non esistono pathfinding o avoidance avanzati.
- Il player morto non dispone ancora di respawn o revive.
- Il drop arma sostituisce immediatamente l'arma corrente.
- Non esistono inventario, confronto arma o scambio tra player.
- Le ondate e lo scaling nemici appartengono alla Milestone 5.
