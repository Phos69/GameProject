# Milestone 8 - Tower defense

## Stato

Completata come prototipo minimo.

## Deliverable

- Modalita `TowerDefenseMode` registrata presso `GameModeManager`.
- `TowerDefenseWaveController` separato per la macchina a stati delle ondate.
- Hotkey debug `F6`.
- Arena dedicata con percorso, core e tre slot costruzione.
- Nemico a waypoint creato tramite `EnemySystem`.
- Core con vita, segnale distruzione e condizione di sconfitta.
- Crediti di run e costo costruzione.
- Input `interact` con `E` e joypad `A`.
- Torre automatica con range, fire rate e proiettili condivisi.
- Ondate con spawn progressivo, scaling e ricompense.
- Boss ogni cinque ondate tramite `BossSystem`.
- HUD con core, crediti, ondata e nemici rimasti.

## Verifica automatica

```text
godot --headless --path . --script res://tests/combat_smoke_test.gd
godot --headless --path . --script res://tests/enemy_drop_smoke_test.gd
godot --headless --path . --script res://tests/survival_wave_smoke_test.gd
godot --headless --path . --script res://tests/boss_smoke_test.gd
godot --headless --path . --script res://tests/dungeon_smoke_test.gd
godot --headless --path . --script res://tests/tower_defense_smoke_test.gd
```

Risultato atteso: tutti i test terminano con `PASS`.

## Verifica manuale

1. Avviare `res://game/main/main.tscn`.
2. Premere `F6`.
3. Verificare core a 250 HP e 75 crediti nell'HUD.
4. Osservare un nemico seguire il percorso e danneggiare il core.
5. Entrare in uno slot azzurro e premere `E` o joypad `A`.
6. Verificare la spesa di 25 crediti e lo spawn della torre.
7. Osservare targeting, proiettili e ricompense crediti.
8. Raggiungere la quinta ondata e verificare boss e scorte.
9. Lasciare distruggere il core e verificare `DEFENSE FAILED`.
10. Premere `F1` e verificare il ritorno pulito a survival.

## Limiti noti

- Il percorso e fisso e non usa navigazione dinamica.
- Esiste un solo tipo di nemico da percorso e un solo tipo di torre.
- Gli slot sono tre e non supportano vendita, upgrade o riparazione.
- I crediti non sono persistenti fuori dalla run.
- Il boss riusa il `Wave Warden` in modalita percorso senza pattern offensivi.
- Il bilanciamento 2-4 player richiede ancora playtest manuali estesi.
