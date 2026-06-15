# Milestone 7 - Dungeon procedurale

## Stato

Completata come prototipo minimo.

## Deliverable

- `DungeonGenerator` deterministico da seed.
- Percorso con celle uniche e link sequenziali.
- Start room, combat room, loot room e boss room.
- `DungeonRoom` riusabile con pareti e portale bloccabile.
- Transizioni fisiche tra stanze.
- Spawn e scaling crescente dei nemici nelle combat room.
- Loot room con XP, denaro, munizioni e vita.
- Boss finale tramite `GameModeManager` e `BossSystem`.
- HUD con seed, stanza, stato uscita e nemici rimasti.
- Hotkey debug `F5` per dungeon e `F1` per survival.
- Condizione di completamento e sconfitta party.

## Verifica automatica

```text
godot --headless --path . --script res://tests/combat_smoke_test.gd
godot --headless --path . --script res://tests/enemy_drop_smoke_test.gd
godot --headless --path . --script res://tests/survival_wave_smoke_test.gd
godot --headless --path . --script res://tests/boss_smoke_test.gd
godot --headless --path . --script res://tests/dungeon_smoke_test.gd
```

Risultati attesi: tutti i test terminano con `PASS`.

## Verifica manuale

1. Avviare `res://game/main/main.tscn`.
2. Premere `F5`.
3. Controllare seed e stato stanza nell'HUD.
4. Attraversare il portale verde della start room.
5. Verificare il blocco rosso durante il combattimento.
6. Eliminare i nemici e attraversare il portale sbloccato.
7. Raccogliere i pickup nella loot room.
8. Raggiungere la boss room ed eliminare il `Wave Warden`.
9. Attraversare il portale finale e verificare il completamento.
10. Premere `F1` e verificare il ritorno a survival.

## Limiti noti

- Il percorso e lineare e non offre ancora diramazioni.
- Esiste una sola scena arena riusata per tutte le stanze.
- Non esistono shop, biomi, minimappa o persistenza della run.
- Il dungeon riusa il solo nemico melee e il solo boss disponibili.
- Il bilanciamento resta da validare con 2-4 player su run complete.
