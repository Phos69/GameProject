# Milestone 6 - Boss system

## Stato

Completata come prototipo minimo.

## Deliverable

- `Wave Warden` come primo boss modulare.
- Targeting del player vivo piu vicino.
- Movimento di avvicinamento, ritirata e strafe.
- Fase 1 con raffiche mirate.
- Fase 2 sotto il 50% con raffiche radiali e mirate alternate.
- Proiettili ostili separati dai proiettili player.
- Scaling di vita e danno fornito dalla modalita.
- `BossSystem` con spawn, boss attivo e segnale sconfitta.
- Barra vita HUD con nome, fase e valori.
- Loot table boss con XP, denaro e `Wave Cannon` garantiti.
- Quinta ondata survival con due scorte e boss.
- Wave completata solo dopo la morte di scorte e boss.

## Verifica automatica

```text
godot --headless --path . --script res://tests/combat_smoke_test.gd
godot --headless --path . --script res://tests/enemy_drop_smoke_test.gd
godot --headless --path . --script res://tests/survival_wave_smoke_test.gd
godot --headless --path . --script res://tests/boss_smoke_test.gd
```

Risultati attesi: tutti i test terminano con `PASS`.

## Verifica manuale

1. Avviare `res://game/main/main.tscn`.
2. Raggiungere la quinta ondata.
3. Verificare due scorte e spawn del `Wave Warden`.
4. Controllare barra vita, nome e fase.
5. Osservare la raffica mirata in fase 1.
6. Portare il boss sotto il 50% e osservare la raffica radiale.
7. Verificare danno dei proiettili viola sui player.
8. Eliminare scorte e boss.
9. Raccogliere il pickup `Wave Cannon`.
10. Verificare intermissione e prosecuzione della run.

## Limiti noti

- Esiste un solo boss.
- I pattern non hanno ancora telegraph animati o audio.
- Non esistono ostacoli o pathfinding boss.
- Il drop arma sostituisce immediatamente l'arma corrente.
- Il bilanciamento resta da validare con sessioni multiplayer lunghe.
