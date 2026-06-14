# Milestone 5 - Zombie survival

## Stato

Completata come prototipo minimo.

## Deliverable

- `SurvivalMode` registrata e avviata da `GameModeManager`.
- `WaveManager` con intermissione, spawning, combat e reward.
- Spawn scaglionato su punti arena configurabili.
- Conteggio zombie crescente per ondata.
- Scaling di vita, velocita e danno.
- Tracking separato dei nemici appartenenti alla wave.
- Ricompense party di denaro, munizioni e cura.
- HUD con countdown, ondata, marker boss, nemici rimasti e reward.
- Join/leave locale compatibile durante la run.
- Sconfitta quando tutti i player attivi sono morti.
- Boss wave ogni cinque ondate con inoltro a `BossSystem`.
- Zombie extra potenziati come fallback finche il boss reale non esiste.

## Verifica automatica

```text
godot --headless --path . --script res://tests/combat_smoke_test.gd
godot --headless --path . --script res://tests/enemy_drop_smoke_test.gd
godot --headless --path . --script res://tests/survival_wave_smoke_test.gd
```

Risultati attesi: tutti i test terminano con `PASS`.

## Verifica manuale

1. Aprire il progetto in Godot 4.x.
2. Avviare `res://game/main/main.tscn`.
3. Attendere il countdown iniziale.
4. Verificare lo spawn scaglionato degli zombie.
5. Eliminare tutti i nemici e controllare ricompensa e intermissione.
6. Proseguire per verificare aumento di conteggio e statistiche.
7. Attivare player 2 durante una intermissione.
8. Verificare che entrambi ricevano le ricompense successive.
9. Raggiungere una boss wave e verificare marker e zombie potenziati.
10. Lasciare morire tutti i player e verificare l'arresto della run.

## Limiti noti

- La boss wave non possiede ancora un boss reale.
- Non esistono ancora barra vita boss, pattern o drop speciale boss.
- Esiste una sola tipologia di zombie melee.
- Non esistono respawn o revive.
- Non esiste ancora un menu di selezione modalita.
- Il bilanciamento e adatto solo al prototipo.
