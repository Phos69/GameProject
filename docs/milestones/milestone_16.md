# Milestone 16 - Downed e Revive Multiplayer

## Stato

Completata come primo pass cooperativo.

## Obiettivo

Evitare che un player locale resti escluso dalla run e rendere il recupero
cooperativo leggibile con due o quattro slot.

## Implementato

- stato `downed` opzionale in `HealthComponent`;
- player downed esclusi da movimento, fuoco, targeting e reward;
- `ReviveSystem` centrale con raggio, durata e input interact tenuto;
- progresso azzerato su interruzione, distanza, cambio reviver o leave;
- ripristino al 35% della vita massima;
- anello world-space con colore slot e progresso;
- stato `DOWNED / HOLD INTERACT` nelle schede HUD;
- sconfitta party all-downed in survival, dungeon e tower defense;
- smoke test a due/tre player e QA a quattro player.

## Contratto

- I componenti non-player mantengono `downed_enabled = false`.
- A zero HP un player diventa downed senza emettere `died`.
- `HealthComponent.is_alive()` restituisce false anche per i downed.
- Solo un player vivo, vicino e con interact tenuto avanza il revive.
- Cambiare reviver o interrompere l'input azzera il progresso.
- Il revive non modifica `max_health`; `Field Kit` resta idempotente.
- Survival e dungeon terminano quando non esistono player vivi.
- Tower defense termina per core distrutto o party interamente downed.

## Controlli

- Tastiera player 1: tenere `E`.
- Joypad: tenere `A` sul controller dello slot reviver.

## Verifica

```text
godot --headless --path . --script res://tests/milestone_16_downed_revive_smoke_test.gd
godot --headless --path . --script res://tests/combat_smoke_test.gd
godot --headless --path . --script res://tests/boss_smoke_test.gd
godot --headless --path . --script res://tests/dungeon_smoke_test.gd
godot --headless --path . --script res://tests/tower_defense_smoke_test.gd
godot --path . --rendering-method gl_compatibility --script res://tests/downed_revive_visual_qa.gd
```

Output QA:

```text
build/qa/milestone_16_downed_revive.png
```

## Checklist manuale

- Abbattere P2 lasciando P1 vivo e verificare posa, colore slot e HUD.
- Confermare che P2 non possa muoversi o sparare.
- Tenere `E` o joypad `A` vicino a P2 e osservare il progresso.
- Lasciare il tasto o uscire dal raggio e verificare il reset.
- Completare il revive e verificare il ripristino al 35%.
- Ripetere con `Field Kit` e confermare max HP invariati.
- Provare join/leave durante un revive.
- Verificare la sconfitta con tutti gli slot downed nelle tre modalita.
